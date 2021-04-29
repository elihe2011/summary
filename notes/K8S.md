k8s 对象：

| 类别     | 名称                                                         |
| :------- | ------------------------------------------------------------ |
| 资源对象 | Pod、ReplicaSet、ReplicationController、Deployment、StatefulSet、DaemonSet、Job、CronJob、HorizontalPodAutoscaler |
| 配置对象 | Node、Namespace、Service、Secret、ConfigMap、Ingress、Label、CustomResourceDefinition、 ServiceAccount |
| 存储对象 | Volume、Persistent Volume                                    |
| 策略对象 | SecurityContext、ResourceQuota、LimitRange                   |



资源限制与配额：

- Pod 级别：最小的资源调度单位
- Namespace 级别：限制资源配额和每个 Pod 的资源使用区间



