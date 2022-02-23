# 1. 简介

自主式 Pod 和 控制器管理的 Pod：

- 自主式Pod：Pod退出，不会被再次创建，因为无管理者（资源控制器）。
- 控制器管理的Pod： 在控制器的生命周期里，始终要维持 Pod 的副本数目

K8S 中内建了很多 controller (控制器)，这些相当于一个状态机，用来控制Pod的具体状态和行为



# 2. ReplicaSet

作用：**用来确保容器的应用副本数始终是用户定义的副本数。如果有容器异常退出，会创建新的Pod来代替；如果多出来，自动回收。**

RS 是RC (ReplicationController，已废弃) 的替代者，通过`selector标签`来认定哪些`pod`是属于它当前的，template 中的 labels 必须对应起来

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```



```bash
$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
nginx-26h68   1/1     Running   0          37s   app=web
nginx-42hmj   1/1     Running   0          37s   app=web
nginx-jsg8f   1/1     Running   0          37s   app=web

$ kubectl label pod nginx-26h68 app=nginx --overwrite=true
pod/nginx-26h68 labeled

$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE    LABELS
nginx-26h68   1/1     Running   0          112s   app=nginx  # 不再受 rs 管理
nginx-42hmj   1/1     Running   0          112s   app=web
nginx-cdt4w   1/1     Running   0          16s    app=web
nginx-jsg8f   1/1     Running   0          112s   app=web
```



# 3. Deployment

作用：自动管理ReplicaSet。ReplicaSet不支持rolling-update，但Deployment支持。

- 滚动升级和回滚应用 (创建一个新的RS，新RS中Pod增1，旧RS的Pod减1)
- 扩容和缩容
- 暂停和继续 Deployment

![rs](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-deployment-scale-replicas.png)



## 3.1 定义

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

```bash
# --record 记录版本升级操作命令详情
kubectl apply -f deploy-nginx.yaml --record
```



## 3.2 扩/缩容

```bash
kubectl scale deployment nginx-deployment --replicas 10
```



## 3.3 水平自动扩容

Horizontal Pod Autoscaling，Pod中，资源使用达到一定阈值时，自动触发

```bash
kubectl autoscale deployment nginx-deployment --min=10 --max=30 --cpu-percent=80

# 取消自动扩容
kubectl delete horizontalpodautoscalers.autoscaling nginx-deployment
```



## 3.4 升级

镜像更新, 会自动创建 RS

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.17.9
```



## 3.5 回滚

```bash
# 升级记录
kubectl rollout history deployment/nginx-deployment

# 回滚到最近一次
kubectl rollout undo deployment/nginx-deployment

# 升级/回滚状态
kubectl rollout status deployment/nginx-deployment
```



## 3.6 暂停和恢复

```bash
# 暂停，后续操作将不会立即重建Pod
kubectl rollout pause deployment/nginx-deployment

# 不会立即升级
kubectl set image deployment/nginx-deployment nginx=nginx:1.18.1

# 未新增 rollout 记录
kubectl rollout history deployment/nginx-deployment

# 设置资源
kubectl set resources deployment nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi

# 恢复
kubectl rollout resume deploy nginx
```

**版本更新策略**：默认25%替换

**清理历史版本**：可以通过设置 `spec.revisionHistoryLimit` 来指定 Deployment 最多保留多少个 `revision` 历史记录。默认保留所有的revision，如果该项设置为0，Deployment将不能被回退



# 4. DaemonSet

Daemonset 保证在每个Node上，都运行一个容器副本，典型的应用：

- 日志收集：fluentd，logstash
- 系统监控：Prometheus Node Exporter， collectd
- 系统程序：kube-proxy，kube-dns，ceph

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: gcr.io/google-containers/fluentd-elasticsearch:1.20
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers       
```




# 5.  Job

作用：负责批处理任务，即仅执行一次的任务，它保证批处理任务的一个或多个Pod成功结束

如果执行失败，则会重新创建一个Pod继续执行，直到成功

特殊说明：

- `.spec.template` 格式同 Pod
- `.spec.restartPolicy` 仅支持 Never 或 OnFailure
- `.spec.completions` 标志 Job 结束需要运行的Pod个数，默认为1
- `.spec.parallelism` 标志并行运行的 Pod 个数，默认为1
- `.spec.activeDeadlineSeconds` 标志失败 Pod的重试最大时间，超过这个时间将不会再重试

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec: 
  template:
    metadata:
      name: pi
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

```bash
$ kubectl get job
NAME   COMPLETIONS   DURATION   AGE
pi     1/1           10s        96s

$ kubectl get pod
NAME       READY   STATUS      RESTARTS   AGE
pi-mr59r   0/1     Completed   0          74s

$ kubectl logs pi-mr59r
3.1415926535897932384626...
```



# 6. CronJob

作用：定时Job

- 在给定时间点只执行一次
- 周期性地在给定时间点运行

特殊说明：

- `.spec.schedule`: 调度，必选字段，格式同Cron

- `.spec.jobTemplate`: 格式同 Pod
- `.spec.startingDeadlineSeconds`: 启动Job的期限，可选字段。如果因为任何原因而错过了被调度的时间，那么错过了执行时间的Job被认为是失败的
- `.spec.concurrencyPolicy`: 并发策略，可选字段
  - `Allow`: 默认，允许并发运行 Job
  - `Forbid`: 禁止并发Job，只能顺序执行
  - `Replace`: 用新的Job替换当前正在运行的 Job
- `.spec.suspend`: 挂起，可选字段，如果设置为true，后续所有执行都会被挂起。默认为fasle 
- `.spec.successfulJobsHistoryLimit` 和 `.spec.failedJobsHistoryLimit`: 历史限制，可选字段。它们指定了可以保留多少完成和失败的Job。默认值为3和1。如果设置为0，相关类型的Job完成后，将不会保留 

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec: 
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo 'hello world'
          restartPolicy: OnFailure
```

```bash
$ kubectl get cj
NAME    SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
hello   */1 * * * *   False     4        13s             7m13s

$ kubectl get job
NAME             COMPLETIONS   DURATION   AGE
hello-27337347   1/1           5s         6m37s
hello-27337348   1/1           6s         5m37s
hello-27337349   1/1           6s         4m37s

$ kubectl get pod
NAME                   READY   STATUS              RESTARTS   AGE
hello-27337347-rbrk2   0/1     Completed           0          7m8s
hello-27337348-bnnzt   0/1     Completed           0          6m8s
hello-27337349-6wfgk   0/1     Completed           0          5m8s
```



# 7. StatefulSet 

作用：解决有状态服务的问题，可以确保部署和 scale 的顺序

典型的使用场景：

- 稳定的持久化存储，即 Pod 重新调度后，还能够访问到相同的持久化数据，基于PVC来实现
- 稳定的网络标识，即 Pod 重新调度后其 PodName 和 HostName 不变，基于 Headless Service （即没有Cluster IP的Service）来实现
- 有序部署、有序扩展，即Pod是有序的，在部署和扩展时，要按照定义的顺序依次进行 (即从 0 到N - 1, 在下一个Pod 运行前，所有 Pod 必须是 Running 和 Ready 状态)，基于 Init Containers 来实现
- 有序收缩、有序删除（即从 N-1 到 0）

```yaml
# Storages
apiVersion: v1 
kind: PersistentVolume 
metadata:
  name: nfs-pv 
spec:
  capacity:
    storage: 5Gi 
  accessModes:
  - ReadWriteOnce 
  persistentVolumeReclaimPolicy: Retain
  nfs:
   path: /nfsdata
   server: 192.168.80.240

---
# MySQL configurations
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql
  labels:
    app: mysql
data:
  master.cnf: |
    # Apply this config only on the master.
    [mysqld]
    log-bin
    default-time-zone='+8:00'
    character-set-client-handshake=FALSE
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    init_connect='SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci'
  slave.cnf: |
    # Apply this config only on slaves.
    [mysqld]
    super-read-only
    default-time-zone='+8:00'
    character-set-client-handshake=FALSE
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    init_connect='SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci'
    
---
# Headless service for stable DNS entries of StatefulSet members.
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  clusterIP: None
  selector:
    app: mysql

---
# Client service for connecting to any MySQL instance for reads.
# For writes, you must instead connect to the master: mysql-0.mysql.
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  labels:
    app: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  selector:
    app: mysql
    
---
# Applications
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  serviceName: mysql
  replicas: 3
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:5.7
        command:
        - bash
        - "-c"
        - |
          set -ex
          # Generate mysql server-id from pod ordinal index.
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          # Add an offset to avoid reserved server-id=0 value.
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
          # Copy appropriate conf.d files from config-map to emptyDir.
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config-map/master.cnf /mnt/conf.d/
          else
            cp /mnt/config-map/slave.cnf /mnt/conf.d/
          fi
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d/
        - name: config-map
          mountPath: /mnt/config-map
      - name: clone-mysql
        image: ipunktbs/xtrabackup
        command:
        - bash
        - "-c"
        - |
          set -ex
          # Skip the clone if data already exists.
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          # Skip the clone on master (ordinal index 0).
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal -eq 0 ]] && exit 0
          # Clone data from previous peer.
          ncat --recv-only mysql-$(($ordinal-1)).mysql 3307 | xbstream -x -C /var/lib/mysql
          # Prepare the backup.
          xtrabackup --prepare --target-dir=/var/lib/mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      containers:
      - name: mysql
        image: mysql:5.7
        env:
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "1"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 500m
            memory: 512m
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            # Check we can execute queries over TCP (skip-networking is off).
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
      - name: xtrabackup
        image: ipunktbs/xtrabackup
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - "-c"
        - |
          set -ex
          cd /var/lib/mysql

          # Determine binlog position of cloned data, if any.
          if [[ -f xtrabackup_slave_info && "x$(<xtrabackup_slave_info)" != "x" ]]; then
            # XtraBackup already generated a partial "CHANGE MASTER TO" query
            # because we're cloning from an existing slave. (Need to remove the tailing semicolon!)
            cat xtrabackup_slave_info | sed -E 's/;$//g' > change_master_to.sql.in
            # Ignore xtrabackup_binlog_info in this case (it's useless).
            rm -f xtrabackup_slave_info xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then
            # We're cloning directly from master. Parse binlog position.
            [[ `cat xtrabackup_binlog_info` =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm -f xtrabackup_binlog_info xtrabackup_slave_info
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi

          # Check if we need to complete a clone by starting replication.
          if [[ -f change_master_to.sql.in ]]; then
            echo "Waiting for mysqld to be ready (accepting connections)"
            until mysql -h 127.0.0.1 -e "SELECT 1"; do sleep 1; done

            echo "Initializing replication from clone position"
            mysql -h 127.0.0.1 \
                  -e "$(<change_master_to.sql.in), \
                          MASTER_HOST='mysql-0.mysql', \
                          MASTER_USER='root', \
                          MASTER_PASSWORD='', \
                          MASTER_CONNECT_RETRY=10; \
                        START SLAVE;" || exit 1
            # In case of container restart, attempt this at-most-once.
            mv change_master_to.sql.in change_master_to.sql.orig
          fi

          # Start a server to send backups when requested by peers.
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root"
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```



# 8. Horizontal Pod AutoScalling

应用的资源使用率通常有高峰和低谷的时候，如何削峰填谷，提高集群的整体资源利用率，HPA 提供了 Pod 的水平自动缩放功能

适用于Deployment和ReplicaSet，支持根据Pod的CPU、内存的利用率，用户自定义的metric等，进行自动扩/缩容

