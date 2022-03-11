# 1. 概述

NetworkPolicy 是一种以应用为中心的结构，允许你设置如何允许 Pod 与网络上的各类网络 “实体” 通信，在 IP/Port (L3/L4) 层面控制网络流量。

Pod 之间的通信通过如下三个标识符的组合来辩识的：

1. 其他被允许的 Pods（例外：Pod 无法阻塞对自身的访问）
2. 被允许的名字空间
3. IP 组块（例外：与 Pod 运行所在的节点的通信总是被允许的， 无论 Pod 或节点的 IP 地址）



支持的网络插件：

- Calico
- Canal
- Cilium
- Kube-router
- Romana
- Weave Net



网络策略定义：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-definitions.png)

- Pod Selector：通过标签选择得到的一组被隔离的pod，只有满足一定的访问规则才能被使用

- Ingress: 同时存在 allow和 deny 规则时，将被allow
  - NetworkPolicyPeer：is the other side of the connection
    - If an IP Block is specified, the rule applies to the addresses defined by the block.
    - If a Namespace is specified, the rule applies to select pods within the namespace.
    - If a Namespace Selector is specified, the rule applies to all pods within a namespace.
    - If a Pod and Namespace Selector is specified, the rule applies to select pods within a specified namespace.
  - NetworkPolicyPort：allows you to explicitly name ingress and egress ports or protocols that may communicate with the pod group.
- Engress:
  - NetworkPolicyPeer
  - NetworkPolicyPort



# 2. Deny all traffic to an application

This NetworkPolicy will drop all traffic to pods of an application, selected using Pod Selectors.

**Use Cases:**

- It’s very common: To start whitelisting the traffic using Network Policies, first you need to blacklist the traffic using this policy.
- You want to run a Pod and want to prevent any other Pods communicating with it.
- You temporarily want to isolate traffic to a Service from other Pods.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-deny-all-traffic.gif)

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80

$ kubectl run -it test-$RANDOM --rm --image=alpine -- sh
/ # wget -qO- http://web
<!DOCTYPE html>
<html>
<head>
...

# 增加网络策略，限制访问
$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-deny-all
spec:
  podSelector:
    matchLabels:
      app: web
  ingress: []
EOF

$ kubectl apply -f web-deny-all.yaml

# 再次尝试访问，timeout
$ kubectl run -it test-$RANDOM --rm --image=alpine -- sh
/ # wget -qO- --timeout=3 http://web
wget: download timed out

# 清理
kubectl delete pod web
kubectl delete service web
kubectl delete networkpolicy web-deny-all
```



# 3. Limit traffic to an application

You can create Networking Policies allowing traffic from only certain Pods.

**Use Case:**

- Restrict traffic to a service only to other microservices that need to use it.
- Restrict connections to a database only to the application using it.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-limit-traffic.gif)

```bash
$ kubectl run web --image=nginx --labels="app=bookstore,role=api" --expose --port=80

$ cat << EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: api-allow
spec:
  podSelector:
    matchLabels:
      app: bookstore
      role: api
  ingress:
  - from:
      - podSelector:
          matchLabels:
            app: bookstore
EOF

# 未指定正确的标签，无法访问
$ kubectl run -it test-$RANDOM --rm --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web
wget: download timed out

# 标签正确，可访问
$ kubectl run -it test-$RANDOM --rm --image=alpine --labels="app=bookstore,role=frontend" -- sh
/ # wget -qO- --timeout=2 http://web
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod web
kubectl delete service web
kubectl delete networkpolicy api-allow
```



# 4. Allow all traffic to an application

**Use Case:** After applying a **deny-all** policy which blocks all non-whitelisted traffic to the application, now you have to allow access to an application from all pods in the current namespace.

Applying this policy makes any other policies restricting the traffic to the pod void, and allow all traffic to it from its namespace and other namespaces.

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-deny-all
spec:
  podSelector:
    matchLabels:
      app: web
  ingress: []
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-all
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - {}
EOF

# allow的权限大于deny
$ kubectl run -it test-$RANDOM --rm --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete networkpolicy web-deny-all web-allow-all
```



补充：Empty ingress rule (`{}`) allows traffic from all pods in the current namespace, as well as other namespaces. It corresponds to:

```yaml
- from:
  - podSelector: {}
    namespaceSelector: {}
```



# 5. DENY all non-whitelisted traffic to a namespace

**Use Case:** This is a fundamental policy, blocking all cross-pod networking other than the ones whitelisted via the other Network Policies you deploy.

Consider applying this manifest to any namespace you deploy workloads to (anything but `kube-system`).

**Best Practice:** This policy will give you a default "deny all" functionality. This way, you can clearly identify which components have dependency on which components and deploy Network Policies which can be translated to dependency graphs between components.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-deny-all-non-whitelisted-traffic.gif)

```bash
$ kubectl run web --image=nginx --expose --port=80

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}   # empty, means it will match all the pods
  ingress: []       # no rules specified, it causes incoming traffic to be dropped
EOF

# same namespace
$ kubectl run test-$RANDOM -it --rm --image=alpine -- sh
/ # wget -qO- --timeout=2 http://web
wget: download timed out

# cross namespace
$ kubectl run test-$RANDOM -it --rm --image=alpine -n kube-system -- sh
/ # wget -qO- --timeout=2 http://web
wget: bad address 'web'
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

# 清理
kubectl delete pod,svc web
kubectl delete networkpolicy default-deny-all
```



# DENY all traffic from other namespaces

You can configure a NetworkPolicy to **deny all the traffic from other namespaces while allowing all the traffic coming from the same namespace** the pod deployed to.

**Use Cases**

- You do not want deployments in `test` namespace to accidentally send traffic to other services or databases in `prod` namespace.
- You host applications from different customers in separate Kubernetes namespaces and you would like to block traffic coming from outside a namespace.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-deny-all-other-ns-traffic.gif)

```bash
$ kubectl run web --image=nginx --labels="app=web" --namespace=default --expose --port=80

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: default
  name: deny-from-other-namespaces
spec:
  podSelector:
    matchLabels:   # empty, select all pods in 'default' namespace
  ingress:
  - from:
    - podSelector: {}   # empty, all all pods in 'default' namespace
EOF

# 非default命名空间，无法访问
$ kubectl create namespace foo
$ kubectl run test-$RANDOM -it --rm --image=alpine -n foo -- sh
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

# default命名空间，可正常访问
$ kubectl run test-$RANDOM -it --rm --image=alpine -n default -- sh
/ # wget -qO- --timeout=2 http://web
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete ns foo
kubectl delete networkpolicy deny-from-other-namespaces
```



# ALLOW traffic to an application from all namespaces

This NetworkPolicy will allow traffic from all pods in all namespaces to a particular application.

**Use Case:**

- You have a common service or a database which is used by deployments in different namespaces.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-allow-traffic-from-all-namespaces.gif)

```bash
$ kubectl run web --image=nginx --labels="app=web" --namespace=default --expose --port 80

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: default
  name: web-allow-all-namespaces
spec:
  podSelector:
    matchLabels:
      app: web    # apply the policy only to the pods that are labeled by app=web
  ingress:
  - from:
    - namespaceSelector: {}  # empty, allow all namespaces to access
EOF

$ kubectl run test-$RANDOM -it --rm --image=alpine --namespace=bar -- sh
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete ns bar
kubectl delete networkpolicy web-allow-all-namespaces
```



# ALLOW all traffic from a namespace

This policy is similar to allowing traffic from all namespaces  but shows how you can choose particular namespaces.

**Use Case:**

- Restrict traffic to a production database only to namespaces where production workloads are deployed.
- Enable monitoring tools deployed to a particular namespace to scrape metrics from the current namespace.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-allow-traffic-from-a-namespace.gif)

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port 80

$ kubectl create namespace dev
$ kubectl label namespace/dev purpose=develop
$ kubectl create namespace prod
$ kubectl label namespace/prod purpose=production

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-prod
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: production   # only pods in namespace that has label `purpose=prodution` will be allowed 
EOF

$ kubectl run test-$RANDOM -it --rm --image=alpine --namespace=dev -- sh
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

$ kubectl run test-$RANDOM -it --rm --image=alpine --namespace=prod -- sh
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete ns dev prod
kubectl delete networkpolicy web-allow-prod
```



# ALLOW traffic from some pods in another namespace

Since Kubernetes v1.11, it is possible to combine `podSelector` and `namespaceSelector` with an `AND` (intersection) operation.

⚠️ This feature is available on Kubernetes v1.11 or after. Most networking plugins do not yet support this feature. Make sure to test this policy after you deploy it to make sure it is working correctly.

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80

$ kubectl create namespace other
$ kubectl label namespace/other team=operations

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-all-ns-monitoring
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
    - from:
      - namespaceSelector:     
          matchLabels:
            team: operations  # chooses all pods in namespaces labelled with team=operations
        podSelector:          
          matchLabels:
            type: monitoring  # chooses pods with type=monitoring
EOF

# 仅namespace满足，不能访问
$ kubectl run test-$RANDOM -it --rm --image=alpine --namespace=other -- sh
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

# 仅label满足，不能访问
$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="type=monitoring" -- sh
/ # wget -qO- --timeout=2 http://web.default
wget: download timed out

# namespace和label都满足，可以访问
$ kubectl run test-$RANDOM -it --rm --image=alpine --namespace=other --labels="type=monitoring" -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -qO- --timeout=2 http://web.default
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete ns other
kubectl delete networkpolicy web-allow-all-ns-monitoring
```



# ALLOW traffic from external clients

This Network Policy enables external clients from the public Internet directly or via a Load Balancer to access to the pod.

**Use Cases:**

- You need to expose the pods to the public Internet in a namespace denying all non-whitelisted traffic

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-allow-traffic-from-external.gif)

```bash
$ kubectl run web --image=nginx --labels="app=web" --port 80
$ kubectl expose pod/web --type=NodePort

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-allow-external
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - {}
EOF

$ kubectl get svc web
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
web          NodePort    10.96.223.48   <none>        80:31261/TCP   65s

$ wget -qO- http://192.168.3.103:31261
<!DOCTYPE html>
<html>
<head>
...

# 清理
kubectl delete pod,svc web
kubectl delete networkpolicy web-allow-external
```



# ALLOW traffic only to a port of an application

This NetworkPolicy lets you define ingress rules for specific ports of an application. If you do not specify a port in the ingress rules, the rule applies to all ports.

A port may be either a numerical or named port on a pod.

**Use Cases**

- Allow monitoring system to collect the metrics by querying the diagnostics port of your application, without giving it access to the rest of the application.

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/network-policy-allow-traffic-only-to-port.gif)

```bash
$ kubectl run web --image=ahmet/app-on-two-ports --labels="app=web"
$ kubectl create service clusterip web --tcp 8001:8000 -tcp 5001:5000

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: api-allow-5000
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - ports:
    - port: 5000
    from:
    - podSelector:
        matchLabels:
          role: monitoring
EOF

# 未指定label，无法访问
$ kubectl run test-$RANDOM -it --rm --image=alpine -- sh
wget: download timed out
/ # wget -qO- --timeout=2 http://web:5001/metrics
wget: download timed out

# 指定label，且只能访问5000端口
$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="role=monitoring" -- sh
/ # wget -qO- --timeout=2 http://web:8001
wget: download timed out
/ # wget -qO- --timeout=2 http://web:5001/metrics
http.requests=1
go.goroutines=5
go.cpus=4

# 清理
kubectl delete pod,svc web
kubectl delete networkpolicy api-allow-5000
```



# ALLOW traffic from apps using multiple selectors

NetworkPolicy lets you define multiple pod selectors to allow traffic from.

**Use Case**

- Create a combined NetworkPolicy that has the list of microservices that are allowed to connect to an application.

```bash
$ kubectl run db --image=redis --labels="app=bookstore,role=db" --expose --port=6379

$ cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: redis-allow-services
spec:
  podSelector:
    matchLabels:
      app: bookstore
      role: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: bookstore
          role: search
    - podSelector:
        matchLabels:
          app: bookstore
          role: api
    - podSelector:
        matchLabels:
          app: inventory
          role: web
EOF

# label满足条件
$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="app=inventory,role=web" -- sh
/ # nc -v -w 2 db 6379
db (10.96.204.248:6379) open

# label 不满足
$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="app=other" -- sh
/ # nc -v -w 2 db 6379
nc: db (10.96.204.248:6379): Operation timed out

# 清理资源
kubectl delete pod,svc db
kubectl delete networkpolicy redis-allow-services
```



## DENY egress traffic from an application

**Use Cases:**

- You want to prevent an application from establishing any connections to outside of the Pod.
- Useful for restricting outbound traffic of single-instance databases and datastores.

```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80

$ cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: foo-deny-egress
spec:
  podSelector:
    matchLabels:
      app: foo
  policyTypes:
  - Egress
  egress: []
EOF

$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="app=foo" -- sh
/ # wget -qO- --timeout=2 http://web
wget: bad address 'web'
/ # wget -qO- --timeout=2 http://google.com
wget: bad address 'google.com'
/ # ping -c 3 -W 2 192.168.3.1
PING 192.168.3.1 (192.168.3.1): 56 data bytes
--- 192.168.3.1 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
/ # ping -W 2 -c 3 google.com
ping: bad address 'google.com'

# allow DNS traffic
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: foo-deny-egress
spec:
  podSelector:
    matchLabels:
      app: foo
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
EOF

# 可正常解析域名
$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="app=foo" -- sh
/ # wget -qO- --timeout=2 http://web
wget: download timed out
/ # wget -qO- --timeout=2 http://google.com
wget: download timed out
/ # ping -W 2 -c 3 google.com
PING google.com (142.251.42.238): 56 data bytes
--- google.com ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss

# 清理操作
kubectl delete pod,svc web
kubectl delete networkpolicy foo-deny-egress
```



# DENY all non-whitelisted traffic from a namespace

💡 **Use Case:** This is a fundamental policy, blocking all outgoing (egress) traffic from a namespace by default (including DNS resolution). After deploying this, you can deploy Network Policies that allow the specific outgoing traffic.

Consider applying this manifest to any namespace you deploy workloads to (except `kube-system`).

💡 **Best Practice:** This policy will give you a default "deny all" functionality. This way, you can clearly identify which components have dependency on which components and deploy Network Policies which can be translated to dependency graphs between components.

```bash
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny-all-egress
  namespace: default
spec:
  policyTypes:
  - Egress
  podSelector: {}     # empty, it will apply the policy to all pods of default namespace
  egress: []          # empty array, it causes all traffic (including DNS resolution) to be dropped
```



# DENY external egress traffic

*(a.k.a LIMIT traffic to pods in the cluster)*

**Use Cases:**

- You want to prevent certain type of applications from establishing connections to the external networks.



```bash
$ kubectl run web --image=nginx --labels="app=web" --expose --port=80

$ cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: foo-deny-external-egress
spec:
  podSelector:
    matchLabels:
      app: foo
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  - to:
    - namespaceSelector: {}  # empty, it will allow all pods in all namespaces, so the outbound traffic to pods in the cluster will be allowed
EOF

$ kubectl run test-$RANDOM -it --rm --image=alpine --labels="app=foo" -- sh
<!DOCTYPE html>
<html>
<head>
...

/ # wget -qO- --timeout=2 http://google.com
wget: download timed out
```





```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```







https://docs.nirmata.io/applicationmanagement/resources/networkpolicies/

https://github.com/ahmetb/kubernetes-network-policy-recipes