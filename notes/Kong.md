Kong



values.yaml

```yaml
env:
 pg_database: kong
 pg_hos: kong-ingress-controller-postgresql
 database: postgres
 pg_user: kong
 pg_password:
  valueFrom:
   secretKeyRef:
    key: postgresql-password
    name: kong-ingress-controller-postgresql
postgresql:
 enabled: true
 postgresqlUsername: kong
 postgresqlDatabase: kong
 service:
  port: 5432
 existingSecret: kong-ingress-controller-postgresql
```





```bash
helm repo add kong https://charts.konghq.com

helm install kong-ingress-controller kong/kong-ingress-controller -f values.yaml
```



kong plugin 配置：(rate-limiting)

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limiting
  plugin: rate-limiting
config:
  policy: redis
  redis_host: redis-instance
  redis_port: 6379
  second: 300
```



- **config.policy**:
  - **local** means the counter will be stored in memory.
  - **cluster** means the kong database will store the counter.
  - **redis** means a Redis will store the counter.

- **config.second**: The maximum of requests per second



Kong consumer:

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: my-great-consumer
  username: my-great-consumer
  custom_id: my-great-consumer
```



**Configure API gateway routes**:

```yaml
apiVersion:
kind:
metadata:
 name: api-gateway-routes
 annotations:
  konghq.com/plugins: rate-limiting
spec:
 ingressClassName: "kong"
 rules:
  - host: myproject.api.me
    http:
     paths:
      - path: /users
        backend:
         serviceName: myproject
         servicePort: 80
      - path: /groups
        backend:
         serviceName: myproject
         servicePort: 80
```









```lua
local ngx_re = require "ngx.re"
local BasePlugin = require "kong.plugins.base_plugin"
local string = require "resty.string"
local BuserResolveHandler = BasePlugin:extend()

function BuserResolveHandler:new()
    BuserResolveHandler.super.new(self, "buser-resolve")
end

function BuserResolveHandler:access(conf)
    BuserResolveHandler.super.access(self)
    local cookieName = "cookie_" .. "KUAIZHAN_V2"
    local kuaizhanV2 = ngx.var[cookieName]
--     ngx.log(ngx.ERR, "kuaizhanV2", kuaizhanV2)
    local uid = 0
    ngx.req.set_header("X-User-Id", uid)
  
    // cookie 内容 3001459%7C1636684996%7C7180720502%7Cb61a12ef865072964aa359e6a9ef2e0b1846dee9
    if xxx_V2 and xxx_V2 ~= '' then
        local res, err = ngx_re.split(xxxV2, "%7C")
        if err then
            return
        end
        // 解析得到 userId, time, nonce, sign，
        // 分别为 3001459，1636684996，7180720502，b61a12ef865072964aa359e6a9ef2e0b1846dee9
        local userId, time, nonce, sign = res[1], res[2], res[3], res[4]
        // 根据密钥，时间，签名，利用 hmac_sha1 算法，十六进制算法，得到摘要签名
        local digest = ngx.hmac_sha1(conf.secret, userId .. time .. nonce)
        local theSign = string.to_hex(digest)
        -- TODO 加上过期时间判断
        // 计算签名和cookie解析得到sign 是否相同，相同则赋值uid
        if theSign == sign then
            uid = userId
        end
        ngx.log(ngx.ERR, "theSign:", theSign, "sign:", sign, "uid:", uid)
    end

    ngx.log(ngx.ERR, "get x-user-id:" .. uid)
    // nginx 请求头header里面存放 X-User-Id,再转发到各个业务线
    ngx.req.set_header("X-User-Id", uid)
end

return BuserResolveHandler
```





安装kong：



mkdir -p docker/kong
$ touch docker/kong/Dockerfile



```dockerfile
FROM kong:1.4.2-centos

LABEL description="Centos 7 + Kong 1.4.2 + kong-oidc plugin"

RUN yum install -y git unzip && yum clean all

RUN luarocks install kong-oidc
```



```bash
docker build -t kong:1.4.2-centos-oidc .
```



docker-compose.yaml

```yaml
version: '3.4'

networks: 
  kong-net:

volumes:
  kong-datastore:

services:
  kong-db:
    image: postgres:9.6
    volumes:
      - kong-datastore:/var/lib/postgresql/data
    networks:
      - kong-net
    ports:
      - "15432:5432"
    environment:
      POSTGRES_DB:       api-gw
      POSTGRES_USER:     kong
      POSTGRES_PASSWORD: kong

  kong:
    image: kong:1.4.2-centos-oidc
    depends_on:
      - kong-db
    networks:
      - kong-net
    ports:
      - "8000:8000" # Listener
      - "8001:8001" # Admin API
      - "8443:8443" # Listener  (SSL)
      - "8444:8444" # Admin API (SSL)
    environment:
      KONG_DATABASE:         postgres
      KONG_PG_HOST:          kong-db
      KONG_PG_PORT:          5432
      KONG_PG_DATABASE:      api-gw
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG:  /dev/stderr
      KONG_ADMIN_ERROR_LOG:  /dev/stderr
      KONG_PROXY_LISTEN:     0.0.0.0:8000, 0.0.0.0:8443 ssl
      KONG_ADMIN_LISTEN:     0.0.0.0:8001, 0.0.0.0:8444 ssl
      KONG_PLUGINS:          bundled,oidc
      
  konga-prepare:
     image: pantsel/konga:next
     command: "-c prepare -a postgres -u postgresql://kong:kong@kong-db:5432/konga_db"
     networks:
       - kong-net
     restart: on-failure
     links:
       - kong-db
     depends_on:
       - kong-db
       
  konga:
    image: pantsel/konga:latest
    networks:
      - kong-net
    environment:
      DB_ADAPTER: postgres
      DB_HOST: kong-db
      DB_USER: kong
      DB_DATABASE: konga_db
      NODE_ENV: production
      DB_PASSWORD: kong
    depends_on: 
      - kong-db
      - konga-prepare
    ports:
      - "1337:1337"
```



安装kong：

```bash
# 创建网络
docker network create kong-net

# 持久化
docker volume create kong-volume

# 数据库
docker run -d --name kong-database \
           --network=kong-net \
           -p 5432:5432 \
           -v kong-volume:/var/lib/postgresql/data \
           -e "POSTGRES_USER=kong" \
           -e "POSTGRES_DB=kong" \
           -e "POSTGRES_PASSWORD=kong"  \
           postgres:9.6
           
# 初始化或者迁移数据库
docker run --rm \
 --network=kong-net \
 -e "KONG_DATABASE=postgres" \
 -e "KONG_PG_HOST=kong-database" \
 -e "KONG_PG_PASSWORD=kong" \
 -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
 kong:3.3.0 kong migrations bootstrap --vvv
 
 # 启动
 docker run -d --name kong \
 --network=kong-net \
 -e "KONG_DATABASE=postgres" \
 -e "KONG_PG_HOST=kong-database" \
 -e "KONG_PG_PASSWORD=kong" \
 -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
 -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
 -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
 -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
 -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
 -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
 -e "KONG_PLUGIN=bundled,custom-auth" \
 -e "KONG_LUA_PACKAGE_PATH=/usr/local/share/lua/5.1/kong/plugins/custom-auth/?.lua;;" \
 -p 8000:8000 \
 -p 8443:8443 \
 -p 8001:8001 \
 -p 8444:8444 \
 -v /root/kong/custom-auth:/usr/local/share/lua/5.1/kong/plugins/custom-auth \
 -v /etc/localtime:/etc/localtime:ro \
 kong:latest
 
 
  docker run -d --name kong \
 --network=kong-net \
 -e "KONG_DATABASE=postgres" \
 -e "KONG_PG_HOST=kong-database" \
 -e "KONG_PG_PASSWORD=kong" \
 -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
 -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
 -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
 -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
 -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
 -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
 -e "KONG_PLUGIN=bundled,custom-auth" \
 -p 8000:8000 \
 -p 8443:8443 \
 -p 8001:8001 \
 -p 8444:8444 \
 -v /root/kong/custom-auth:/usr/local/share/lua/5.1/kong/plugins/custom-auth \
 -v /etc/localtime:/etc/localtime:ro \
 -v /root/kong/constants.lua:/usr/local/share/lua/5.1/kong/constants.lua \
 kong:latest
```



检查Kong Admin 是否联通：

```bash
curl -i http://192.168.3.195:8001/
```



### Kong 管理 UI:

```bash
# 存储
docker volume create konga-postgresql

# 数据库
docker run -d --name konga-database  \
	 --network=kong-net  \
                    -p 5433:5432 \
                    -v  konga-postgresql:/var/lib/postgresql/data  \
                    -e "POSTGRES_USER=konga"  \
                    -e "POSTGRES_DB=konga" \
                    -e "POSTGRES_PASSWORD=konga"  \
                    postgres:9.6
                    
# 初始化
docker run --rm  \
     --network=kong-net  \
     pantsel/konga:latest -c prepare -a postgres -u postgres://konga:konga@konga-database:5432/konga
     
# 启动     
docker run -d -p 1337:1337  \
               --network kong-net  \
               -e "DB_ADAPTER=postgres"  \
               -e "DB_URI=postgres://konga:konga@konga-database:5432/konga"  \
               -e "NODE_ENV=production"  \
               -e "DB_PASSWORD=konga" \
               --name konga \
               pantsel/konga
```



访问控制台：http://192.168.3.195:1337/

在 dashboard 面板里新增链接，Kong 的管理 api 路径 `http://192.168.3.195:8001`







## Environment variables

These are the general environment variables Konga uses.



| VAR                                   | DESCRIPTION                                                  | VALUES                                | DEFAULT                                      |
| ------------------------------------- | ------------------------------------------------------------ | ------------------------------------- | -------------------------------------------- |
| HOST                                  | The IP address that will be bind by Konga's server           | -                                     | '0.0.0.0'                                    |
| PORT                                  | The port that will be used by Konga's server                 | -                                     | 1337                                         |
| NODE_ENV                              | The environment                                              | `production`,`development`            | `development`                                |
| SSL_KEY_PATH                          | If you want to use SSL, this will be the absolute path to the .key file. Both `SSL_KEY_PATH` & `SSL_CRT_PATH` must be set. | -                                     | null                                         |
| SSL_CRT_PATH                          | If you want to use SSL, this will be the absolute path to the .crt file. Both `SSL_KEY_PATH` & `SSL_CRT_PATH` must be set. | -                                     | null                                         |
| KONGA_HOOK_TIMEOUT                    | The time in ms that Konga will wait for startup tasks to finish before exiting the process. | -                                     | 60000                                        |
| DB_ADAPTER                            | The database that Konga will use. If not set, the localDisk db will be used. | `mongo`,`mysql`,`postgres`            | -                                            |
| DB_URI                                | The full db connection string. Depends on `DB_ADAPTER`. If this is set, no other DB related var is needed. | -                                     | -                                            |
| DB_HOST                               | If `DB_URI` is not specified, this is the database host. Depends on `DB_ADAPTER`. | -                                     | localhost                                    |
| DB_PORT                               | If `DB_URI` is not specified, this is the database port. Depends on `DB_ADAPTER`. | -                                     | DB default.                                  |
| DB_USER                               | If `DB_URI` is not specified, this is the database user. Depends on `DB_ADAPTER`. | -                                     | -                                            |
| DB_PASSWORD                           | If `DB_URI` is not specified, this is the database user's password. Depends on `DB_ADAPTER`. | -                                     | -                                            |
| DB_DATABASE                           | If `DB_URI` is not specified, this is the name of Konga's db. Depends on `DB_ADAPTER`. | -                                     | `konga_database`                             |
| DB_PG_SCHEMA                          | If using postgres as a database, this is the schema that will be used. | -                                     | `public`                                     |
| KONGA_LOG_LEVEL                       | The logging level                                            | `silly`,`debug`,`info`,`warn`,`error` | `debug` on dev environment & `warn` on prod. |
| TOKEN_SECRET                          | The secret that will be used to sign JWT tokens issued by Konga | -                                     | -                                            |
| NO_AUTH                               | Run Konga without Authentication                             | true/false                            | -                                            |
| BASE_URL                              | Define a base URL or relative path that Konga will be loaded from. Ex: [www.example.com/konga](http://www.example.com/konga) |                                       | -                                            |
| KONGA_SEED_USER_DATA_SOURCE_FILE      | Seed default users on first run. [Docs](https://github.com/pantsel/konga/blob/master/docs/SEED_DEFAULT_DATA.md). |                                       | -                                            |
| KONGA_SEED_KONG_NODE_DATA_SOURCE_FILE | Seed default Kong Admin API connections on first run [Docs](https://github.com/pantsel/konga/blob/master/docs/SEED_DEFAULT_DATA.md) |                                       |                                              |



```bash
# 创建 upstream
curl -X POST http://127.0.0.1:8001/upstreams --data "name=lap-upstream"

# 创建 target
curl -X POST http://127.0.0.1:8001/upstreams/lap-upstream/targets --data "target=192.168.3.187:8080" --data "weight=100"

# 创建 service
curl -X POST http://127.0.0.1:8001/services --data "name=lap" --data "host=lap-upstream" --data "path=/lap"

# 创建 route
curl -X POST http://localhost:8001/services/lap/routes --data "name=lap-route" --data "paths[]=/lap"
```





测试

```yaml
version: '3'

services:

  kong-database:
    image: postgres:9.6
    container_name: kong-database
    ports:
      - 5432:5432
    environment:
      - POSTGRES_USER=kong
      - POSTGRES_DB=kong
      - POSTGRES_PASSWORD=kong
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - "db-data-kong-postgres:/var/lib/postgresql/data"

  kong-migrations:
    image: kong
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
      - KONG_PG_PASSWORD=kong
      - KONG_CASSANDRA_CONTACT_POINTS=kong-database
    command: kong migrations bootstrap
    restart: on-failure
    depends_on:
      - kong-database

  kong:
    image: kong:3.3.0
    container_name: kong
    environment:
      - LC_CTYPE=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
      - KONG_PG_USER=kong
      - KONG_PG_PASSWORD=kong
      - KONG_CASSANDRA_CONTACT_POINTS=kong-database
      - KONG_PROXY_ACCESS_LOG=/dev/stdout
      - KONG_ADMIN_ACCESS_LOG=/dev/stdout
      - KONG_PROXY_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl
      - KONG_PLUGIN=bundled,custom-auth
    restart: on-failure
    ports:
      - 8000:8000
      - 8443:8443
      - 8001:8001
      - 8444:8444
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./custom-auth:/usr/local/share/lua/5.1/kong/plugins/custom-auth
      - ./constants.lua:/usr/local/share/lua/5.1/kong/constants.lua
    links:
      - kong-database:kong-database
    depends_on:
      - kong-migrations

  konga:
    image: pantsel/konga:0.14.9
    ports:
      - 1337:1337
    links:
      - kong:kong
    container_name: konga
    environment:
      - NODE_ENV=production

volumes:
  db-data-kong-postgres:

networks:
  default:
    name: kong-net
```





嵌入第三方页面：

如果你想在你的网站上嵌入第三方页面登录功能，一般有以下几种方式：

1. OAuth认证：你可以使用OAuth认证协议，让用户通过第三方网站登录你的网站。这种方式需要你的网站支持OAuth认证协议，并且需要你申请第三方网站的OAuth授权。用户在第三方网站上授权后，就可以在你的网站上登录。
2. 嵌入iframe：你可以使用iframe标签将第三方网站的登录界面嵌入到你的网站中。这种方式需要你获得第三方网站的授权，并且需要注意安全问题。因为如果第三方网站的登录界面有漏洞，可能会导致你的网站受到攻击。
3. 跳转到第三方网站：你可以在你的网站中设置一个链接，让用户点击后跳转到第三方网站的登录界面。用户在第三方网站上登录后，可以跳转回你的网站。这种方式比较简单，但是用户体验可能不太好，因为需要跳转到另一个页面。

总之，如果你想在你的网站上嵌入第三方页面登录功能，需要考虑到安全性、用户体验等因素，并根据具体情况选择合适的方式实现。



