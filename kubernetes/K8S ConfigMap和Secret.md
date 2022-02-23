# 1. ConfigMap

## 1.1 简介

用途：应用配置管理，实现配置数据和应用程序代码分开。

典型场景：

- 替换镜像中的**环境变量**
- 替换镜像中的**配置文件**

热更新：

- 挂载的 Env 不会同步更新
- 挂载的 Volume 延迟更新 (10s左右)



## 1.2 操作

### 1.2.1 环境变量

1）单值引用

`spec.containers[i].env.valueFrom.configMapKeyRef`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
data:
  special.how: very
  special.type: charm
---
apiVersion: v1
kind: Pod
metadata:
  name: configmap-env-1
spec:
  containers:
  - name: busybox
    image: busybox
    command: [ "/bin/sh", "-c", "env" ]
    env:
    # Define the environment variable
    - name: SPECIAL_LEVEL_KEY
      valueFrom:
        configMapKeyRef:
          name: special-config
          key: special.how
  restartPolicy: Never
```

验证结果：

```bash
$ kubectl logs test-configmap-env | grep SPECIAL_LEVEL_KEY
SPECIAL_LEVEL_KEY=very
```



2）多值引用

`spec.containers[i].envFrom.configMapRef`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tomcat-cfg
data:
  JAVA_HOME: "/usr/lib/jvm/java-8-openjdk-amd64"
  CATALINA_HOME: "/usr/local/apache-tomcat-7.0.69"
---
apiVersion: v1 
kind: Pod 
metadata:
  name: configmap-env-2
spec:
  containers: 
  - name: busybox
    image: busybox
    command: [ "/bin/sh","-c", "echo $(JAVA_HOME) $(CATALINA_HOME)" ] 
    envFrom:
    - configMapRef:
        name: tomcat-cfg
  restartPolicy: Never
```



### 1.2.2 配置文件

`spec.volume[i].configMap`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cfg
data:
  redis-config: |
    maxmemory 2mb
    maxmemory-policy allkeys-lru
---
apiVersion: v1
kind: Pod
metadata:
  name: redis
spec:
  containers:
  - name: redis
    image: redis
    command:
      - redis-server
      - "/redis-master/redis.conf"
    env:
    - name: MASTER
      value: "true"
    ports:
    - containerPort: 6379
    resources:
      limits:
        cpu: "0.1"
    volumeMounts:
    - mountPath: /redis-master-data
      name: data
    - mountPath: /redis-master
      name: config
  volumes:
    - name: data
      emptyDir: {}
    - name: config
      configMap:
        name: redis-cfg
        items:
        - key: redis-config
          path: redis.conf
```

验证结果：

```bash
$ kubectl exec -it redis -- redis-cli
127.0.0.1:6379> CONFIG GET maxmemory
1) "maxmemory"
2) "2097152"

127.0.0.1:6379> CONFIG GET maxmemory-policy
1) "maxmemory-policy"
2) "allkeys-lru"
```



**Nginx 配置：**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ngnix-cfg
data:
  nginx.conf: |
    worker_processes  1;
    events {
        worker_connections  1024;
    }
    http {
        include       mime.types;
        default_type  application/octet-stream;
        #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
        #                  '$status $body_bytes_sent "$http_referer" '
        #                  '"$http_user_agent" "$http_x_forwarded_for"'; 
        #access_log  logs/access.log  main;
        sendfile        on;
        #tcp_nopush     on;
        #keepalive_timeout  0;
        keepalive_timeout  65;
        #gzip  on;
        server {
            listen       80;
            server_name  localhost;
            location / {
                root   /usr/share/nginx/html;
                index  index.html index.htm;
            }
            #error_page  404              /404.html;
            # redirect server error pages to the static page /50x.html
            #
            error_page   500 502 503 504  /50x.html;
            location = /50x.html {
                root   html;
            }
            # proxy the PHP scripts to Apache listening on 127.0.0.1:80
            #
            #location ~ \.php$ {
            #    proxy_pass   http://127.0.0.1;
            #}
            # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
            #
            #location ~ \.php$ {
            #    root           html;
            #    fastcgi_pass   127.0.0.1:9000;
            #    fastcgi_index  index.php;
            #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
            #    include        fastcgi_params;
            #}
            # deny access to .htaccess files, if Apache's document root
            # concurs with nginx's one
            #
            #location ~ /\.ht {
            #    deny  all;
            #}
        } 
    }
  index.html: |
    <h1>Hello World!</h1>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
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
        image: nginx
        resources:
          limits:
            cpu: 200m
            memory: 512Mi
          requests:
            cpu: 200m
            memory: 512Mi
        volumeMounts:
        - mountPath: /etc/nginx/nginx.conf
          name: ngnix-conf
          readOnly: true
          subPath: nginx.conf
        - mountPath: /usr/share/nginx/html/index.html
          name: ngnix-index
          readOnly: true
          subPath: index.html
      restartPolicy: Always
      volumes:
      - name: ngnix-conf
        configMap:
          name: ngnix-cfg
          items:
          - key: nginx.conf
            path: nginx.conf
      - name: ngnix-index
        configMap:
          name: ngnix-cfg
          items:
          - key: index.html
            path: index.html
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30080
  selector:
    app: nginx
```



## 1.3 补充

```bash
# 使用字面值创建
kubectl create configmap mysql-config --from-literal=db.host=192.168.3.100 --from-literal=db.port=3306

# 通过文件创建
kubectl create configmap redis-config --from-file=./redis.conf
kubectl create configmap redis-config --from-file=redis-master.conf=./redis.conf  # 修改默认名称

# 目录下多个文件
kubectl create configmap multi-config --from-file=./configs
```



# 2. Secret

## 2.1 简介

用途：解决密码、token、密钥等敏感数据的配置问题

典型场景：

- **环境变量**
- **volume 挂载**



## 2.2 Secret 类型

| 内置类型                              | 用法                                                         |
| ------------------------------------- | ------------------------------------------------------------ |
| `Opaque`                              | **base64 编码，用来存储密码、密钥等**                        |
| `kubernetes.io/service-account-token` | **用来访问 Kubernetes API，默认由 kubernetes 自动创建，并挂载到 Pod 的** `/run/secrets/kubernetes.io/serviceaccount/` |
| `kubernetes.io/dockercfg`             | `~/.dockercfg` 文件的序列化形式                              |
| `kubernetes.io/dockerconfigjson`      | **用来存储私有 `docker registry` 的认证信息**，`~/.docker/config.json` |
| `kubernetes.io/basic-auth`            | 用于基本身份认证的凭据                                       |
| `kubernetes.io/ssh-auth`              | 用于 SSH 身份认证的凭据                                      |
| `kubernetes.io/tls`                   | **用来存储 TLS 证书**                                        |
| `bootstrap.kubernetes.io/token`       | 启动引导令牌数据                                             |



### 2.2.1 Service Account

Service Account 是 k8s 的一种内置”服务账户“，它绑定了一个特殊的 Secret，即 ServiceAccountToken, 保存了授权信息等内容。任何在 k8s 集群上运行的应用，都必须使用 ServiceAccountToken 中的授权信息，才能合法访问 API Server.

```bash
$ kubectl describe pod nginx-845d4d9dff-4v7p8
...
Containers:
  nginx:
    ...
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-fgghg (ro)
...
Volumes:
  kube-api-access-fgghg:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true

$ kubectl exec -it nginx-845d4d9dff-4v7p8 -- ls /run/secrets/kubernetes.io/serviceaccount
ca.crt  namespace  token
```



### 2.2.2 Opaque

```bash
# 1. 直接创建
$ kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  user: root
  pass: "123456"
EOF

# 2. 使用字面值创建
$ kubectl create secret generic login-credential --from-literal=username=root --from-literal=password=123456

# 3. 通过文件创建
$ cat > user.txt <<EOF
username=root
password=123456
EOF

$ kubectl create secret generic certification --from-file=user.txt
```

1）环境变量

```yaml
apiVersion: apps/v1
kind: Deployment 
metadata:
  name: secret-env
spec:
  replicas: 1 
  selector:
    matchLabels:
      app: secret-env
  template:
    metadata:
      labels:
        app: secret-env
    spec:
      containers:
      - name: busybox
        image: busybox
        command: [ "/bin/sh", "-c", "echo $(TEST_USERNAME) $(TEST_PASSWORD)" ] 
        env:
        - name: TEST_USERNAME 
          valueFrom:
            secretKeyRef:
              name: login-credential
              key: username 
        - name: TEST_PASSWORD 
          valueFrom:
            secretKeyRef:
              name: login-credential
              key: password
        restartPolicy: Never
```

2）挂载 volume

将 'user.txt' 挂载到 "/etc/secrets" 下

```yaml
apiVersion: v1 
kind: Pod 
metadata:
  name: secret-volume
spec:
  containers:
  - image: busybox
    name: busybox
    command:
    - /bin/sleep
    - "3600"
    volumeMounts:
    - name: secrets 
      mountPath: "/etc/secrets"
      readOnly: true
  volumes:
  - name: secrets 
    secret:
      secretName: certification 
```



### 2.2.3 DockerConfigJson

```bash
# 创建 docker-registry 认证信息
kubectl create secret docker-registry myregistrykey --docker-server=registry.xtwl.io --docker-username=admin --docker-password=Admin123 --docker-email=admin@xtwl.io
```

使用：

```yaml
apiVersion: v1 
kind: Pod 
metadata:
  name: docker-registry-json 
spec:
  containers:
  - name: busybox 
    image: registry.xtwl.io/library/busybox
  imagePullSecrets:
  - name: myregistrykey
```



### 2.2.4 TLS

1）创建 tls

```json
kubectl create secret tls xtwl-secret --key tls.key --cert tls.crt
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: xtwl-secret
data:
  tls.crt: **************************
  tls.key: **************************
```

2）使用 tls

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test
spec:
  tls:
  - hosts:
    - xtwl.com
    secretName: xtwl-secret
  rules:
  - host: xtwl.com
    http:
      paths:
      - path: /
        backend:
          serviceName: web-svc
          servicePort: 30080
```



# 3. DownwardAPI

作用：让 Pod 中的容器，能够直接获取该 Pod API 对象本身的信息

## 3.1 挂载文件

`.spec.volumes[*].downwardAPI.items[*].fieldRef.fieldPath`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: downward-api-volume
  labels:
    zone: CST
    app: busybox
  annotations:
    version: "1.2"
    builder: gopher
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c"]
    args:
    - while true; do;
        if [[ -e /etc/podinfo/labels ]]; then
          echo -en '\n\n'; cat /etc/podinfo/labels; fi;
        if [[ -e /etc/podinfo/annotations ]]; then
          echo -en '\n\n'; cat /etc/podinfo/annotations; fi;
        sleep 5;
      done
    volumeMounts:
    - name: podinfo
      mountPath: /etc/podinfo
  volumes:
  - name: podinfo
    downwardAPI:
      items:
      - path: "labels"
        fieldRef:
          fieldPath: metadata.labels
      - path: "annotations"
        fieldRef:
          fieldPath: metadata.annotations
```



## 3.2 环境变量

`.spec.containers[*].env.valueFrom.fieldRef.fieldPath`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: downward-api-env
spec:
  restartPolicy: Never
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "env"]
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
```

