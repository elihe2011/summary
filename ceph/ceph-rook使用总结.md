# 1. 简介

Rook 是 Kubernetes 的开源云原生存储编排器，为各种存储解决方案提供平台、框架和支持，以与云原生环境进行原生集成。

Rook是一个自管理的分布式存储编排系统，可以为Kubernetes提供便利的存储解决方案，Rook本身并不提供存储，而是在Kubernetes和存储之间提供适配层，简化存储系统的部署和维护工作。目前，主要支持存储系统包括但不限于Ceph(主推)、Cassandra、NFS。

![img](https://rook.io/docs/rook/v1.9/media/kubernetes.png)



## 1.1 Ceph 要求

### 1.1.1 Disk

Ceph 集群的的存储要求，需要满足至少一项：

- Raw devices (no partitions or formatted filesystems)
- Raw partitions (no formatted filesystem)
- LVM Logical Volumes (no formatted filesystem)
- Persistent Volumes available from a storage class in `block` mode

如下，sdb, sdc 满足

```bash
$ lsblk -f
NAME                  FSTYPE      LABEL UUID                                   MOUNTPOINT
sda
├─sda1                vfat              CD24-112D                              /boot/efi
└─sda2                LVM2_member       6jLY4m-0F31-CgVe-c4Ei-SHcF-sOBU-ds00Bi
  ├─ubuntu--vg-root   ext4              167ef25c-3192-43a1-a723-3bf180c302df   /
  └─ubuntu--vg-swap_1 swap              cef6ab38-1e6c-4686-95f9-e4e70e1b125f
sdb
sdc
sr0
```



### 1.1.2 LVM

Ceph OSDs have a dependency on LVM in the following scenarios:

- OSDs are created on raw devices or partitions
- If encryption is enabled (`encryptedDevice: "true"` in the cluster CR)
- A `metadata` device is specified

LVM is not required for OSDs in these scenarios:

- Creating OSDs on PVCs using the `storageClassDeviceSets`

安装 lvm2 支持：

```bash
# CentOS
yum install -y lvm2

# Debian/Ubuntu
apt install -y lvm2
```



### 1.1.3 Kernel

内核版本：

- 4.19.z
- 5.x

内核升级:

```bash
$ uname -r
4.15.0-29-generic

# 升级内核
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.1.21/linux-headers-5.1.21-050121_5.1.21-050121.201907280731_all.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.1.21/linux-headers-5.1.21-050121-generic_5.1.21-050121.201907280731_arm64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.1.21/linux-image-unsigned-5.1.21-050121-generic_5.1.21-050121.201907280731_arm64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.1.21/linux-modules-5.1.21-050121-generic_5.1.21-050121.201907280731_arm64.deb

dpkg -i *.deb

reboot

# 是否支持
modprobe rbd

$ uname -r
5.1.21-050121-generic
```



## 1.2 Rook 部署要求

- K8s v1.16+
- 至少3个工作节点
- 每个工作节点至少一块未使用的硬盘
- Ceph Nautilus(14.2.22)+



# 2. 准备工作

## 2.1 软件版本

| 软件        | 版本    | 备注        |
| ----------- | ------- | ----------- |
| ubuntu      | 18.04   | aarch64     |
| kuberenetes | 1.21.4  |             |
| docker      | 20.10.7 |             |
| rook        | 1.9.12  |             |
| ceph        | v17.2.0 | Ceph Quincy |



## 2.2 设备列表

| **角色**   | **IP**        | **组件**                                                     |
| ---------- | ------------- | ------------------------------------------------------------ |
| k8s-master | 192.168.3.191 | kube-apiserver，kube-controller-manager，kube-scheduler，docker, etcd |
| k8s-node01 | 192.168.3.192 | kubelet，kube-proxy，docker，etcd                            |
| k8s-node02 | 192.168.3.193 | kubelet，kube-proxy，docker，etcd                            |



由于要求至少三个节点，暂时去除主控节点的污点，当工作节点使用：

```bash
$ kubectl get node -o yaml | grep taint -A 5
    taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/master
  status:
    addresses:
    - address: 192.168.3.191
    
$ kubectl taint node k8s-master node-role.kubernetes.io/master-
```



## 2.3 证书管理

```bash
wget https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml

kubectl apply -f cert-manager.yaml

kubectl get pod -n cert-manager
```



# 3. 安装部署

## 3.1 下载

```bash
wget https://github.com/rook/rook/archive/refs/tags/v1.9.12.tar.gz

tar zxvf v1.9.12.tar.gz

cd rook-1.9.12/deploy/examples/
```



## 3.2 公共资源

包含NS、SA、RBAC、CRDs 等

```bash
kubectl apply -f common.yaml -f crds.yaml
```



## 3.3 Operator

镜像仓库更换为阿里云

```bash
$ vi operator.yaml 
  ...
  # The default version of CSI supported by Rook will be started. To change the version
  # of the CSI driver to something other than what is officially supported, change
  # these images to the desired release of the CSI driver.
  ROOK_CSI_CEPH_IMAGE: "quay.io/cephcsi/cephcsi:v3.6.2"
  ROOK_CSI_REGISTRAR_IMAGE: "registry.aliyuncs.com/google_containers/csi-node-driver-registrar:v2.5.1"
  ROOK_CSI_RESIZER_IMAGE: "registry.aliyuncs.com/google_containers/csi-resizer:v1.4.0"
  ROOK_CSI_PROVISIONER_IMAGE: "registry.aliyuncs.com/google_containers/csi-provisioner:v3.1.0"
  ROOK_CSI_SNAPSHOTTER_IMAGE: "registry.aliyuncs.com/google_containers/csi-snapshotter:v6.0.1"
  ROOK_CSI_ATTACHER_IMAGE: "registry.aliyuncs.com/google_containers/csi-attacher:v3.4.0"
  ROOK_CSI_NFS_IMAGE: "registry.aliyuncs.com/google_containers/nfsplugin:v4.0.0"

          
$ kubectl apply -f operator.yaml
```



## 3.4 Cluster CRD

节点和设备设置：由于测试规划的磁盘大小均为 10GB，需要开启参数 databaseSizeMB & journalSizeMB

```bash
$ vi cluster.yaml
  ...
    storage: # cluster level storage configuration and selection
    useAllNodes: true
    useAllDevices: false
    deviceFilter: sd[b,c]   # 指定设备名称，也可以在下面独立配置每台设备的信息
    config:
      # crushRoot: "custom-root" # specify a non-default root label for the CRUSH map
      # metadataDevice: "md0" # specify a non-rotational storage so ceph-volume will use it as block db device of bluestore.
      databaseSizeMB: "1024" # uncomment if the disks are smaller than 100 GB
      journalSizeMB: "1024"  # uncomment if the disks are 20 GB or smaller
      # osdsPerDevice: "1" # this value can be overridden at the node or device level
      # encryptedDevice: "true" # the default value for this option is "false"
# Individual nodes and their config can be specified as well, but 'useAllNodes' above must be set to false. Then, only the named
# nodes below will be used as storage resources.  Each node's 'name' field should match their 'kubernetes.io/hostname' label.
    # nodes:
    #   - name: "172.17.4.201"
    #     devices: # specific devices to use for storage can be specified for each node
    #       - name: "sdb"
    #       - name: "nvme01" # multiple osds can be created on high performance devices
    #         config:
    #           osdsPerDevice: "5"
    #       - name: "/dev/disk/by-id/ata-ST4000DM004-XXXX" # devices can be specified using full udev paths
    #     config: # configuration can be specified at the node level which overrides the cluster level config
    #   - name: "172.17.4.301"
    #     deviceFilter: "^sd."
    # when onlyApplyOSDPlacement is false, will merge both placement.All() and placement.osd

  ...

$ kubectl apply -f cluster.yaml

$ kubectl get pod -n rook-ceph --watch
```



## 3.5 Toolbox

```bash
$ kubectl create -f toolbox.yaml

$ kubectl -n rook-ceph get pod -l "app=rook-ceph-tools"
NAME                               READY   STATUS    RESTARTS   AGE
rook-ceph-tools-79b8797fd6-lnvnd   1/1     Running   0          52m

$ [rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph -s
  cluster:
    id:     bb840d84-3c64-4004-b502-4886318a3eb0
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,b,c (age 4m)
    mgr: a(active, since 2m), standbys: b
    osd: 3 osds: 3 up (since 3m), 3 in (since 3m)

  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   15 MiB used, 60 GiB / 60 GiB avail
    pgs:     1 active+clean

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph device ls
DEVICE                           HOST:DEV                                      DAEMONS            WEAR  LIFE EXPECTANCY
QEMU_HARDDISK_drive-scsi0-0-0-2  k8s-master:sdb k8s-node01:sdb k8s-node02:sdb  osd.0 osd.1 osd.2

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph df
--- RAW STORAGE ---
CLASS    SIZE   AVAIL    USED  RAW USED  %RAW USED
hdd    60 GiB  60 GiB  15 MiB    15 MiB       0.02
TOTAL  60 GiB  60 GiB  15 MiB    15 MiB       0.02

--- POOLS ---
POOL                   ID  PGS  STORED  OBJECTS  USED  %USED  MAX AVAIL
device_health_metrics   1    1     0 B        0   0 B      0     19 GiB

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph mgr services
{
    "dashboard": "https://10.244.1.60:8443/",
    "prometheus": "http://10.244.1.60:9283/"
}

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph auth ls
osd.0
        key: AQCwD01jX7YGNhAAijYvcha2MlioaZOSbtZG3Q==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
...
mgr.a
        key: AQBfUU9jjipvChAA/S2N1P/caiVTswLluF2swQ==
        caps: [mds] allow *
        caps: [mon] allow profile mgr
        caps: [osd] allow *
mgr.b
        key: AQBgUU9jhEhpMBAA7D2ivGtvSDRAl+2nDVZp7w==
        caps: [mds] allow *
        caps: [mon] allow profile mgr
        caps: [osd] allow *


[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph config set mgr mgr/dashboard/ssl false
[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph config get mgr mgr/dashboard/ssl
false

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ rados df
POOL_NAME              USED  OBJECTS  CLONES  COPIES  MISSING_ON_PRIMARY  UNFOUND  DEGRADED  RD_OPS   RD  WR_OPS   WR  USED COMPR  UNDER COMPR
device_health_metrics   0 B        0       0       0                   0        0         0       0  0 B       0  0 B         0 B          0 B

total_objects    0
total_used       15 MiB
total_avail      60 GiB
total_space      60 GiB

[rook@rook-ceph-tools-79b8797fd6-lnvnd /]$ ceph osd status
ID  HOST         USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  k8s-node01  5080k  19.9G      0        0       0        0   exists,up
 1  k8s-node02  5080k  19.9G      0        0       0        0   exists,up
 2  k8s-master  5080k  19.9G      0        0       0        0   exists,up
```



## 3.6 Dashboard

由于 mgr 存在主备，且备节点无法访问，需要指定访问主节点：

```bash
$ vi dashboard-external-https.yaml
...
spec:
  ports:
    - name: dashboard
      port: 8443
      protocol: TCP
      targetPort: 8443
  selector:
    app: rook-ceph-mgr
    ceph_daemon_id: a             # 新增
    rook_cluster: rook-ceph

$ kubectl apply -f dashboard-external-https.yaml

$ kubectl get svc -n rook-ceph
NAME                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
rook-ceph-admission-controller           ClusterIP   10.96.235.227   <none>        443/TCP             20m
rook-ceph-mgr                            ClusterIP   10.96.157.80    <none>        9283/TCP            14m
rook-ceph-mgr-dashboard                  ClusterIP   10.96.135.96    <none>        7000/TCP            14m
rook-ceph-mgr-dashboard-external-https   NodePort    10.96.33.178    <none>        8443:31159/TCP      72s
rook-ceph-mon-a                          ClusterIP   10.96.182.138   <none>        6789/TCP,3300/TCP   18m
rook-ceph-mon-b                          ClusterIP   10.96.126.104   <none>        6789/TCP,3300/TCP   16m
rook-ceph-mon-c                          ClusterIP   10.96.1.101     <none>        6789/TCP,3300/TCP   15m


# 登录密码
$ kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 -d
$/#o(]2[8X`C]'P6g,?O
```

使用浏览器登陆：https://192.168.3.194:31159    admin/xxx

总览：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-dashboard-overall.png)

节点列表：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-dashboard-hosts.png)

OSD列表：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-dashboard-osds.png)



## 3.7 卸载操作

安装遇到问题时重装，或者需要卸载时使用

```bash
kubectl delete -f dashboard-external-https.yaml
kubectl delete -f toolbox.yaml
kubectl delete -f cluster.yaml
kubectl delete -f operator.yaml
kubectl delete -f crds.yaml
kubectl delete -f commons.yaml

rm -rf /var/lib/rook

# 非常重要，注意指定自己的磁盘名称，否则可能导致系统问题，比如这里为/dev/sdb
dd if=/dev/zero of=/dev/sdb bs=1M count=100 oflag=direct,dsync





#检查硬盘路径
fdisk -l
#删除硬盘分区信息
DISK="/dev/sdb"
sgdisk --zap-all $DISK
#清理硬盘数据（hdd硬盘使用dd，ssd硬盘使用blkdiscard，二选一）
dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync
blkdiscard $DISK
#删除原osd的lvm信息（如果单个节点有多个osd，那么就不能用*拼配模糊删除，而根据lsblk -f查询出明确的lv映射信息再具体删除，参照第5项操作）
ls /dev/mapper/ceph-* | xargs -I% -- dmsetup remove %
rm -rf /dev/ceph-*
#重启，sgdisk –zzap-all需要重启后才生效
reboot
```



# 4. Ceph 块存储(RBD)

## 4.1 创建 StorageClass

参考 csi/rbd/storageclass.yaml

```bash
$ cat csi/rbd/storageclass.yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 3
    requireSafeReplicaSize: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
    clusterID: rook-ceph # namespace:cluster
    pool: replicapool
    imageFormat: "2"
    imageFeatures: layering
    csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph # namespace:cluster
    csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph # namespace:cluster
    csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
    csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph # namespace:cluster
    csi.storage.k8s.io/fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

$ kubectl apply -f csi/rbd/storageclass.yaml

$ kubectl get sc
NAME              PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   7s
```



## 4.2 安装 MySQL

mysql的初始化过程较慢，从初始化到完全好大概耗费了10分钟，暂未分析原因

```bash
$ mkdir -p ~/ceph-test/rbd && cd $_

$ cat > mysql.yml <<EOF 
apiVersion: v1
kind: Service
metadata:
  name: mysql-svc
  labels:
    app: mysql
spec:
  type: NodePort
  selector:
    app: mysql
  ports:
    - port: 3306
      protocol: TCP
      targetPort: 3306
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
  labels:
    app: mysql
spec:
  storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
        - name: busybox
          image: busybox
          command: ["ls", "-al"]
      containers:
        - image: mysql:8.0.31
          args:
            - "--ignore-db-dir=lost+found"
          name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "123456"
          ports:
            - containerPort: 3306
              name: mysql
          
          volumeMounts:
            - name: mysql-persistent-storage
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-persistent-storage
          persistentVolumeClaim:
            claimName: mysql-pv-claim
EOF

$ kubectl apply -f mysql.yml

$ kubectl get pv
NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS  CLAIM                    STORAGECLASS      REASON   AGE
pvc-d9521c05-*  2Gi        RWO            Delete           Bound   default/mysql-pv-claim   rook-ceph-block            40m

$ kubectl get pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mysql-pv-claim   Bound    pvc-d9521c05-bd7d-42e8-803c-7368da5a9d6d   2Gi        RWO            rook-ceph-block   40m
```



# 5. CephFS

## 5.1 创建 fs

```bash
$ kubectl apply -f filesystem.yaml

$ kubectl apply -f csi/cephfs/storageclass.yaml

$ kubectl get sc
NAME              PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   4h28m
rook-cephfs       rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   44s
```



## 5.2 安装 Redis 集群

```bash
$ mkdir -p ~/ceph-test/cephfs && cd $_

$ cat > redis-cluster.yml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: redis-cluster
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cluster
  namespace: redis-cluster
data:
  change-pod-ip.sh: |
    #!/bin/sh
    CLUSTER_CONFIG="/data/nodes.conf"
    if [ -f \${CLUSTER_CONFIG} ]; then
      if [ -z "\${POD_IP}" ]; then
        echo "Unable to determine Pod IP address!"
        exit 1
      fi
      echo "change IP to \${POD_IP} in \${CLUSTER_CONFIG}"
      sed -i.bak -e '/myself/ s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/'\${POD_IP}'/' \${CLUSTER_CONFIG}
    fi
    exec "\$@"

  redis.conf: |
    bind 0.0.0.0
    protected-mode yes
    port 6379
    tcp-backlog 2048
    timeout 0
    tcp-keepalive 300
    daemonize no
    supervised no
    pidfile /var/run/redis.pid
    loglevel notice
    logfile /data/redis.log
    databases 16
    always-show-logo yes
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    masterauth hard2guess
    replica-serve-stale-data yes
    replica-read-only no
    repl-diskless-sync no
    repl-diskless-sync-delay 5
    repl-disable-tcp-nodelay no
    replica-priority 100
    requirepass hard2guess
    maxclients 32768
    maxmemory-policy allkeys-lru
    lazyfree-lazy-eviction no
    lazyfree-lazy-expire no
    lazyfree-lazy-server-del no
    replica-lazy-flush no
    appendonly yes
    appendfilename "appendonly.aof"
    appendfsync everysec
    no-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb
    aof-load-truncated yes
    aof-use-rdb-preamble yes
    lua-time-limit 5000
    cluster-enabled yes
    cluster-config-file /data/nodes.conf
    cluster-node-timeout 15000
    slowlog-log-slower-than 10000
    slowlog-max-len 128
    latency-monitor-threshold 0
    notify-keyspace-events ""
    hash-max-ziplist-entries 512
    hash-max-ziplist-value 64
    list-max-ziplist-size -2
    list-compress-depth 0
    set-max-intset-entries 512
    zset-max-ziplist-entries 128
    zset-max-ziplist-value 64
    hll-sparse-max-bytes 3000
    stream-node-max-bytes 4096
    stream-node-max-entries 100
    activerehashing yes
    client-output-buffer-limit normal 0 0 0
    client-output-buffer-limit replica 256mb 64mb 60
    client-output-buffer-limit pubsub 32mb 8mb 60
    hz 10
    dynamic-hz yes
    aof-rewrite-incremental-fsync yes
    rdb-save-incremental-fsync yes
    
---
apiVersion: v1
kind: Service
metadata:
  namespace: redis-cluster
  name: redis-cluster
spec:
  clusterIP: None
  ports:
  - name: client
    port: 6379
    targetPort: 6379
  - name: gossip  
    port: 16379
    targetPort: 16379
  selector:
    app: redis-cluster
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  namespace: redis-cluster
  name: redis-cluster
spec:
  serviceName: redis-cluster
  replicas: 12    # 至少6个节点
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
    spec:
      terminationGracePeriodSeconds: 20
      containers:
      - name: redis
        image: redis:5.0.14
        ports:
        - containerPort: 6379
          name: client
        - containerPort: 16379
          name: gossip
        command: ["/etc/redis/change-pod-ip.sh", "redis-server", "/etc/redis/redis.conf"]
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:
        - name: conf
          mountPath: /etc/redis/
          readOnly: false
        - name: data
          mountPath: /data
          readOnly: false
      volumes:
      - name: conf
        configMap:
          name: redis-cluster
          defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: "rook-cephfs"
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 100Mi
EOF

# 部署操作
$ kubectl apply -f redis-cluster.yml

$ kubectl get pod -n redis-cluster -o wide
NAME              READY   STATUS    RESTARTS   AGE   IP             NODE         NOMINATED NODE   READINESS GATES
redis-cluster-0   1/1     Running   0          24m   10.244.0.73    k8s-master   <none>           <none>
redis-cluster-1   1/1     Running   0          23m   10.244.2.101   k8s-node02   <none>           <none>
redis-cluster-2   1/1     Running   0          22m   10.244.1.74    k8s-node01   <none>           <none>

$ kubectl get pvc -n redis-cluster
NAME                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-redis-cluster-0    Bound    pvc-6bcbd769-721b-4699-8681-4d283ff7df12   100Mi      RWX            rook-cephfs    7m23s
data-redis-cluster-1    Bound    pvc-b7abfbca-a648-470a-beca-e6159b9b96f4   100Mi      RWX            rook-cephfs    6m37s
data-redis-cluster-10   Bound    pvc-74625f86-93fa-4068-b29c-399f4177c6e4   100Mi      RWX            rook-cephfs    69s
data-redis-cluster-11   Bound    pvc-62300de1-21b1-4936-aa5b-c4e8789aec61   100Mi      RWX            rook-cephfs    40s
data-redis-cluster-2    Bound    pvc-95e456df-0e45-4724-9d7b-332a415b185c   100Mi      RWX            rook-cephfs    6m3s
data-redis-cluster-3    Bound    pvc-b4be489e-2e0a-4f18-bc80-a8ad7198e533   100Mi      RWX            rook-cephfs    5m35s
data-redis-cluster-4    Bound    pvc-241832d6-2628-4091-89de-6e510800e1a1   100Mi      RWX            rook-cephfs    5m3s
data-redis-cluster-5    Bound    pvc-b4d0efb6-8308-4baf-9d73-f25690bb5578   100Mi      RWX            rook-cephfs    4m35s
data-redis-cluster-6    Bound    pvc-90fe1521-a98c-407b-8231-75912c01c65f   100Mi      RWX            rook-cephfs    3m13s
data-redis-cluster-7    Bound    pvc-210a6a30-91f5-4f35-a6a1-02c1ec3fee3d   100Mi      RWX            rook-cephfs    2m41s
data-redis-cluster-8    Bound    pvc-e72beba9-3eb0-457d-bcd7-8c40ad19d33f   100Mi      RWX            rook-cephfs    2m10s
data-redis-cluster-9    Bound    pvc-61628860-12d3-4b55-9dd4-46d1003b5fd6   100Mi      RWX            rook-cephfs    100s

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                 STORAGECLASS      REASON   AGE
pvc-210a6a30-91f5-4f35-a6a1-02c1ec3fee3d   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-7    rook-cephfs                2m14s
pvc-241832d6-2628-4091-89de-6e510800e1a1   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-4    rook-cephfs                4m36s
pvc-481ef2d7-ffb4-4a8c-9de4-5476af8e22e6   100Mi      RWO            Delete           Bound    default/rbd-pvc                       rook-ceph-block            5h14m
pvc-61628860-12d3-4b55-9dd4-46d1003b5fd6   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-9    rook-cephfs                73s
pvc-62300de1-21b1-4936-aa5b-c4e8789aec61   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-11   rook-cephfs                13s
pvc-6bcbd769-721b-4699-8681-4d283ff7df12   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-0    rook-cephfs                6m56s
pvc-74625f86-93fa-4068-b29c-399f4177c6e4   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-10   rook-cephfs                42s
pvc-90fe1521-a98c-407b-8231-75912c01c65f   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-6    rook-cephfs                2m46s
pvc-95e456df-0e45-4724-9d7b-332a415b185c   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-2    rook-cephfs                5m36s
pvc-b4be489e-2e0a-4f18-bc80-a8ad7198e533   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-3    rook-cephfs                5m8s
pvc-b4d0efb6-8308-4baf-9d73-f25690bb5578   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-5    rook-cephfs                4m8s
pvc-b7abfbca-a648-470a-beca-e6159b9b96f4   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-1    rook-cephfs                6m11s
pvc-e72beba9-3eb0-457d-bcd7-8c40ad19d33f   100Mi      RWX            Delete           Bound    redis-cluster/data-redis-cluster-8    rook-cephfs                103s
```



**Redis 集群创建**：

集群创建，只能使用IP方式(7.x版本才支持使用域名)，潜在问题：pod跨节点漂移，IP段不一致，所以尽量在每个节点上只调度一个(通过Pod反亲和性实现，但前提是工作节点至少6个)

```bash
$ kubectl exec -it redis-cluster-0 -n redis-cluster -- bash
root@redis-cluster-0:/data# redis-cli -a hard2guess --cluster create \
10.244.0.74:6379 \
10.244.0.75:6379 \
10.244.0.84:6379 \
10.244.0.85:6379 \
10.244.0.76:6379 \
10.244.0.77:6379 \
10.244.0.78:6379 \
10.244.0.79:6379 \
10.244.0.80:6379 \
10.244.0.81:6379 \
10.244.0.82:6379 \
10.244.0.83:6379 \
--cluster-replicas 1

...
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.


root@redis-cluster-0:/data# redis-cli -c -h redis-cluster-2.redis-cluster.redis-cluster.svc.cluster.local -a 'hard2guess'
redis-cluster-2.redis-cluster.redis-cluster.svc.cluster.local:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:12
cluster_size:6
cluster_current_epoch:12
cluster_my_epoch:11
cluster_stats_messages_ping_sent:192
cluster_stats_messages_pong_sent:172
cluster_stats_messages_meet_sent:1
cluster_stats_messages_update_sent:2
cluster_stats_messages_sent:367
cluster_stats_messages_ping_received:172
cluster_stats_messages_pong_received:193
cluster_stats_messages_update_received:5
cluster_stats_messages_received:370

redis-cluster-2.redis-cluster.redis-cluster.svc.cluster.local:6379> cluster nodes
bfbe1e65b6c43b38d1094a76d11eb32536de50e9 10.244.0.79:6379@16379 master - 0 1666167426000 6 connected 13653-16383
ecf467e4045ddbe64aa46bbec5a0a5a2d0900236 10.244.0.75:6379@16379 master - 0 1666167423000 2 connected 2731-5460
cdaa721179bda420d635c240bd67d31c0c5dc88a 10.244.0.85:6379@16379 master - 0 1666167422094 12 connected 8192-10922
6b1815585263cef228665e8312bba283589ad506 10.244.0.80:6379@16379 slave ecf467e4045ddbe64aa46bbec5a0a5a2d0900236 0 1666167426214 7 connected
cfe4f2d06bf86611565e164b3250f0ea62133d12 10.244.0.84:6379@16379 master - 0 1666167427217 11 connected 5461-8191
02eefc1717292228c84adb66ac446c9f4c2e2be5 10.244.0.81:6379@16379 slave cfe4f2d06bf86611565e164b3250f0ea62133d12 0 1666167424000 11 connected
a11609994c8b29d4aa6c766653d461dd563c3aaf 10.244.0.82:6379@16379 slave cdaa721179bda420d635c240bd67d31c0c5dc88a 0 1666167423000 12 connected
27926234c07f55b669daa350f1c91969537730d2 10.244.0.74:6379@16379 master - 0 1666167426000 1 connected 0-2730
818bb1ff413ad7b80a6a4ec6df2b157c3a223509 10.244.0.76:6379@16379 myself,slave cfe4f2d06bf86611565e164b3250f0ea62133d12 0 1666167421000 3 connected
cbde8f3b2efb012af801ef01f4f73095572c8540 10.244.0.78:6379@16379 master - 0 1666167423201 5 connected 10923-13652
a1b17b4db6d5d6da7462829c0ebfe1ea94db35fd 10.244.0.83:6379@16379 master - 0 1666167425211 10 connected
310dea619a5b60bde7b0af92e6f63366910ccfce 10.244.0.77:6379@16379 slave cdaa721179bda420d635c240bd67d31c0c5dc88a 0 1666167424206 12 connected
```

