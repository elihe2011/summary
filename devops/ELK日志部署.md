# 1. 日志

日志主要包括系统日志和应用程序日志，运维和开发人员可以通过日志了解服务器中软硬件的信息，检查应用程序或系统的故障，了解故障出现的原因，以便解决问题。分析日志可以更清楚的了解服务器的状态和系统安全状况，从而可以维护服务器稳定运行。

但是日志通常都是存储在各自的服务器中。如果管理数十台服务器， 查阅日志需要依次登陆不同的服务器，查看过程就会很繁琐从而导致工作效率低下。虽然可以使用 rsyslog 服务将日志汇总。但是统计一些日志中的数据或者检索也是很麻烦的，一般使用grep、awk、wc、sort等Linux命令来统计和检索。如果对数量巨大的日志进行统计检索，人工的效率还是十分低下。

通过我们对日志进行收集、汇总到一起，完整的日志数据具有非常重要的作用：

- 信息查找：通过检索日志信息，查找相应的报错，可以快速的解决BUG。
- 数据分析：如果是截断整理格式化后的日志信息，可以进一步对日志进行数据分析和统计，可以选出头条，热点，或者爆款。
- 系统维护：对日志信息分析可以了解服务器的负荷和运行状态。可以针对性的对服务器进行优化。



# 2. ELK

ELK 实时日志收集分析系统可以完美的解决以上问题。

ELK 核心组件：

- **Elasticsearch** ：分布式搜索引擎。具有高可伸缩、高可靠、易管理等特点。可以用于全文检索、结构化检索和分析，并能将这三者结合起来。Elasticsearch 是用Java 基于 Lucene 开发，现在使用最广的开源搜索引擎之一。**在elasticsearch中，所有节点的数据是均等的。**

- **Logstash** ：数据收集处理引擎。支持动态的从各种数据源搜集数据，并对数据进行过滤、分析、丰富、统一格式等操作，然后存储以供后续使用。

- **Kibana** ：可视化化平台。它能够搜索、展示存储在 Elasticsearch 中索引数据。使用它可以很方便的用图表、表格、地图展示和分析数据。

- **Filebeat**：轻量级数据收集引擎。相对于Logstash所占用的系统资源来说，Filebeat 所占用的系统资源几乎是微乎及微。它是基于原先 Logstash-fowarder 的源码改造出来，更加轻量和高效。

工作演示：

1. Filebeat 在服务端收集日志
2. Logstash 处理过滤 Filebeat 收集过来的日志
3. ElasticSearch 存储Logstash提供的处理之后的日志，用以检索、统计
4. Kibana 提供web页面，将Elasticsearch的数据可视化的展示出来

不带缓存：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/elk-no-buffer.png) 

带消息队列缓存：

 ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/elk-with-buffer.png)



# 3. 日志采集方案

## 3.1 方案一：Using a node logging agent

每个节点上部署一个 DaemonSet 日志收集程序 logging-agent，然后通过这个 agent 收集日志数据。例如收集系统日志：`/var/log` 

 ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/logging-with-node-agent.png)

因为使用了 stdout/stderr，只需要在宿主机上收集容器日志 ` /var/lib/docker/containers/${CONTAINER_ID}/${CONTAINER_ID}-json.log`



## 3.2 方案二：Streaming sidecar container

在方案一的基础上，pod中增加一个边车容器，用于将应用容器的 stdout 流写入特定的日志文件中，以便 logging-agent 收集。 

 ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/logging-with-streaming-sidecar.png)

```bash
apiVersion: v1
kind: Pod
metadata:
  name: counter
spec:
  containers:
  - name: count
    image: busybox:1.28
    args:
    - /bin/sh
    - -c
    - >
      i=0;
      while true;
      do
        echo "$i: $(date)" >> /var/log/1.log;
        echo "$(date) INFO $i" >> /var/log/2.log;
        i=$((i+1));
        sleep 1;
      done      
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  - name: count-log-1
    image: busybox:1.28
    args: [/bin/sh, -c, 'tail -n+1 -F /var/log/1.log']
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  - name: count-log-2
    image: busybox:1.28
    args: [/bin/sh, -c, 'tail -n+1 -F /var/log/2.log']
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  volumes:
  - name: varlog
    emptyDir: {}
```



## 3.3 方案三：Sidecar container with a logging agent

Pod 中采用边车模式附加一个日志收集容器 logging-agent，并使用 emptyDir 共享日志目录让日志收集程序读取到

 ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/logging-with-sidecar-agent.png)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluentd.conf: |
    <source>
      type tail
      format none
      path /var/log/1.log
      pos_file /var/log/1.log.pos
      tag count.format1
    </source>

    <source>
      type tail
      format none
      path /var/log/2.log
      pos_file /var/log/2.log.pos
      tag count.format2
    </source>

    <match **>
      type google_cloud
    </match> 

---
apiVersion: v1
kind: Pod
metadata:
  name: counter
spec:
  containers:
  - name: count
    image: busybox:1.28
    args:
    - /bin/sh
    - -c
    - >
      i=0;
      while true;
      do
        echo "$i: $(date)" >> /var/log/1.log;
        echo "$(date) INFO $i" >> /var/log/2.log;
        i=$((i+1));
        sleep 1;
      done      
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  - name: count-agent
    image: registry.k8s.io/fluentd-gcp:1.30
    env:
    - name: FLUENTD_ARGS
      value: -c /etc/fluentd-config/fluentd.conf
    volumeMounts:
    - name: varlog
      mountPath: /var/log
    - name: config-volume
      mountPath: /etc/fluentd-config
  volumes:
  - name: varlog
    emptyDir: {}
  - name: config-volume
    configMap:
      name: fluentd-config
```



## 3.4 方案四：Exposing logs directly from the application

应用程序直接推送日志。该方案需要在应用程序中集成日志推送功能，不再输出到控制台或文件中

 ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/elk/logging-from-application.png)



## 3.5 方案总结

| 方案   | 说明                                    | 优点                                                         | 缺点                                                         |
| ------ | --------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 方案一 | Node上部署一个日志收集程序              | 每个Node仅需部署一个日志收集程序，资源消耗少，对应用无侵入   | 应用程序日志需要写到标准输出和标准错误输出，不支持多行日志   |
| 方案二 | 在方案一的基础上，Pod附加专用流转换容器 | 支持将容器中不同的日志分开；不影响kubectl logs等从 stdout 中获取数据 | 增加了开销和运维成本                                         |
| 方案三 | Pod中附加专用日志收集的容器             | 低耦合                                                       | 每个Pod启动一个日志收集代理，增加资源消耗，并增加运维维护成本 |
| 方案四 | 应用程序直接推送日志                    | 无需额外收集工具                                             | 侵入应用，增加应用复杂度                                     |



# 4. 部署

## 4.1 filebeat

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: logging
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: log
      paths:
      - /var/log/nginx
      document_type: k8s-nginx

    setup.template.name: "k8s-nginx"
    setup.template.pattern: "k8s-nginx-*"
    output.elasticsearch:
      hosts: ["elasticsearch:9200"]
      index: "k8s-nginx-%{+yyyy.MM.dd}"
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: logging
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        k8s-app: filebeat
        app: filebeat
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: filebeat
        image: elastic/filebeat:7.14.0 
        imagePullPolicy: IfNotPresent 
        args: [
          "-c", "/etc/filebeat.yml",
          "-e",
        ]
        volumeMounts:
        - name: config
          mountPath: /etc/filebeat.yml
          readOnly: true
          subPath: filebeat.yml
        - name: log
          mountPath: /var/log/
      volumes:
      - name: config
        configMap:
          defaultMode: 0755
          name: filebeat-config
      - name: log
        hostPath:
          path: /var/log/
          type: Directory
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
```



## 4.2 logstash

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-config
  namespace: logging
  labels:
    k8s-app: logstash-config
data:
  logstash.conf: |
      input {
        beats {
            port => "5044"
            codec => "json"
        }
      }
      filter{
        json{
                source =>  "message"
                remove_field => "message"
        }
      }
      output {
        elasticsearch {
            hosts => "elasticsearch:9200"
            index => "nginx-json-log-%{+YYYY.MM.dd}"
        }
      }
---
apiVersion: apps/v1 
kind: Deployment
metadata:
  name: logstash
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: logstash
  template:
    metadata:
      labels:
        k8s-app: logstash
    spec:
      containers:
      - name: logstash
        image: logstash:7.14.0 
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5044
        volumeMounts:
          - name: config-volume
            mountPath: /usr/share/logstash/pipeline/
      volumes:
      - name: config-volume
        configMap:
          name: logstash-config
          items:
          - key: logstash.conf
            path: logstash.conf
---
apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: logging
spec:
  type: ClusterIP
  selector:
    k8s-app: logstash
  ports:
  - port: 5044
    targetPort: 5044
    protocol: TCP
```



## 4.3 elasticsearch

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: elasticsearch-sc
provisioner: driver.longhorn.io        # 使用 longhorn 存储，可换成其他
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  dataLocality: disabled
  fromBackup: ""
  fsType: ext4
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-headless
  namespace: logging
  labels:
    app: elasticsearch
spec:
  clusterIP: None
  selector:
    k8s-app: elasticsearch
  ports:
    - port: 9200
      name: db
    - port: 9300
      name: internal
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
  labels:
    k8s-app: elasticsearch
spec:
  serviceName: elasticsearch-headless
  selector:
    matchLabels:
      k8s-app: elasticsearch
  template:
    metadata:
      labels:
        k8s-app: elasticsearch
    spec:
      containers:
      - image: elasticsearch:7.14.0
        name: elasticsearch
        resources:
          limits:
            cpu: 1
            memory: 2Gi
          requests:
            cpu: 0.5
            memory: 500Mi
        env:
          - name: "discovery.type"
            value: "single-node"
          - name: "xpack.security.enabled"
            value: "false"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx2g"
        ports:
        - containerPort: 9200
          name: db
          protocol: TCP
        - name: internal
          containerPort: 9300
        volumeMounts:
        - name: elasticsearch-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-data
    spec:
      storageClassName: elasticsearch-sc
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```



## 4.4 kibana

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging 
  labels:
    k8s-app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kibana
  template:
    metadata:
      labels:
        k8s-app: kibana
    spec:
      containers:
      - name: kibana
        image: kibana:7.14.0
        resources:
          limits:
            cpu: 1
            memory: 1G
          requests:
            cpu: 0.5
            memory: 500Mi
        env:
          - name: ELASTICSEARCH_HOSTS
            value: http://elasticsearch-headless:9200
        ports:
        - containerPort: 5601
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  type: NodePort
  selector:
    k8s-app: kibana
  ports:
  - port: 5601
    protocol: TCP
    targetPort: 5601
    nodePort: 30601
```

















