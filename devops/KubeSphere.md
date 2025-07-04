# 1. 页面

```bash
$ kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f
...
Console: http://192.168.3.190:30880
Account: admin
Password: P@88w0rd
...
```

修改密码为：`Abc@12345`



# 2. API

## 2.1 暴露 ks-apiserver 服务

```bash
kubectl -n kubesphere-system patch svc ks-apigateway -p '{"spec":{"type":"NodePort","ports":[{"name":"ks-apigateway","port":80,"protocal":"TCP","targetPort":2018,"nodePort":30881}]}}'


kubectl -n kubesphere-system patch service ks-apiserver -p '{"spec":{"type":"NodePort","ports":[{"port":80,"protocal":"TCP","targetPort":9090,"nodePort":30881}]}}'

kubectl -n kubesphere-system patch service ks-apiserver -p '{"spec":{"type":"NodePort","ports":[{nodePort":30882}]}}'
```



## 2.2 生成令牌

```bash
curl -X POST \
  http://192.168.3.190:30880/kapis/iam.kubesphere.io/v1alpha2/login \
  -H 'Content-Type: application/json' \
  -d '{
  "username":"admin",
  "password":"Abc@12345"
}'

curl -X POST -H 'Content-Type: application/x-www-form-urlencoded' \
 'http://192.168.3.190:30881/oauth/token' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode 'username=admin' \
  --data-urlencode 'password=Abc@12345' \
  --data-urlencode 'client_id=kubesphere' \
  --data-urlencode 'client_secret=kubesphere'
```



## 3.2 发起调用

```bash
curl -X GET -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2ODU1MjQwOTMsImlhdCI6MTY4NTUxNjg5MywiaXNzIjoia3ViZXNwaGVyZSIsInN1YiI6ImFkbWluIiwidG9rZW5fdHlwZSI6ImFjY2Vzc190b2tlbiIsInVzZXJuYW1lIjoiYWRtaW4ifQ.5KR5atyxPSrl8JJRWTAEkwS24PKsVG4ZV4kFTZ_73eA" \
  -H 'Content-Type: application/json' \
  'http://192.168.3.190:30880/kapis/resources.kubesphere.io/v1alpha3/nodes'
```





```bash
./kk create config --with-kubernetes v1.22.12 --with-kubesphere v3.3.2  
```





# 配置dns解析





coredns.yaml 新增 hosts配置，解析harbor域名

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        hosts {
           192.168.3.190 registry.xtwl.local
           fallthrough
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```





```bash
kubectl patch configmap/coredns \
  -n kube-system \
  --type merge \
  -p '{"data":{"upstreamNameservers":"[\"1.1.1.1\", \"1.0.0.1\"]"}}'
```

