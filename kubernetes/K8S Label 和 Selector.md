# 1.Label 

标签(labels)：附加到 k8s 对象上的键值对。用于指定对用户有意义且相关的对象的标识属性。

示例标签：

- `"release" : "stable"`, `"release" : "canary"`
- `"environment" : "dev"`, `"environment" : "qa"`, `"environment" : "production"`
- `"tier" : "frontend"`, `"tier" : "backend"`, `"tier" : "cache"`
- `"partition" : "customerA"`, `"partition" : "customerB"`
- `"track" : "daily"`, `"track" : "weekly"`

推荐使用的标签：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/name: mysql
    app.kubernetes.io/instance: mysql-abcxzy
    app.kubernetes.io/version: "5.7.21"
    app.kubernetes.io/managed-by: helm
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: wordpress
...
```



# 2. 语法

Label Key:

- 不超过63个字符
- 支持使用前缀，前缀必须是DNS子域，不超过253个字符。系统化组件创建的label必须指定前缀。`kubernetes.io` 和 `k8s.io` 由 kubernetes 保留
- 格式：`[A-Za-z0-9][A-Za-z0-9_\-\.]`

Label Value:

- 不超过63个字符
- 格式：`[A-Za-z0-9][A-Za-z0-9_\-\.]`



# 3. Label selector

Label 不是唯一的，很多对象可能有相同的label

通过 label selector，可指定一个object集合，通过 label selector 对 object 集合进行操作

两种类型：

- `equality-based`: 使用`=`, `==`, `!=` 操作符，可使用逗号分隔多个表达式： `environment=production,tier!=frontend`

- `set-based`：使用`in`, `notin`, `!`操作符。`!` 表示没有该 label 的 object

```bash
$ kubectl get pods -l environment=production,tier=frontend
$ kubectl get pods -l 'environment in (production),tier in (frontend)'
$ kubectl get pods -l 'environment in (production, qa)'
$ kubectl get pods -l 'environment,environment notin (frontend)'
```



# 4. API

- Service

  `spec.selector = map[string]string`

  ```yaml
  selector:
    component: redis
  ```

- Deployment, StatefulSet, DaemonSet, ReplicaSet, Job

  `sepc.selector.matchLabels = map[string]string`

  `sepc.selector.matchExpressions`:

  - `key: string`
  - `operator: In, NotIn, Exists or DoesNotExist`
  - `values: []string`

  ```yaml
  selector:
    matchLabels:
      component: redis
    matchExpressions:
      - {key: tier, operator: In, values: [cache]}
      - {key: environment, operator: NotIn, values: [dev]}
  ```

- node affinity 和 pod affinity 中的 selector

  `spec.template.spec.affinity.nodeAffinity`:
  
  - `requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms`
  - `preferredDuringSchedulingIgnoredDuringExecution.preference`
    - `matchExpressions`: by node labels
      - `key: string`
      - `operator: In, NotIn, Exists, DoesNotExist, Gt or Lt`
      - `values: []string`
    - `matchFields`: by node fields
      - `key: string`
      - `operator: In, NotIn, Exists, DoesNotExist, Gt or Lt`
      - `values: []string`
  
  `spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution`
  
  `spec.template.spec.affinity.podAffinity.preferredDuringSchedulingIgnoredDuringExecution.podAffinityTerm`
  
  `spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution`
  
  `spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution.podAffinityTerm`
  
  - `labelSelector`:
    - `matchExpressions`:
      - `key: string`
      - `operator: In, NotIn, Exists or DoesNotExist`
      - `values: []string`
    - `matchLabels`: `map[string]string`  
  - `namespaceSelector`:
    - `matchExpressions`:
      - `key: string`
      - `operator: In, NotIn, Exists or DoesNotExist`
      - `values: []string`
    - `matchLabels`: `map[string]string`  
  
  ```yaml
  affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
              - k8s-node01
              - k8s-node02
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          preference:
            matchExpressions:
            - key: another-node-label-key
              operator: In
              values:
              - another-node-label-value
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - kafka-container
            topologyKey: kubernetes.io/hostname
          weight: 100
  ```
  
  