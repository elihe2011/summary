# 1. 构建镜像

## 1.1 entrypoint.sh

```bash
#!/bin/bash

NODE_ID=${HOSTNAME:6}
LISTENERS="CONTROLLER://:9093,PLAINTEXT://0.0.0.0:9092,EXTERNAL://0.0.0.0:$((30090 + $NODE_ID))"
ADVERTISED_LISTENERS="PLAINTEXT://kafka-$NODE_ID.$SERVICE.$NAMESPACE.svc.cluster.local:9092,EXTERNAL://${K8S_NODE_IP}:$((30090 + $NODE_ID))"

CONTROLLER_QUORUM_VOTERS=""
for i in $( seq 0 $REPLICAS); do
    if [[ $i != $REPLICAS ]]; then
        CONTROLLER_QUORUM_VOTERS="$CONTROLLER_QUORUM_VOTERS$i@kafka-$i.$SERVICE.$NAMESPACE.svc.cluster.local:9093,"
    else
        CONTROLLER_QUORUM_VOTERS=${CONTROLLER_QUORUM_VOTERS::-1}
    fi
done

mkdir -p $SHARE_DIR/$NODE_ID

sed -e "s+^node.id=.*+node.id=${NODE_ID}+" \
-e "s+^controller.quorum.voters=.*+controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS+" \
-e "s+^listeners=.*+listeners=$LISTENERS+" \
-e "s+^advertised.listeners=.*+advertised.listeners=$ADVERTISED_LISTENERS+" \
-e "s+\(^listener.security.protocol.map=.*\)+\1,EXTERNAL:PLAINTEXT+" \
-e "s+^log.dirs=.*+log.dirs=$SHARE_DIR/$NODE_ID+" \
/opt/kafka/config/kraft/server.properties > server.properties.updated \
&& mv server.properties.updated /opt/kafka/config/kraft/server.properties

/opt/kafka/bin/kafka-storage.sh format -t $CLUSTER_ID -c /opt/kafka/config/kraft/server.properties

exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
```

## 1.2 Dockerfile
```dockerfile
FROM openjdk:11

ENV KAFKA_VERSION=3.0.0
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka
ENV PATH=${PATH}:${KAFKA_HOME}/bin

LABEL name="kafka" version=${KAFKA_VERSION}

RUN wget -O /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt \
 && rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} \
 && rm -rf /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

COPY ./entrypoint.sh /
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]
```

## 1.3 编译镜像
```
$ docker build -t kafka:3.0.0 .
```



# 2. 集群安装

## 2.1 创建 namespace

```bash
$ mkdir ~/kafka && cd $_

$ cat > kafka-namespace.yml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: "kafka-cluster"
  labels:
    name: "kafka-cluster"
EOF

$ kubectl apply -f kafka-namespace.yml
$ kubectl get ns
kafka-cluster     Active   7s
```



## 2.2 创建 PV

暂用本地目录

```bash
# 1. 所有节点上，挂载相应的存储盘或路径
$ mkdir -p /data/kafka

# 2. 创建PV
$ cat > kafka-pv.yml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kafka-pv
  namespace: kafka-cluster
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /data/kafka
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-master
          - k8s-node01
          - k8s-node02
EOF

$ kubectl apply -f kafka-pv.yml
```



## 2.3 创建 PVC

```bash
$ cat > kafka-pvc.yml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kafka-pvc
  namespace: kafka-cluster
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

$ kubectl apply -f kafka-pvc.yml
```



## 2.4 创建 Service (无头服务)

```bash
$ cat > kafka-headless.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  labels:
    app: kafka-app
  namespace: kafka-cluster
spec:
  clusterIP: None
  ports:
    - name: kafka
      port: 9092
      protocol: TCP
      targetPort: 9092
  selector:
    app: kafka-app
EOF

$ kubectl apply -f  kafka-headless.yml 
```



## 2.5 创建 StatefulSet

```bash
$ cat > kafka-app.yml <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  labels:
    app: kafka-app
  namespace: kafka-cluster
spec:
  serviceName: kafka-headless
  replicas: 3
  selector:
    matchLabels:
      app: kafka-app
  template:
    metadata:
      labels:
        app: kafka-app
    spec:
      volumes:
        - name: kafka-storage
          persistentVolumeClaim:
            claimName: kafka-pvc
      containers:
        - name: kafka-container
          image: kafka:3.0.0
          ports:
            - containerPort: 9092
            - containerPort: 9093
          env:
            - name: REPLICAS
              value: '3'
            - name: CLUSTER_ID
              value: 9dJzdGvfTPaCY4e8klXaDQ
            - name: SERVICE
              value: kafka-svc
            - name: NAMESPACE
              value: kafka-cluster
            - name: SHARE_DIR
              value: /data/kafka
            - name: K8S_NODE_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
          volumeMounts:
            - name: kafka-storage
              mountPath: /data/kafka
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - kafka-app
              topologyKey: kubernetes.io/hostname
EOF

$ kubectl apply -f  kafka-app.yml 
```



## 2.6 创建 Service (外部访问)

```bash
cat > kafka-external-svc.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kafka-external-0
  labels:
    app: kafka-app
  namespace: kafka-cluster
spec:
  type: NodePort
  selector:
    statefulset.kubernetes.io/pod-name: kafka-0
  ports:
    - protocol: TCP
      port: 30090
      targetPort: 30090
      nodePort: 30090
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-external-1
  labels:
    app: kafka-app
  namespace: kafka-cluster
spec:
  type: NodePort
  selector:
    statefulset.kubernetes.io/pod-name: kafka-1
  ports:
    - protocol: TCP
      port: 30091
      targetPort: 30091
      nodePort: 30091
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-external-2
  labels:
    app: kafka-app
  namespace: kafka-cluster
spec:
  type: NodePort
  selector:
    statefulset.kubernetes.io/pod-name: kafka-2
  ports:
    - protocol: TCP
      port: 30092
      targetPort: 30092
      nodePort: 30092
EOF
```



# 3. 验证

## 3.1 kafkacat

```bash
# 安装测试工具
$ apt install kafkacat

# 获取 broker 列表
$ kafkacat -b 192.168.80.240:30090 -L
Metadata for all topics (from broker -1: 192.168.80.240:30090/bootstrap):
 3 brokers:
  broker 0 at 192.168.80.242:30090
  broker 1 at 192.168.80.241:30091 (controller)
  broker 2 at 192.168.80.240:30092
 0 topics:


# 发布消息
$ kafkacat -b 192.168.80.240:30090 -t topic -P
hello world
abc
kafka test

# 订阅消息
$ kafkacat -b 192.168.80.241:30091 -t topic -C
% Reached end of topic topic [0] at offset 12
hello world
% Reached end of topic topic [0] at offset 13
abc
% Reached end of topic topic [0] at offset 14
kafka test

```



## 3.2 kafka 脚本

```bash
$ kubectl exec -it kafka-0 -n kafka-cluster -- /bin/bash

> kafka-topics.sh --create --partitions 3 --replication-factor 1 --topic test --bootstrap-server kafka-0.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-1.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-2.kafka-svc.kafka-cluster.svc.cluster.local:9092 

> kafka-console-producer.sh --topic test --broker-list kafka-0.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-1.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-2.kafka-svc.kafka-cluster.svc.cluster.local:9092

> kafka-console-consumer.sh --from-beginning --topic test --bootstrap-server kafka-0.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-1.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-2.kafka-svc.kafka-cluster.svc.cluster.local:9092
```





参考资料：

https://adityasridhar.com/posts/how-to-easily-install-kafka-without-zookeeper  【主机安装kafka，不带ZK】

https://developer.ibm.com/tutorials/kafka-in-kubernetes/ 【kafka 安装到 k8s】

https://github.com/IBM/kraft-mode-kafka-on-kubernetes/blob/main/kubernetes/kafka.yml

https://blog.csdn.net/boling_cavalry/article/details/105466163

https://www.orchome.com/1903

https://segmentfault.com/a/1190000020715650

https://tsuyoshiushio.medium.com/configuring-kafka-on-kubernetes-makes-available-from-an-external-client-with-helm-96e9308ee9f4     【loadblancer】

https://blog.51cto.com/u_15127500/3790439  【kafkacat 使用】