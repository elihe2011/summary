# 1. 简介

![img](https://raw.githubusercontent.com/elihe2011/bedgraph/master/kubernetes/k8s-pod-lifecycle.png)

1）kubectl --> apiserver --> CRI --> kubelet  环境初始化

2）启动Pause容器: 初始化网络和数据卷。其镜像由汇编写成，永远处于“pause”状态的容器，解压后大小100~200KB，运行时占用极小的资源

3）init C初始化。多个initC时，必须串行执行，且每个必须执行成功才向下走

4）Main C，开始运行时，启动Start命令/脚本；结束时，执行Stop命令(做哪些清理操作等)

5）Readiness 就绪检测：若干秒后，进行是否就绪的探测。只有当Readiness成功后，Pod才会显示Ready状态

6）Liveness 生存检测：探测Main C中的进程是否正常，不正常则执行重启、删除等命令



# 2. InitC 容器

作用：

- initC 容器可作为 Pod 中其他容器的初始化工具

- 出于安全考虑，将应用容器中的某些实用工具（python, awk等）单独拆开放入initC容器
- 应用容器的启动是并行的，而 initC 容器可阻塞应用容器的启动，直到满足一些先决条件

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-initc
  labels:
    app: myapp
spec:
  initContainers:
  - name: init-mysvc
    image: tutum/dnsutils
    command: ['sh', '-c', 'until nslookup mysvc; do echo "waiting for mysvc"; sleep 2; done']
  - name: init-mydb
    image: tutum/dnsutils
    command: ['sh', '-c', 'until nslookup mydb; do echo "waiting for mydb"; sleep 2; done']
  containers:
  - name: mypod
    image: busybox
    command: ['sh', '-c', 'while true; do echo "myapp is running!"; sleep 3600; done']
---
apiVersion: v1
kind: Service
metadata:
  name: mysvc
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9001
---
apiVersion: v1
kind: Service
metadata:
  name: mydb
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9002
```



# 3. 容器探针

健康状态探针：

- **ReadinessProbe**: 判断容器服务是否可用，成功显示ready， 失败不触发重启
- **LivenessProbe**: 判断容器是否存活，如果探测到不健康，将触发重启策略。如果未配置该探针，则永远返回成功.

探针的三种实现方式：

- **ExecAction**: 容器内执行命令，返回码等于0则认为成功
- **TCPSocketAction**: 在指定端口上的容器IP地址进行TCP检查，如果端口打开，则认为成功
- **HTTPGetAction**: 在指定端口和路径的容器IP地址执行HTTP GET请求，状态码在 [200, 399] 表示成功

探测结果：

- success
- failed：失败，按策略处理
- unknown：诊断失败，但不会采取任何行动



## 3.1 就绪检测

检测失败，状态非Ready，但不会重启容器

**spec.containers[].readinessProbe.httpGet**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-test
spec:
  containers:
  - name: nginx
    image: nginx
    readinessProbe:
      httpGet:
        port: 80
        path: /index1.html
      initialDelaySeconds: 1
      periodSeconds: 3
```

```bash
$ kubectl get pod
NAME             READY   STATUS    RESTARTS   AGE
readiness-test   0/1     Running   0          76s

$ kubectl describe pod readiness-test
Warning  Unhealthy  35s (x21 over 94s)  kubelet            Readiness probe failed: HTTP probe failed with statuscode: 404

# 更新容器
$ kubectl exec -it readiness-test -- /bin/sh
# echo '<h1>hello world</h1>' > /usr/share/nginx/html/index1.html
# logout

$ kubectl get pod
NAME             READY   STATUS    RESTARTS   AGE
readiness-test   1/1     Running   0          6m4s
```



## 3.2 存活检测

检测失败，直接重启Pod

**spec.containers[].livenessProbe.exec**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec-test
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "touch /tmp/abc.txt; sleep 60; rm -f /tmp/abc.txt; sleep 3600"]
    livenessProbe:
      exec:
        command: ["test", "-e", "/tmp/abc.txt"]
      initialDelaySeconds: 1
      periodSeconds: 3
```

```bash
# 失败，重启自动重启
$ kubectl get pod -w
NAME                 READY   STATUS    RESTARTS   AGE
liveness-exec-test   1/1     Running   0          8s
liveness-exec-test   1/1     Running   1          108s
liveness-exec-test   1/1     Running   2          3m30s
liveness-exec-test   1/1     Running   3          5m11s
```

**spec.containers[].livenessProbe.tcpSocket**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-tcpsocket
spec:
  containers:
  - name: redis
    image: redis
    livenessProbe:
      tcpSocket:
        port: 6379
      initialDelaySeconds: 5
      periodSeconds: 3
      timeoutSeconds: 1
```



# 4. 启动 & 退出

**spec.containers[].lifecycle.postStart|preStop**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo 'hello world' > /tmp/hello.txt"]
      preStop:
        exec:
          command: ["/usr/sbin/nginx", "-s", "quit"]
```



# 5. Pod 状态值

- Pending：Pod已被k8s系统接受，但有一个或多个容器尚未创建。等待包括Pod调度、镜像下载等操作。
- Running: Pod中的容器已被创建
- Succeeded: Pod中的容器都被成功终止，且不会再重启
- Failed: Pod中的容器都已终止，但至少有一个容器以非0返回值退出
- Unknown: 未知原因无法获取Pod状态，通常是因为与Pod所在主机的通信失败