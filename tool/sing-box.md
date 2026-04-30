# 1. 安装

https://github.com/sagernet/sing-box

```bash
curl -fsSL https://sing-box.app/install.sh | sh
```



# 2. 配置

## 2.1 dns

```json
{
  "dns": {
    "strategy": "prefer_ipv4",
    "servers": [
      {
        "type": "udp",
        "tag": "google",
        "server": "8.8.8.8"
      },
      {
        "type": "udp",
        "tag": "cloudflare",
        "server": "1.1.1.1"
      }
    ]
  }
}
```



## 2.2 trojan

```json
{
  "inbounds": [
    {
      "type": "http",
      "tag": "http-in",
      "listen": "0.0.0.0",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "trojan",
      "tag": "trojan-out",
      "server": "HOST",
      "server_port": 443,
      "password": "PASSWORD",
      "tls": {
        "enabled": true,
        "server_name": "HOST",
        "insecure": true
      },
      "multiplex": {
        "enabled": false
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "trojan-out",
    "default_domain_resolver": "google"
  }
}
```



## 2.3 vless

```bash
{
"inbounds": [
    {
      "type": "http",
      "tag": "http-in",
      "listen": "0.0.0.0",
      "listen_port": 7890
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-grpc-out",
      "server": "IP",
      "server_port": 443,
      "uuid": "UUID",
      "packet_encoding": "xudp",
      "tls": {
        "enabled": true,
        "server_name": "HOST"
      },
      "transport": {
        "type": "grpc",
        "service_name": "SERVICE_NAME",
        "idle_timeout": "15s",
        "ping_timeout": "15s",
        "permit_without_stream": false
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "vless-grpc-out",
    "default_domain_resolver": "google"
  }
}
```

