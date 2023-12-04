# 安装 EdgeX Foundry

## 安装前提

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

  

## 安装操作

当前以 Jakarta 作为基准版本

```bash
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



## 登录平台

当前默认使用 NodePort 来暴露端口，参看端口规划：

- consul:  http://192.168.3.194:30500   （正式环境不会开放）
- ui-go: http://192.168.3.194:30400/zh/#/dashboard   (EdgeX 控制台，常用)



## 卸载操作

```bash
helm uninstall edgex-jakarta
```



## 自定义安装参数

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



