# 1. 安装

## 1.1 试用版

```bash
git clone https://github.com/TykTechnologies/tyk-self-managed-trial && cd tyk-self-managed-trial

DASH_LICENSE=your-tyk-license-key

eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhbGxvd2VkX25vZGVzIjoiMmRlOGI0MTctZTBhZi00YmM2LTZiYWYtMzcxMDJmNjBhNWI0LGE2OGMyYzQ0LTc2NzctNGMyYS01YzFjLTVjMTY1ZjZkYTZkMCIsImV4cCI6MTc1Nzk4MDc5OSwiaWF0IjoxNzU2NzI0NTUzLCJvd25lciI6IjY4YWM4OTk2NWNlZDY3YTMyOWE3MDliNCIsInNjb3BlIjoidHJhY2ssbXVsdGlfdGVhbSxyYmFjLHVkZyxncmFwaCxmZWRlcmF0aW9uIiwidiI6IjIifQ.ulo6mOJAd4hyYMzEWAOZB7VEWp-LJ3P1Jxc4KEIkLG9DYgHTNDoxHyz_suUZHz3YqD-s6_NQPhYIaOhu3mbO8B1-KJ4xaCySsU7qFd-L4WBXJiEVUb4VrXO3JZThPkoiZwVA3Cvps0F3IaqPlA-TgUFPN6FA0Ii6iv4om0AIo6DdJcE6E5mdVtJzDo_1MjSstxdMnn7k9dmsL9ushxy6gUPgPjxjNb0G4GjRJmJ1LoZypXZj-vIEiW4XGrhQfB6vAXnpD_4JGKMLNoHqSpa0CF3FkPVpVtdenxuAnw72KzteDoqPx6cMaKAUDi_GU0Xs0ujAppQjp6qlEaSotkHhnw

docker compose up -d
```


---------------------------
Your Tyk Dashboard URL is http://localhost:3000
user: developer@tyk.io
pw: specialpassword

---------------------------
Your Tyk Gateway URL is http://localhost:8080

---------------------------
Your Developer Portal URL is http://localhost:3001
admin user: portaladmin@tyk.io
admin pw: specialpassword



c0a58f8799500d73

eyJvcmciOiI2OGI2NTA4Y2I0MmNiNjAwMDE1NmUwMzIiLCJpZCI6ImE4NGEwZTI4YzBjYzQ2NDA4ZjRlMWY2ZTc3NTVjMTNmIiwiaCI6Im11cm11cjY0In0=



## 1.2 社区版

```bash
mkdir -p /opt/tyk-gateway/{apps,middleware}
cd /opt/tyk-gateway


cat <<EOF > docker-compose.yml
version: "3.3"

services:
  tyk-gateway:
    image: tykio/tyk-gateway:v5.9.1
    container_name: tyk-gateway
    ports:
      - "3080:8080"
    environment:
      TYK_GW_LISTENPORT: "8080"
      TYK_GW_LOGLEVEL: "debug"
      TYK_GW_SECRET: "aWdvbUAyMDI1Cg=="
      TYK_GW_ENABLEHASHEDKEYSLISTING: "true"
      TYK_GW_STORAGE_TYPE: "redis"
      TYK_GW_STORAGE_HOST: "172.16.8.184"
      TYK_GW_STORAGE_PASSWORD: "123456"
      TYK_GW_STORAGE_DATABASE: "8"
    volumes:
      - ./apps:/opt/tyk-gateway/apps
      - ./middleware:/opt/tyk-gateway/middleware

  httpbin:
    image: kennethreitz/httpbin
    container_name: httpbin
    ports:
      - "3081:80"
EOF
```



# 2. API

## 2.1 创建API

```json
{
 "api_id": "b84fe1a04e5648927971c0557971565c",
 "auth": {
 "auth_header_name": "authorization"
 },
 "definition": {
 "key": "version",
 "location": "header"
 },
 "name": "consul-api",
 "proxy": {
 "listen_path": "/consul-api-test/",
 "strip_listen_path": true,
 "target_url": "http://192.168.3.105:8500"
 },
 "use_oauth2": false,
 "version_data": {
 "not_versioned": true,
 "versions": {
   "Default": {
     "name": "Default"
   }
 }
 }
}
```



## 2.2 创建APP_SECRET

```json
{
 "access_rights": {
 "consul-api": {
   "api_id": "b84fe1a04e5648927971c0557971565c",
   "api_name": "consul-api",
   "limit": {
     "per": 60,
     "quota_max": 10000,
     "quota_remaining": 10000,
     "quota_renewal_rate": 3600,
     "rate": 1000,
     "throttle_interval": 10,
     "throttle_retry_limit": 10
   },
   "versions": [
     "Default"
   ]
 }
 },
 "allowance": 1000,
 "enable_detailed_recording": true,
 "per": 60,
 "quota_max": 10000,
 "quota_renewal_rate": 3600,
 "rate": 1000,
 "throttle_interval": 10,
 "throttle_retry_limit": 10
}

// 返回：
{
    "key": "3cdc23c5e8d24406a828cbeb03852f5e",
    "status": "ok",
    "action": "added",
    "key_hash": "2e6af38f"
}
```



## 2.3 验证

```bash
curl -iv -H "Authorization: e2940c9355cc428993040c54bea2a5c1"  \
 'http://192.168.3.111:8080/consul-api-test/v1/internal/ui/services?dc=dc1&index=62021'
```



HTTP/1.1 404 Not Found



# 3. 参数说明



### 🔑 速率限制（Rate Limiting）

- **`rate`**:
  - 定义在 `per` 时间窗口内允许的请求数上限。
  - 例子：`rate: 1000, per: 60` → 每 60 秒最多允许 1000 次请求。
- **`per`**:
  - 速率限制的时间窗口，单位 **秒**。
  - 上面例子就是 60 秒一个窗口。

------

### 📊 配额（Quota）

- **`quota_max`**:
  - Key 的总请求配额上限。
  - 例子：`quota_max: 10000` → 一共能调用 10000 次。
  - 设置为 `-1` 表示不限制。
- **`quota_remaining`**:
  - 剩余的调用次数。
  - 当 Tyk 创建 Key 时会初始化为 `quota_max`，之后每次请求会递减。
- **`quota_renewal_rate`**:
  - 配额重置周期，单位 **秒**。
  - 例子：`quota_renewal_rate: 3600` → 每小时（3600 秒）重置配额。
  - 如果是 `0`，表示不重置（一次性总量）。

------

### 🕒 节流（Throttle）

- **`throttle_interval`**:
  - 检查速率限制的时间片，单位 **秒**。
  - 例子：`throttle_interval: 10` → 每 10 秒为一个速率检测区间。
- **`throttle_retry_limit`**:
  - 在 `throttle_interval` 内允许的最大请求次数。
  - 如果超过这个值，请求会被立即拒绝，直到下一个 interval。
  - 相当于在全局 `rate/per` 之上，再加一层“短周期”限制，防止突刺流量。







