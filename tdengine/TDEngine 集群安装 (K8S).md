# 1. 构建镜像

## 1.1 entrypoint.sh

```bash
#!/bin/bash

set +e
ulimit -c unlimited
sysctl -w kernel.core_pattern=/corefile/core-%e-%p

if [ "x$TZ" != "x" ]; then
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
fi

if [ "$TAOS_FQDN" = "" ]; then
    echo "TAOS_FQDN not set"
    exit 1
fi

sed -i "s#.*fqdn.*#fqdn    ${TAOS_FQDN}#" /etc/taos/taos.cfg
if [ $? -ne 0 ]; then
    echo "refreshing fqdn failed"
    exit 1
fi

if [ "x$TAOS_FIRST_EP" != "x" ]; then
    sed -i "s#.*firstEp.*#firstEp     ${TAOS_FIRST_EP}#" /etc/taos/taos.cfg
    if [ $? -ne 0 ]; then
        echo "refreshing firstEp failed"
        exit 1
    fi
fi

if [ "x$TAOS_SERVER_PORT" != "x" ]; then
    sed -i "s#.*serverPort.*#serverPort     ${TAOS_SERVER_PORT}#" /etc/taos/taos.cfg
    if [ $? -ne 0 ]; then
        echo "refreshing serverPort failed"
        exit 1
    fi
fi


CLUSTER=${CLUSTER:=}
FIRST_EP_HOST=${TAOS_FIRST_EP%:*}
SERVER_PORT=${TAOS_SERVER_PORT:-6030}


if [ "$CLUSTER" = "" ]; then
    # single node
    $@
elif [ "$TAOS_FQDN" = "$FIRST_EP_HOST" ] ; then
    # master node
    $@
else
    # follower, wait for master node ready
    while true
    do
        taos -h $FIRST_EP_HOST -n startup > /dev/null
        if [ $? -eq 0 ]; then
            taos -h $FIRST_EP_HOST -s "create dnode \"$TAOS_FQDN:$SERVER_PORT\";"
            break
        fi
        sleep 1s
    done

    $@
fi
```



## 1.2 Dockerfile

通过源码方式构建镜像，同时支持 AMD64 & ARM64 系统

```dockerfile
FROM ubuntu:18.04 as builder
RUN apt-get update \
    && apt-get install -y gcc cmake build-essential git wget  \
    && apt-get clean \
    && cd /usr/local/src \
    && wget https://github.com/taosdata/TDengine/archive/refs/tags/ver-2.4.0.0.tar.gz \
    && tar zxvf ver-2.4.0.0.tar.gz && cd TDengine-ver-2.4.0.0 \
    && mkdir debug && cd debug \
    && cmake .. && cmake --build . && make install
WORKDIR /root


FROM ubuntu:18.04
LABEL MAINTAINER="eli.he@outlook.com>"

COPY ./entrypoint.sh /usr/bin/
COPY --from=0 /usr/local/taos /usr/local/taos
COPY --from=0 /etc/taos /etc/taos

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y apt-utils locales tzdata curl wget net-tools iproute2 iputils-ping sysstat binutils \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && chmod +x /usr/bin/entrypoint.sh \
    && ln -s /usr/local/taos/bin/taos /usr/bin/taos \
    && ln -s /usr/local/taos/bin/taosd       /usr/bin/taosd \
    && ln -s /usr/local/taos/bin/taosdump    /usr/bin/taosdump \
    && ln -s /usr/local/taos/bin/taosdemo    /usr/bin/taosdemo \
    && ln -s /usr/local/taos/bin/remove.sh   /usr/bin/rmtaos \
    && ln -s /usr/local/taos/include/taoserror.h  /usr/include/taoserror.h \
    && ln -s /usr/local/taos/include/taos.h  /usr/include/taos.h \
    && ln -s /usr/local/taos/driver/libtaos.so.2.4.0.0  /usr/lib/libtaos.so.1 \
    && ln -s /usr/lib/libtaos.so.1 /usr/lib/libtaos.so  \
    && mkdir -p /var/lib/taos \
    && mkdir -p /var/log/taos \
    && chmod 777 /var/log/taos

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

WORKDIR /etc/taos
EXPOSE 6030 6031 6032 6033 6034 6035 6036 6037 6038 6039 6040 6041 6042
CMD ["taosd"]
VOLUME [ "/var/lib/taos", "/var/log/taos", "/corefile" ]
ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
```



## 1.3 生成镜像

```bash
docker build -t tdengine:2.4.0.0 .
```



# 2. 安装集群

## 2.1 创建 namespace

```bash
$ mkdir ~/taos && cd $_

$ cat > taos-namespace.yml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: taos-cluster
EOF

$ kubectl apply -f taos-namespace.yml
$ kubectl get ns
taos-cluster     Active   7s
```



## 2.2 创建 ConfigMap

```bash
$ cat > taos-configmap.yml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: taos-cfg
  namespace: taos-cluster
  labels:
    app: tdengine
data:
  CLUSTER: "1"
  TAOS_KEEP: "3650"
  TAOS_DEBUG_FLAG: "135"
EOF

$ kubectl apply -f taos-configmap.yml
```



## 2.3 创建 PV

暂时使用本地文件系统，可换成 Ceph 等

```bash
# 1. 所有节点上，挂载相应的存储盘或路径
$ mkdir -p /data/tdengine

# 2. 创建PV
$ cat > taos-pv.yml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: taos-pv
  namespace: taos-cluster
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: taos-storage
  local:
    path: /data/tdengine
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

$ kubectl apply -f taos-pv.yml
```



## 2.4 创建 PVC

```bash
$ cat > taos-pvc.yml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: taos-pvc
  namespace: taos-cluster
spec:
  storageClassName: taos-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

$ kubectl apply -f taos-pvc.yml
```



## 2.5 创建 Service (无头服务)

```bash
$ cat > taos-headless.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: taosd
  namespace: taos-cluster
  labels:
    app: tdengine
spec:
  clusterIP: None
  ports:
  - name: tcp6030
    protocol: "TCP"
    port: 6030
  - name: tcp6035
    protocol: "TCP"
    port: 6035
  - name: tcp6041
    protocol: "TCP"
    port: 6041
  - name: udp6030
    protocol: "UDP"
    port: 6030
  - name: udp6031
    protocol: "UDP"
    port: 6031
  - name: udp6032
    protocol: "UDP"
    port: 6032
  - name: udp6033
    protocol: "UDP"
    port: 6033
  - name: udp6034
    protocol: "UDP"
    port: 6034
  - name: udp6035
    protocol: "UDP"
    port: 6035
  - name: udp6036
    protocol: "UDP"
    port: 6036
  - name: udp6037
    protocol: "UDP"
    port: 6037
  - name: udp6038
    protocol: "UDP"
    port: 6038
  - name: udp6039
    protocol: "UDP"
    port: 6039
  - name: udp6040
    protocol: "UDP"
    port: 6040
  selector:
    app: tdengine
EOF

$ kubectl apply -f  taos-headless.yml 
```



## 2.6 创建 StatefulSet

```bash
$ cat > taos-app.yml <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: "tdengine"
  namespace: taos-cluster
  labels:
    app: "tdengine"
spec:
  serviceName: "taosd"
  replicas: 3
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: "tdengine"
  template:
    metadata:
      name: "tdengine"
      labels:
        app: "tdengine"
    spec:
      volumes:
      - name: taos-storage
        persistentVolumeClaim:
          claimName: taos-pvc
      containers:
      - name: "tdengine"
        image: "tdengine-server:2.4.0.0"
        envFrom:
        - configMapRef:
            name: taos-cfg
        ports:
        - name: tcp6030
          protocol: "TCP"
          containerPort: 6030
        - name: tcp6035
          protocol: "TCP"
          containerPort: 6035
        - name: tcp6041
          protocol: "TCP"
          containerPort: 6041
        - name: udp6030
          protocol: "UDP"
          containerPort: 6030
        - name: udp6031
          protocol: "UDP"
          containerPort: 6031
        - name: udp6032
          protocol: "UDP"
          containerPort: 6032
        - name: udp6033
          protocol: "UDP"
          containerPort: 6033
        - name: udp6034
          protocol: "UDP"
          containerPort: 6034
        - name: udp6035
          protocol: "UDP"
          containerPort: 6035
        - name: udp6036
          protocol: "UDP"
          containerPort: 6036
        - name: udp6037
          protocol: "UDP"
          containerPort: 6037
        - name: udp6038
          protocol: "UDP"
          containerPort: 6038
        - name: udp6039
          protocol: "UDP"
          containerPort: 6039
        - name: udp6040
          protocol: "UDP"
          containerPort: 6040
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: SERVICE_NAME
          value: "taosd"
        - name: STS_NAME
          value: "tdengine"
        - name: STS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: TZ
          value: "Asia/Shanghai"
        # TAOS_ prefix will configured in taos.cfg, strip prefix and camelCase.
        - name: TAOS_SERVER_PORT
          value: "6030"
        # Must set if you want a cluster.
        - name: TAOS_FIRST_EP
          value: "\$(STS_NAME)-0.\$(SERVICE_NAME).\$(STS_NAMESPACE).svc.cluster.local:\$(TAOS_SERVER_PORT)"
        # TAOS_FQND should always be setted in k8s env.
        - name: TAOS_FQDN
          value: "\$(POD_NAME).\$(SERVICE_NAME).\$(STS_NAMESPACE).svc.cluster.local"
        volumeMounts:
        - name: taos-storage
          mountPath: /var/lib/taos
        readinessProbe:
          exec:
            command:
            - taos
            - -s
            - "show mnodes"
          initialDelaySeconds: 5
          timeoutSeconds: 5000
        livenessProbe:
          tcpSocket:
            port: 6030
          initialDelaySeconds: 15
          periodSeconds: 20    
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
                  - tdengine
              topologyKey: kubernetes.io/hostname    
EOF

$ kubectl apply -f  taos-app.yml 
```



## 2.7 创建 Service (外部访问)

```bash
cat > taos-external-svc.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: taosd-np
  namespace: taos-cluster
  labels:
    app: tdengine
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
spec:
  type: NodePort
  selector:
    app: tdengine
  ports:
  - name: tcp6030
    protocol: "TCP"
    port: 6030
    targetPort: 6030
    nodePort: 36030
  - name: tcp6035
    protocol: "TCP"
    port: 6035
    targetPort: 6035
    nodePort: 36035
  - name: tcp6041
    protocol: "TCP"
    port: 6041
    targetPort: 6041
    nodePort: 36041
EOF
```



# 3. 验证

## 3.1 kubectl

登录到容器中，执行命令检查集群状态

```bash
$ kubectl exec -it tdengine-0 -n taos-cluster -- taos -s "show dnodes;"

Welcome to the TDengine shell from Linux, Client Version:2.2.2.0
Copyright (c) 2020 by TAOS Data, Inc. All rights reserved.

taos> show dnodes;
   id   |           end_point            | vnodes | cores  |   status   | role  |       create_time       |      offline reason      |
======================================================================================================================================
      1 | tdengine-0.taosd.taos-clust... |      0 |      2 | ready      | any   | 2021-11-26 02:42:25.932 |                          |
      2 | tdengine-1.taosd.taos-clust... |      1 |      2 | ready      | any   | 2021-11-26 02:42:35.633 |                          |
      3 | tdengine-2.taosd.taos-clust... |      1 |      2 | ready      | any   | 2021-11-26 02:42:48.004 |                          |
Query OK, 3 row(s) in set (0.001099s)
```



## 3.2 restful

容器外部，使用restful接口访问，注意：容器外，无法之间使用taos客户端连接

```bash
$ curl -H 'Authorization: Basic cm9vdDp0YW9zZGF0YQ==' -d 'show databases;' 192.168.80.240:36041/rest/sql
{"status":"succ","head":["name","created_time","ntables","vgroups","replica","quorum","days","keep","cache(MB)","blocks","minrows","maxrows","wallevel","fsync","comp","cachelast","precision","update","status"],"column_meta":[["name",8,32],["created_time",9,8],["ntables",4,4],["vgroups",4,4],["replica",3,2],["quorum",3,2],["days",3,2],["keep",8,24],["cache(MB)",4,4],["blocks",4,4],["minrows",4,4],["maxrows",4,4],["wallevel",2,1],["fsync",4,4],["comp",2,1],["cachelast",2,1],["precision",8,3],["update",2,1],["status",8,10]],"data":[["log","2021-11-26 02:42:26.936",6,1,1,1,10,"30",1,3,100,4096,1,3000,2,0,"us",0,"ready"],["iec61850","2021-12-01 01:13:56.176",59,1,1,1,10,"365",16,6,100,4096,1,3000,2,0,"ms",0,"ready"]],"rows":2}

$ curl -u root:taosdata -d 'show databases;' 192.168.80.240:36041/rest/sql
```



参考资料：

https://github.com/taosdata/TDengine-Operator  【官方 kubernetes 安装tdengine 方案】

