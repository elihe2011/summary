

# 1. Docker

## 1.1 代理配置

```bash
# 国内仓库
$ vi /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://pvjhx571.mirror.aliyuncs.com"
  ]
}

# 代理设置
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="ALL_PROXY=http://192.168.3.99:8889/"
Environment="NO_PROXY=localhost,127.0.0.1,docker.io,hub.docker.com,hub-mirror.c.163.com,pvjhx571.mirror.aliyuncs.com"
EOF

systemctl daemon-reload && systemctl restart docker
systemctl show --property=Environment docker


mkdir -p ~/.docker
cat > ~/.docker/config.json <<EOF
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "http://192.168.3.3:8889",
     "httpsProxy": "http://192.168.3.3:8889",
     "noProxy": "127.0.0.1,docker.io,hub.docker.com,hub-mirror.c.163.com,pvjhx571.mirror.aliyuncs.com"
   }
 }
}
EOF


```



# 2. hey 性能测试

```bash
# 2个客户端，持续发送5s请求
hey -c 2 -z 5s https://www.baidu.com/

# 50个客户端，发送2000次请求
hey -n 2000 -c 50  https://www.baidu.com/

# 2个客户端，持续发送5s请求，使用的cpu核数为2
hey -c 2 -z 5s -cpus 2 -host "baidu.com" https://220.181.38.148

# 带header的请求：压测时长为5s (-z), 客户端发送请求的速度为128QPS
hey -z 5s -q 128 -H "client-ip:0.0.0.0" -H "X-Up-Calling-Line-Id:X.L.Xia" https://www.baidu.com/

# POST请求
hey -z 5s -c 50 -m POST -H "info:firstname=xiuli; familyname=xia" -d "year=2020&month=1&day=21" https://www.baidu.com/

# 代理模式，需额外配置proxy：因部分ip频繁发请求有风险，故可用-x设置白名单代理向服务器发请求
hey -z 5s -c 10 -x "http://127.0.0.1:8001" http://baidu.com/

# shell for循环实现压测
for i in `seq 10`; do curl -v http://baidu.com; done
```

