# 1. NFS 存储

暂时使用 NFS 作为后台数据存储，可调整为其他，在 helm 安装时，指定存储的 storageclass 即可

## 1.1 安装 NFS 服务

### 1.1.1 服务端

#### 1.1.1.1 服务目录

- 独立磁盘

  ```bash
  # 1. 分区
  fdisk /dev/sdb       
  
  # 2. 格式化
  mke2fs -t ext4 /dev/sdb1
  
  # 3. 挂载
  mkdir -p /srv/nfsv4
  mount /dev/sdb1 /srv/nfsv4
  
  # 4. 查询磁盘UUID
  $ blkid  /dev/sdb1
  /dev/sdb1: UUID="17b60a9a-92a2-4084-aaea-9f1e73d72509" TYPE="ext4" PARTUUID="42cf54d8-01"
  
  # 5. 配置开机自动挂载
  $ vi /etc/fstab
  UUID=17b60a9a-92a2-4084-aaea-9f1e73d72509 /srv/nfsv4 ext4 defaults 0 2
  ```

- 共享目录

  ```bash
  # 1. 创建目录
  mkdir -p /data/share
  mkdir -p /srv/nfsv4
  
  # 2. 绑定挂载
  mount --bind /data/share /srv/nfsv4
  
  # 3. 配置开机自动挂载
  $ vi /etc/fstab
  /data/share /srv/nfsv4     none   bind   0   0
  ```



#### 1.1.1.2 安装 NFS Server

```bash
# 1. Install NFS Kernel Server
apt update
apt install nfs-kernel-server

# 2. Create a NFS Export Directory
chown -R nobody:nogroup /srv/nfsv4
chmod 777 /srv/nfsv4

# 3. Grant NFS Share Access to Client，指定no_root_squash，否则无法更改文件属主和属组
vim /etc/exports
/srv/nfsv4 192.168.3.0/24(rw,sync,no_subtree_check,no_root_squash)

# 4. Export the NFS Share Directory
exportfs -a
systemctl restart nfs-kernel-server

# 5. Allow NFS Access through the Firewall
ufw status
ufw allow from 192.168.0.0/16 to any port nfs

# 6. 导出详情
exportfs -v
/srv/nfsv4      192.168.3.0/24(rw,wdelay,no_root_squash,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)

# 7. 列出被mount的目录及客户端主机或IP
showmount -a
```

NFS 共享的常用参数：

| 参数               | 说明                                                         |
| ------------------ | ------------------------------------------------------------ |
| ro                 | 只读访问                                                     |
| rw                 | 读写访问                                                     |
| sync               | 同时将数据写入到内存与硬盘中                                 |
| async              | 异步，优先将数据保存到内存，然后再写入硬盘                   |
| secure             | 通过1024以下的安全TCP/IP端口发送                             |
| insecure           | 通过1024以上的端口发送                                       |
| wdelay             | 如果多个用户要写入NFS目录，则归组写入（默认）                |
| no_wdelay          | 如果多个用户要写入NFS目录，则立即写入，当使用async时，无需此设置 |
| hide               | 在NFS共享目录中不共享其子目录                                |
| no_hide            | 共享NFS目录的子目录                                          |
| subtree_check      | 如果共享/usr/bin之类的子目录时，强制NFS检查父目录的权限（默认） |
| no_subtree_check   | 不检查父目录权限                                             |
| all_squash         | 全部用户都映射为服务器端的匿名用户，适合公用目录             |
| no_all_squash      | 保留共享文件的UID和GID（默认）                               |
| root_squash        | 当NFS客户端使用root用户访问时，映射到NFS服务器的匿名用户（默认） |
| **no_root_squash** | 当NFS客户端使用root用户访问时，映射到NFS服务器的root用户     |
| anonuid=UID        | 将客户端登录用户映射为此处指定的用户uid                      |
| anongid=GID        | 将客户端登录用户映射为此处指定的用户gid                      |



### 1.1.2 客户端

```bash
# 1. Install the NFS-Common Package
sudo apt update
sudo apt install nfs-common

# 2. Create an NFS Mount Point on Client
sudo mkdir -p /data/share

# 3. Mount NFS Share on Client System
sudo mount 192.168.3.194:/srv/nfsv4  /data/share
sudo nfsstat -m

# 4. Testing the NFS Share on Client System
touch /srv/nfsv4/abc.txt  # server
ls -l /data/share         # client
```



### 1.1.3 无法启动

```bash
$ systemctl start nfs-kernel-server
A dependency job for nfs-server.service failed. See 'journalctl -xe' for details.

$ journalctl -xe
Oct 29 19:38:04 k8s-master multipathd[720]: sda: add missing path
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get udev uid: Invalid argument
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get sysfs uid: Invalid argument
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get sgio uid: No such file or directory
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: add missing path
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get udev uid: Invalid argument
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get sysfs uid: Invalid argument
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get sgio uid: No such file or directory

# 解决
$ vi /etc/multipath.conf
defaults {
    user_friendly_names yes
}

blacklist {
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
    devnode "^sd[a-z]?[0-9]*"
}

$ systemctl restart multipath-tools

# 启动 nfs
systemctl start nfs-kernel-server
```



## 1.2 动态存储分配

### 1.2.1 创建 RBAC

```bash
mkdir ~/install/sc_nfs && cd $_

cat > nfs-rbac.yml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f nfs-rbac.yml
```



### 1.2.2 部署 NFS Provisioner

```bash
cat > nfs-provisioner-deploy.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      nodeName: k8s-master  # 直接调度到主控节点 
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 192.168.3.194
            - name: NFS_PATH
              value: /srv/nfsv4
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.3.194
            path: /srv/nfsv4
EOF

kubectl apply -f  nfs-provisioner-deploy.yml
```



### 1.2.3 创建 StorageClass

```yaml
cat > nfs-storageclass.yml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
  namespace: default
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
  mountOptions:
  - nfsvers=3
EOF

kubectl apply -f nfs-storageclass.yml
```



# 2. 安装 EdgeX Foundry

## 2.1 安装前提

- Kubernetes 集群 v1.22.17+

- KubeEdge v1.12.1

- EdgeMesh v1.12.0

- Helm v3.10.3+

- Edgex 选择(Jakarta, v2.1.1)

  ```bash
  'Barcelona': October 2017
  'California': July 2018
  'Delhi': November 2018
  'Edinburgh':  July 2019
  'Fuji': November 2019
  'Geneva': ~ April 2020
  'Hanoi': ~ October 2020
  'Ireland': ~ April 2021
  'Jakarta': ~ October 2021
  'Kamakura': ~ April 2022
  ```

  

## 2.2 端口规划

| Service                     | Partial URL              | Internal Port | External Port |
| :-------------------------- | ------------------------ | ------------- | ------------- |
| edgex-redis                 | -                        | 6379          | 30379         |
| edgex-core-consul           | -                        | 8500          | 30500         |
| edgex-core-data             | core-data                | 59880         | -             |
| edgex-core-metadata         | core-metadata            | 59881         | -             |
| edgex-core-command          | core-command             | 59882         | -             |
| edgex-support-rulesengine   | rules-engine             | 59720         | -             |
| edgex-support-notifications | support-notifications    | 59860         | -             |
| edgex-support-scheduler     | support-scheduler        | 59861         | -             |
| edgex-appservice-rules      | app-service-configurable | 59701         | -             |
| edgex-device-rest           | device-rest              | 59986         | -             |
| edgex-device-virtual        | device-virtual           | 59900         | -             |
| edgex-sys-mgmt-agent        | sys-mgmt-agent           | 58890         | -             |
| edgex-ui-go                 | -                        | 4000          | 30400         |



## 2.3 安装操作

当前以 Jakarta 作为基准版本

```bash
# 不安装，语法检查等
helm install test --debug  --dry-run edgex-helm-no-secty

# 安装操作
helm install edgex-jakarta edgex-helm-no-secty
```



安装后，等待一段时间检查

```bash
$ kubectl get all
NAME                                               READY   STATUS    RESTARTS        AGE
pod/edgex-app-rules-engine-79c69dcb89-drz88        1/1     Running   1 (7m42s ago)   9m7s
pod/edgex-core-command-cdb57cc58-gc2hg             1/1     Running   1 (7m54s ago)   9m7s
pod/edgex-core-consul-5c9d64c857-nmwhd             1/1     Running   0               9m8s
pod/edgex-core-data-576bdb4fd8-wd4m9               1/1     Running   1 (7m45s ago)   9m7s
pod/edgex-core-metadata-6dc6ff9f87-9bqr4           1/1     Running   2               9m8s
pod/edgex-device-rest-57d7bdf479-rtk7g             1/1     Running   0               9m8s
pod/edgex-device-virtual-6bc95c4bc5-6hhdh          1/1     Running   1               9m11s
pod/edgex-redis-6559759c77-b2lt5                   1/1     Running   0               9m12s
pod/edgex-support-notifications-574db5fff6-mlzqr   1/1     Running   2               9m12s
pod/edgex-support-rulesengine-6d7bb9c455-cwt24     1/1     Running   0               9m11s
pod/edgex-support-scheduler-6b8c696f7f-gxkm8       1/1     Running   2 (7m45s ago)   9m12s
pod/edgex-sys-mgmt-agent-f7fd659bb-tpsrf           1/1     Running   2 (7m50s ago)   9m10s
pod/edgex-ui-go-74d99d97f9-r6cpv                   1/1     Running   0               9m8s
pod/nfs-client-provisioner-847457d76f-9c547        1/1     Running   5 (11h ago)     33h

NAME                                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)              AGE
service/edgex-app-rules-engine        ClusterIP   10.96.29.117   <none>        59701/TCP            9m14s
service/edgex-core-command            ClusterIP   10.96.2.233    <none>        59882/TCP            9m14s
service/edgex-core-consul             NodePort    10.96.176.60   <none>        8500:30850/TCP       9m15s
service/edgex-core-data               ClusterIP   10.96.202.47   <none>        5563/TCP,59880/TCP   9m14s
service/edgex-core-metadata           ClusterIP   10.96.16.238   <none>        59881/TCP            9m12s
service/edgex-device-rest             ClusterIP   10.96.221.49   <none>        59986/TCP            9m13s
service/edgex-device-virtual          ClusterIP   10.96.126.93   <none>        59900/TCP            9m14s
service/edgex-kuiper                  ClusterIP   10.96.75.32    <none>        59720/TCP            9m12s
service/edgex-redis                   NodePort    10.96.209.98   <none>        6379:30379/TCP       9m12s
service/edgex-support-notifications   ClusterIP   10.96.53.23    <none>        59860/TCP            9m15s
service/edgex-support-scheduler       ClusterIP   10.96.237.93   <none>        59861/TCP            9m13s
service/edgex-sys-mgmt-agent          ClusterIP   10.96.74.112   <none>        58890/TCP            9m13s
service/edgex-ui-go                   ClusterIP   10.96.171.56   <none>        4000/TCP             9m15s
service/edgex-ui-go-nodeport          NodePort    10.96.191.14   <none>        4000:30400/TCP       9m15s
service/kubernetes                    ClusterIP   10.96.0.1      <none>        443/TCP              8d

NAME                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/edgex-app-rules-engine        1/1     1            1           9m12s
deployment.apps/edgex-core-command            1/1     1            1           9m12s
deployment.apps/edgex-core-consul             1/1     1            1           9m12s
deployment.apps/edgex-core-data               1/1     1            1           9m12s
deployment.apps/edgex-core-metadata           1/1     1            1           9m12s
deployment.apps/edgex-device-rest             1/1     1            1           9m12s
deployment.apps/edgex-device-virtual          1/1     1            1           9m12s
deployment.apps/edgex-redis                   1/1     1            1           9m12s
deployment.apps/edgex-support-notifications   1/1     1            1           9m12s
deployment.apps/edgex-support-rulesengine     1/1     1            1           9m12s
deployment.apps/edgex-support-scheduler       1/1     1            1           9m12s
deployment.apps/edgex-sys-mgmt-agent          1/1     1            1           9m12s
deployment.apps/edgex-ui-go                   1/1     1            1           9m12s
deployment.apps/nfs-client-provisioner        1/1     1            1           33h

NAME                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/edgex-app-rules-engine-79c69dcb89        1         1         1       9m8s
replicaset.apps/edgex-core-command-cdb57cc58             1         1         1       9m8s
replicaset.apps/edgex-core-consul-5c9d64c857             1         1         1       9m11s
replicaset.apps/edgex-core-data-576bdb4fd8               1         1         1       9m8s
replicaset.apps/edgex-core-metadata-6dc6ff9f87           1         1         1       9m11s
replicaset.apps/edgex-device-rest-57d7bdf479             1         1         1       9m11s
replicaset.apps/edgex-device-virtual-6bc95c4bc5          1         1         1       9m12s
replicaset.apps/edgex-redis-6559759c77                   1         1         1       9m12s
replicaset.apps/edgex-support-notifications-574db5fff6   1         1         1       9m12s
replicaset.apps/edgex-support-rulesengine-6d7bb9c455     1         1         1       9m12s
replicaset.apps/edgex-support-scheduler-6b8c696f7f       1         1         1       9m12s
replicaset.apps/edgex-sys-mgmt-agent-f7fd659bb           1         1         1       9m11s
replicaset.apps/edgex-ui-go-74d99d97f9                   1         1         1       9m11s
replicaset.apps/nfs-client-provisioner-847457d76f        1         1         1       33h
```



## 2.4 登录平台

当前默认使用 NodePort 来暴露端口，参看端口规划：

- consul:  http://192.168.3.194:30500   （正式环境不会开放）
- ui-go: http://192.168.3.194:30400/zh/#/dashboard   (EdgeX 控制台，常用)



## 2.5 卸载操作

```bash
helm uninstall edgex-jakarta
```



## 2.6 自定义安装参数

安装时，如果不想使用默认值，可以自己写配置文件覆盖默认参数：

```bash
# 1. 创建自己的配置参数，覆盖默认的存储配置
cat > myvalues.yaml <<EOF
storage:
  core:
    consul:
      class: ceph-storage
      configSize: 50Mi
      dataSize: 200Mi
  support:
    rulesengine:
      class: ceph-storage
      size: 500Mi
  redis:
    class: ceph-storage
    size: 1Gi
EOF

# 2. 执行安装
helm install -f myvalues.yaml edgex-jakarta edgex-helm-no-secty
```



# 3. 问题汇总

## 3.1 安全认证

当前的 helm 包参照 https://github.com/edgexfoundry/edgex-compose/blob/main/docker-compose-no-secty-arm64.yml 改写而成，暂未集成安全认证相关内容



## 3.2 登录 edgex-ui 提示认证

非安全认证版本，不需要提供 token 认证。这里是它的 compose 文件 bug，修改 docker-compose-no-secty-arm64.yml 文件：

```yaml
  ui:
    container_name: edgex-ui-go
    environment:  # 新增环境变量配置
      EDGEX_SECURITY_SECRET_STORE: "false"
      SERVICE_HOST: edgex-ui-go
    hostname: edgex-ui-go
    image: edgexfoundry/edgex-ui-arm64:2.1.0
    networks:
      edgex-network: {}
    ports:
    - 4000:4000/tcp
    read_only: true
    restart: always
    security_opt:
    - no-new-privileges:true
    user: 2002:2001
```





