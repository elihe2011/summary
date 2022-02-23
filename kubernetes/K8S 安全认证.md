# 1. ServiceAccount

## 1.1 简介

Kubernetes 种账户分为：

- **UserAccount**: 给集群外用户访问 API Server，执行 kubectl 命令时用的就是该账号。它是全局性的，跨 namespace,  通常为admin，也可以自定义

  ```bash
  $ cat /root/.kube/config
  users:
  - name: cluster-admin
    user:
  ```

- **ServiceAccount**: Pod 容器访问 API Server 的身份认证。SA 与 namespace 绑定，每个namespace 都会自动创建一个 default service account。创建 Pod 时，如果未指定 SA， 则默认使用 default service account. (`spec.serviceAccount` )



## 1.2 Secret 和 ServiceAccount

Secret 资源，分为两类：

- ServiceAccount: `kubernetes.io/service-account-token`
- Opaque: 用户自定义的保密信息

SA 中包含三个部分：

- token：使用API Server私钥签名的 JWT
- ca.crt: 根证书，用于Client端验证API Server发送的证书
- namespace: 标识该service-account-token的作用域名空间



## 1.3 默认 ServiceAccount

在创建 namespace 时，会自动创建一个默认的 SA，而 SA 创建时，也会创建对应的 Secret

```bash
$ kubectl create ns my-ns

$ kubectl get sa -n my-ns
NAME      SECRETS   AGE
default   1         44s

$ kubectl get secret -n my-ns
NAME                  TYPE                                  DATA   AGE
default-token-sdjnx   kubernetes.io/service-account-token   3      66s
```

Pod 中的 SA 配置：

```bash
$ cat > default-sa.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-sa
  namespace: my-ns
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF

$ kubectl apply -f default-sa.yml

$ kubectl describe pod default-sa -n my-ns
...
Containers:
  nginx:
    ...
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-ngxjs (ro)
...
Volumes:
  kube-api-access-ngxjs:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
```

Pod Container 内部：

```bash
$ kubectl exec -it default-sa -n my-ns -- ls /run/secrets/kubernetes.io/serviceaccount
ca.crt  namespace  token

# ca.crt: 根证书，与 /etc/kubernetes/pki/ca.pem 一致
# namespace: Pod 所属 namespace
# token: 由 API Server 私钥签发的 JWT，Pod访问API Server的凭证 
```



## 1.4 自定义 ServiceAccount

```bash
$ kubectl create sa my-sa -n my-ns

$ kubectl get sa -n myns
NAME      SECRETS   AGE
default   1         5m53s
my-sa     1         13s

$ kubectl get secret -n my-ns
NAME                  TYPE                                  DATA   AGE
default-token-sdjnx   kubernetes.io/service-account-token   3      6m15s
my-sa-token-ndvsk     kubernetes.io/service-account-token   3      35s
```



Pod 中SA 配置：

```bash
$ cat >self-define-sa.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: self-define-sa
  namespace: my-ns
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
  serviceAccountName: my-sa   # 指定 SA
EOF
```



## 1.5 免登录获取镜像

```bash
$ kubectl create secret docker-registry registry-key --docker-server=hub.exped.io --docker-username=root --docker-password=123456 --docker-email=admin@exped.io -n my-ns

$ kubectl get secret -n my-ns
NAME                  TYPE                                  DATA   AGE
default-token-sdjnx   kubernetes.io/service-account-token   3      10m
my-sa-token-ndvsk     kubernetes.io/service-account-token   3      4m59s
registry-key          kubernetes.io/dockerconfigjson        1      13s

# 修改 my-sa, 添加 imagePullSecrets
$ kubectl patch sa my-sa -n my-ns --patch '{"imagePullSecrets": [{"name": "registry-key"}]}'

$ kubectl get sa my-sa -n my-ns -o yaml
apiVersion: v1
imagePullSecrets:
- name: registry-key
kind: ServiceAccount
metadata:
  creationTimestamp: "2021-12-27T02:34:20Z"
  name: my-sa
  namespace: my-ns
  resourceVersion: "904575"
  selfLink: /api/v1/namespaces/my-ns/serviceaccounts/my-sa
  uid: 9e1799e2-9c93-431c-86fa-e258f4352908
secrets:
- name: my-sa-token-ndvsk
```



# 2. RBAC

## 2.1 简介

![auth](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-rbac.png)

ServiceAccount 是 APIServer 的认证过程，而授权机制通过 RBAC：基于角色的访问控制实现(Role-based access control )

**允许 CRUD (Create, Read, Update, Delete) 的操作的资源**：

- pods
- configmaps
- deployments
- nodes
- secrets
- namespaces
- services



**操作动作**：

- create
- get
- delete
- list
- update
- edit
- watch
- exec



## 2.2 Role & ClusterRole

Role 表示一组规则权限，权限只会增加(累加权限)，不存在资源开始就有很多权限而通过 RBAC 对其减少的操作。Role 定义在一个 namespace 中，而 ClusterRole 是集群级别的

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-1
  namespace: my-ns
rules:
- apiGroups: [""]   #为空表示为默认的core api group
  resources: ["pods"] 
  verbs: ["get","watch","list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get","list","create","update","patch","delete","watch"]
```



ClusterRole 具有和 Role 相同的权限角色控制能力，且是集群级别的，它可以用于：

- 集群级别资源控制，如 node 访问控制
- 非资源型 endpoints，如对某个目录和文件的访问：/healthz
- 所有命名空间资源控制 (Pod、Deployment等)

```bash
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: clusterrole-1
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get","create","list"]
```



k8s 系统默认的 ClusterRole: **cluster-admin**, 具有所有资源的管理权限

```bash
$ kubectl get clusterrole cluster-admin -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2021-11-22T05:12:41Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
  resourceVersion: "94"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterroles/cluster-admin
  uid: a0d42c32-b3d8-476b-a186-06eb3e7df47b
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
```



## 2.3 RoleBinding & ClusterRoleBinding

RoleBinding: 可以将角色中定义的权限授予用户或用户组。它包含一组权限列表 (Subjects)， 权限列表中包含不同形式的待授予权限的资源类型 (users, groups, ServiceAccount)。另外，它同样包含对 Role或ClusterRole的引用。RoleBinding 适用于某个命名空间内的授权.

```yaml
# 绑定 Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rolebinding-1
  namespace: my-ns
subjects:
- kind: User    # 权限资源类型
  name: eli     # 名称
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role    # Role
  name: role-1
  apiGroup: rbac.authorization.k8s.io
  
# 绑定 ClusterRole，将集群资源权限赋予用户eli
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rolebinding-2
  namespace: my-ns
subjects:
- kind: User
  name: eli
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: clusterrole-1
  apiGroup: rbac.authorization.k8s.io
```



ClusterRoleBinding: 用于集群范围内的授权

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: clusterrolebinding-1
subjects:
- kind: Group
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: clusterrole-1
  apiGroup: rbac.authorization.k8s.io
```



# 3. 安全机制

## 3.1 认证 (Authentication)

### 3.1.1 认证方式

- HTTP Token：`Authorization: Bearer $TOKEN`
- HTTP Basic： `Authorization: Basic $(base64encode USERNAME:PASSWORD)`,

- HTTPS: 基于CA根证书签名的客户端身份认证方式（推荐）

![https](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/https-auth.png)

**证书颁发：**

- 手动签发：通过k8s集群的根 ca 进行签发 HTTPS 证书
- 自动签发：kubelet 首次访问 API Server 时，使用 token 认证，通过后，Controller Manager 会为kubelet生成一个证书，以后的访问均使用该证书



### 3.1.2 认证方案

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-authentication.png)

- **kubeconfig**

  kubeconfig 文件包含集群参数（CA证书、API Server地址），客户端参数，集群context信息（集群名称、用户名）。k8s 组件通过启动时指定不同的 kubeconfig 文件可以切换到不同的集群`cat ~/.kube/config`

- ServiceAccount

  Pod 中的容器访问API Server。因为Pod的创建和销毁是动态的，所以要为它手动生成证书是不可行的，k8s 使用 Service Account解决Pod访问API Server的认证问题



## 3.2 鉴权 (Authorization)

### 3.2.1 API Server的授权策略

启动参数`--authorization-mode`

- AlwaysDeny: 拒绝所有请求，一般用于测试
- AlwaysAllow: 接收所有请求。如果集群不需要授权流程，采用该策略
- ABAC (Attribute-Based Access Control): 基于属性的访问控制，表示使用用户配置的授权规则对用户请求进行匹配和控制
- Webbook: 通过调用外部REST服务对用户进行授权
- RBAC (Role-Based Access Control): **基于角色的访问控制**，默认规则



### 3.2.2 RBAC 的优势

- 对集群中的资源和非资源均拥有完整的覆盖
- 整个RBAC完全由几个API对象完成，同其他API对象一样，可以用kubectl或API进行操作
- 可在运行时调整，无需重启API Server



## 3.3 准入控制

准入控制是 API Server 的插件集合，通过添加不同的插件，实现额外的准入控制规则

常见准入控制插件：

- NamespaceLifecycle: 防止在不存在的namespace上创建对象；防止删除系统预置的namespace；删除namespace时，连带删除它下面的所有资源
- LimitRanger: 确保请求的资源不会超过资源所在Namespace的LimitRange的限制
- ServiceAccount: 实现自动化添加SA
- ResourceQuota: 确保请求的资源不会超过资源的ResourceQuota限制



## 3.4 总结

API Server 是集群内部各个组件通讯的中介，也是外部控制的入口。k8s 使用认证(Authentication)、鉴权(Authorization)、准入控制(Admission Control) 三步来确保API Server的安全。

认证 和鉴权：

- 认证(authencation): 通过只代表通讯双方是可信的
- 鉴权(authorization): 确定请求方有哪些资源权限



# 4. 实例：普通用户管理集群

## 4.1 创建用户

```bash
# 创建 namespace
kubectl create ns eli

# 创建用户
useradd -s /bin/bash -d /home/eli -m eli
su - eli

$ kubectl get pod
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```



## 4.2 创建证书

```bash
mkdir -p /root/certs && cd $_

cat > eli-csr.json <<EOF
{
  "CN": "eli",    
  "hosts": [],  
  "key": {
    "algo": "rsa", 
    "size": 2048
},
  "names": [
    {
       "C": "CN",
       "L": "Nanjing",
       "O": "k8s",
       "ST": "Jiangsu",            
       "OU": "System"
    }
  ]
}
EOF

cd /etc/kubernetes/pki

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -profile=kubernetes /root/certs/eli-csr.json | cfssljson -bare eli
```



## 4.3 生成集群配置

```bash
cd /root/certs

export KUBE_APISERVER="https://192.168.80.240:6443"

# 创建 kubeconfig
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true --server=${KUBE_APISERVER} \
--kubeconfig=eli.kubeconfig

# 设置客户端参数，绑定用户到 kubeconfig
kubectl config set-credentials eli \
--client-certificate=/etc/kubernetes/pki/eli.pem \
--client-key=/etc/kubernetes/pki/eli-key.pem \
--embed-certs=true \
--kubeconfig=eli.kubeconfig

# 设置上下文
kubectl config set-context kubernetes \
--cluster=kubernetes \
--user=eli \
--namespace=eli \
--kubeconfig=eli.kubeconfig
```



## 4.4 创建角色并绑定

```bash
cat > eli-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: admin
  namespace: eli
rules:
- apiGroups: [""] 
  resources: ["pods"] 
  verbs: ["get","watch","list"]  
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get","list","create","update","patch","delete","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin
  namespace: eli
subjects:
- kind: User
  name: eli
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f eli-role.yml
```



## 4.5 验证权限

```bash
# 复制配置
mkdir -p /home/eli/.kube
cp eli.kubeconfig /home/eli/.kube/config
chown -R eli:eli /home/eli/.kube

# 切换用户
su - eli

# 切换上下文，使 Kubectl 读取到config 信息
$ kubectl config use-context kubernetes --kubeconfig=.kube/config

# 验证
$ kubectl get pod
No resources found in eli namespace.

$ kubectl get svc
Error from server (Forbidden): services is forbidden: User "eli" cannot list resource "services" in API group "" in the namespace "eli"

# 创建 deployment
$ kubectl create deployment nginx --replicas=10 --image=nginx --port-80

$ kubectl get pod
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7848d4b86f-2j7lt   1/1     Running   0          86s
nginx-7848d4b86f-89l2d   1/1     Running   0          86s
nginx-7848d4b86f-9tf57   1/1     Running   0          86s
nginx-7848d4b86f-bhhz2   1/1     Running   0          86s
nginx-7848d4b86f-ft7fv   1/1     Running   0          86s
nginx-7848d4b86f-l7vqn   1/1     Running   0          86s
nginx-7848d4b86f-qrkvh   1/1     Running   0          86s
nginx-7848d4b86f-sjpch   1/1     Running   0          86s
nginx-7848d4b86f-wvm4n   1/1     Running   0          86s
nginx-7848d4b86f-xwnsf   1/1     Running   0          86s
```

