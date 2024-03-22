# 1. 简介

## 1.1 重要概念

- **服务(Services)**：后端的API或应用程序，它们提供了一组相关的功能和端点，供客户端访问和使用。

- **路由(Routes)**：定义了客户端如何访问服务，包括URL路径、HTTP方法、请求头等信息。路由将客户端的请求映射到相应的服务。

- **上游(Upstreams)**：表示API、应用程序或微服务。Kong网关将请求发送到上游，以实现负载均衡、健康检查和断路器等功能。

- **插件(Plugins)**：Kong 网关的扩展功能，用于添加额外的功能。插件可以修改请求、添加安全性、实现身份验证等功能。

- **消费者群组(Consumer Groups)**：一组相关的消费者，共享相关的访问权限和配额。群组是一种组织和管理消费者的方式。



## 1.2 服务与路由

服务定义了后端API或应用程序，而路由定义了客户端访问服务的方式。

在 Kong网关中，一个服务可以配置多个路由，每个路由对应一个URL路径和其他请求信息。



## 1.3 上游与服务

上游时网关和后端服务之间的中间件层。上游可以管理多个后端服务，并提供负载均衡、健康检查和断路器等功能。

通过将服务与上游关联，Kong网关可以在多个后端服务之间分发请求，并确保可靠性和性能。这种灵活性使得网关能够适应不同的负载和流量需求。



## 1.4 插件

插件提供网关自身外的高级功能，包括请求过滤、响应转换、认证和授权等。

**插件可以配置在不同的实体上，如消费者、路由和服务。**

在同一个实体上配置多个插件，Kong将按它们的配置顺序依次执行。



# 2. 插件开发

## 2.1 Kong 代码

Kong 核心代码结构

```
kong/
├── api/
├── cluster_events/
├── cmd/
├── core/
├── dao/
├── plugins/
├── templates/
├── tools/
├── vendor/
│
├── cache.lua
├── cluster_events.lua
├── conf_loader.lua
├── constants.lua
├── init.lua
├── meta.lua
├── mlcache.lua
└── singletons.lua
```

执行 `kong start` 启动后，Kong 会解析配置文件并保存在 `$prefix/.kong_env`，同时生成 `$prefix/nginx.conf`，`$prefix/nginx-kong.conf` 供 OpenResty 使用。这三个文件，每次Kong重启均会被覆盖。

自定义 OpenResty 配置，需要自己准备配置模板，然后启动时调用：`kong start -c kong.conf --nginx-conf custom_nginx.template` 即可。



在 `nginx-kong.conf` 包含了 Kong 的 Lua 代码加载逻辑：

```nginx
init_by_lua_block {
    kong = require 'kong'
    kong.init()
}
init_worker_by_lua_block {
    kong.init_worker()
}

upstream kong_upstream {
    server 0.0.0.1;
    balancer_by_lua_block {
        kong.balancer()
    }
    keepalive 60;
}

# ...

location / {
    rewrite_by_lua_block {
        kong.rewrite()
    }
    access_by_lua_block {
        kong.access()
    }

    header_filter_by_lua_block {
        kong.header_filter()
    }
    body_filter_by_lua_block {
        kong.body_filter()
    }
    log_by_lua_block {
        kong.log()
    }
}
```

Kong 的入库模块 `kong/init.lua`

```lua
local Kong = {}

function Kong.init()
  -- ...
end

function Kong.init_worker()
  -- ...
end

function Kong.rewrite()
  -- ...
end

function Kong.access()
  -- ...
end

function Kong.header_filter()
  -- ...
end

function Kong.log()
  -- ...
end

-- ...
```



## 2.2 钩子函数

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kong/kong-phase.png) 

| 函数名           | LUA-NGINX-MODULE Context | 描述                                                         |
| ---------------- | ------------------------ | ------------------------------------------------------------ |
| :init_worker()   | init_worker_by_lua       | 在每个 Nginx 工作进程启动时执行                              |
| :certificate()   | ssl_certificate_by_lua   | 在SSL握手阶段的SSL证书服务阶段执行                           |
| :rewrite()       | rewrite_by_lua           | 从客户端接收作为重写阶段处理程序的每个请求执行。在这个阶段，无论是API还是消费者都没有被识别，因此这个处理器只在插件被配置为全局插件时执行 |
| :access()        | access_by_lua            | 为客户的每一个请求而执行，并在它被代理到上游服务之前执行（路由） |
| :header_filter() | header_filter_by_lua     | 从上游服务接收到所有响应头字节时执行                         |
| :body_filter()   | body_filter_by_lua       | 从上游服务接收的响应体的每个块时执行。由于响应流回客户端，它可以超过缓冲区大小，因此，如果响应较大，该方法可以被多次调用 |
| :log()           | log_by_lua               | 当最后一个响应字节已经发送到客户端时执行                     |
|                  |                          |                                                              |



## 2.3 工具类

| PDK名称                                                      | 功能描述 |
| ------------------------------------------------------------ | -------- |
| kong.client	              |提供客户端的ip, 端口等信息          |
| kong.ctx	         |  提供了插件之间共享并传递参数的桥梁         |
| kong.ip	 |  提供了kong.ip.is_trusted(address)IP白名单检测方法        |
| kong.log	                            |   日志方法            |
| kong.node	                     |   返回此插件的UUID信息         |
| kong.request	 |    仅提供request信息的读取功能,access()中可读      |
| kong.response	 |     提供response信息的读写功能, access()中不可用     |
| kong.router	               |  返回此请求关联的router信息       |
| kong.service	 |   返回此请求关联的service,可以动态修改后端服务信息      |
| kong.service.request	|  仅用于access()方法中,可以读写请求信息       |
| kong.service.response	 |   仅可用于header_filter(), body_filter()方法中,只提供header信息的读取功能       |
| kong.table	          |   kong提供的一套数据结构功能                  |



## 2.4 插件结构

```
complete-plugin
├── api.lua
├── daos.lua
├── handler.lua
├── migrations
│   ├── cassandra.lua
│   └── postgres.lua
└── schema.lua
```

各个模块功能如下：

| Module name      | Required | Description                                                  |
| :--------------- | :------- | :----------------------------------------------------------- |
| api.lua          | No       | 插件需要向 Admin API 暴露接口时使用                          |
| daos.lua         | No       | 数据层相关，当插件需要访问数据库时配置                       |
| handler.lua      | Yes      | 插件的主要逻辑，这个将会被 Kong 在不同阶段执行其对应的 handler |
| migrations/*.lua | No       | 插件依赖的数据表结构，启用了 daos.lua 时需要定义             |
| schema.lua       | Yes      | 插件的配置参数定义，主要用于 Kong 参数验证                   |



### 2.4.1 鉴权插件

 `schema.lua`: 定义参数等

```lua
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "custom-auth",
  fields = {
  { protocols = typedefs.protocols_http },
  { consumer = typedefs.no_consumer },
  { config = {
    type = "record",
    fields = {
      { introspection_endpoint = typedefs.url({ required = true }) },
      { token_header = typedefs.header_name { default = "Authorization", required = true }, }
    }, 
    }, 
  },
  },
}
```



`handler.lua`: 核心处理逻辑

```lua
local http = require "resty.http"
local utils = require "kong.tools.utils"
local cjson = require "cjson"

local AuthHandler = {
  VERSION = "1.0",
  PRIORITY = 1000,
}

local function check_access_token(conf, access_token, request_path, request_method)
  local httpc = http:new()
  
  -- validate the token & the user access rights
  local res, err = httpc:request_uri(conf.introspection_endpoint, {
    method = "POST",
    ssl_verify = false,
    body = '{ "path":"' .. request_path .. '", "method":"' .. request_method ..'"}',
    headers = { ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. access_token }
  })

  if not res then
    kong.log.err("failed to call IAM endpoint")
    kong.response.exit(500, "failed to call IAM server")
    return
  end

  -- http status
  if res.status >= 400 then
    kong.log.err("IAM server return error status: ", res.status)
    kong.response.exit(res.status, res.body, {["Content-Type"] = "application/json"})
    return
  end

  -- parse body 
  local data = cjson.decode(res.body)

  -- service error code
  if data.code ~= 0 then
    kong.log.err("IAM server return service error code: ", data.code)
    kong.response.exit(200, data, {["Content-Type"] = "application/json"})
    return
  end
  
  -- ok, pass away
  local user_id = res.headers["X-User-Id"]
  kong.service.request.set_header("X-User-Id", user_id)

  return true
end

function AuthHandler:access(conf)
  local access_token = kong.request.get_headers()[conf.token_header]
  if not access_token then
    kong.response.exit(401, "token not found in header")  --unauthorized
  end
  
  -- replace Bearer prefix
  access_token = access_token:sub(8,-1) -- drop "Bearer "
  local request_path = kong.request.get_path()
  local request_method = kong.request.get_method()
  
  check_access_token(conf, access_token, request_path, request_method)
end

return AuthHandler
```



### 2.4.2 日志插件

 `schema.lua`: 定义参数等

```lua
local typedefs = require "kong.db.schema.typedefs"

return {
  name = "custom-log",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { http_endpoint = typedefs.url({ required = true }) },
          { token_header = typedefs.header_name { default = "Authorization", required = true }, },
          { timeout = { type = "number", default = 10000 }, },
          { keepalive = { type = "number", default = 60000 }, },
          { retry_count = { type = "integer", default = 10 }, },
          { queue_size = { type = "integer", default = 1 }, },
          { flush_timeout = { type = "number", default = 2 }, }
    }, }, },
  },
}
```



`handler.lua`: 核心处理逻辑

```lua
local cjson = require "cjson"
local http = require "resty.http"
local Queue = require "kong.tools.queue"

local LogHandler = {
  VERSION = "1.0",
  PRIORITY = 1000,
}

local function do_ops_log(conf, payload)
  local httpc = http.new()
  local res, err = httpc:request_uri(conf.http_endpoint, {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
    },
    ssl_verify = false,
    body = payload,
  })
  
  if not res then
    kong.log.err("failed to call IAM endpoint to record ops-log")
    return
  end

  return true
end

function LogHandler:access(conf)
  local access_token = kong.request.get_headers()[conf.token_header]
  if not access_token then
    kong.response.exit(401, "token not found in header")  --unauthorized
  end

  local request_body = ""
  local content_type = kong.request.get_headers()["Content-Type"]
  if content_type == "application/json" then
    request_body = kong.request.get_body()
  end

  -- request cache
  local ctx = kong.ctx.plugin
  ctx.start_time = ngx.now() * 1000
  ctx.access_token =  access_token
  ctx.user_agent = kong.request.get_headers()["User-Agent"]
  ctx.client_ip = kong.request.get_headers()["X-Forwarded-For"]
  ctx.uri = kong.request.get_path()
  ctx.method = kong.request.get_method()

  ctx.request_body = request_body
end

function LogHandler:body_filter(conf)
  -- response cache
  local ctx = kong.ctx.plugin
  ctx.end_time = ngx.now() * 1000
  
  local code = 0
  local status = kong.service.response.get_status()
  if (status == nil or status >= 400) then
    code = 1
  end
  ctx.code = code
end

local function json_array_concat(entries)
  return "[" .. table.concat(entries, ",") .. "]"
end

local function get_queue_id(conf)
  return string.format("%s:%s:%s:%s:%s:%s",
    conf.http_endpoint,
    conf.timeout,
    conf.keepalive,
    conf.retry_count,
    conf.queue_size,
    conf.flush_timeout)
end

function LogHandler:log(conf)
  local ctx = kong.ctx.plugin

  if (ctx.method ~= "POST" and ctx.method ~= "PUT" and ctx.method ~= "DELETE") then
    kong.log.warn("skip method ", ctx.method)
    return
  end

  local body = {
    token = ctx.access_token,
    time_cost = ctx.end_time - ctx.start_time,
    user_agent = ctx.user_agent,
    client_ip = ctx.client_ip,
    uri = ctx.uri,
    method = ctx.method,
    code = ctx.code,
    req_body = ctx.request_body
  }
  
  local entry = cjson.encode(body)
  
  local process = function(conf, entries)
    local payload = #entries == 1 and entries[1] or json_array_concat(entries)
    return do_ops_log(conf, payload)
  end
  
  local queue_id = get_queue_id(conf)
  local queue_conf = {
    name = "custome-log",
    log_tag = "custome-log",
    max_batch_size = 10,
    max_coalescing_delay = 1,
    max_entries = 10000,
    max_bytes = 1000000,
    initial_retry_delay = 0.01,
    max_retry_time = 60,
    max_retry_delay = 60,
  }

  local batch_max_size = conf.queue_size or 1
  local opts = {
    retry_count = conf.retry_count,
    flush_timeout = conf.flush_timeout,
    batch_max_size = batch_max_size,
    process_delay = 0,
  }

  local ok, err = Queue.enqueue(
    queue_conf,
    process,
    conf,
    entry
  )
  if not ok then
    kong.log.err("failed to enqueue log entry to log server: ", err)
  end
end

return LogHandler
```



# 3. 部署网关

## 3.1 安装

docker-compose.yaml

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
      - db-data-kong-postgres:/var/lib/postgresql/data

  kong-migrations:
    image: kong:3.3.0
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
      - KONG_PLUGINS=bundled,custom-auth,custom-log
    restart: on-failure
    ports:
      - 8000:8000
      - 8443:8443
      - 8001:8001
      - 8444:8444
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./custom-auth:/usr/local/share/lua/5.1/kong/plugins/custom-auth
      - ./custom-log:/usr/local/share/lua/5.1/kong/plugins/custom-log
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



检查Kong Admin 是否联通：

```bash
curl -i http://192.168.3.195:8001/
```

konga 访问控制台：http://192.168.3.195:1337/

在 dashboard 面板里新增链接，Kong 的管理 api 路径 `http://192.168.3.195:8001`



## 3.2 配置

```bash
# 管理IP地址
KONG_ADMIN_IP=$(kubectl get svc -n ops-system | grep kong-svc | awk '{print $3}')

# upstream => backend
curl -X POST http://${KONG_ADMIN_IP}:8001/upstreams --data "name=lap"
curl -X POST http://${KONG_ADMIN_IP}:8001/upstreams/lap/targets --data "target=lap-svc:8889" --data "weight=100"

# service => upstream (host=lap)
curl -X POST http://${KONG_ADMIN_IP}:8001/services --data "name=lap" --data "host=lap"

# route => service (services/lap/routes)
curl -X POST http://${KONG_ADMIN_IP}:8001/services/lap/routes --data "name=lap" --data 'strip_path=false' --data "paths[]=/lap"

# plugin => route
curl -X POST http://${KONG_ADMIN_IP}:8001/routes/lap/plugins --data 'name=custom-auth' --data 'config.introspection_endpoint=http://iam-svc:8888/xauth'
curl -X POST http://${KONG_ADMIN_IP}:8001/routes/lap/plugins --data 'name=custom-log' --data 'config.http_endpoint=http://iam-svc:8888/xlog'

# plugin => service
curl -X POST http://${KONG_ADMIN_IP}:8001/services/lap/plugins --data 'name=cors' --data 'config.max_age=86400' --data 'config.methods=["GET","HEAD","PUT","POST","DELETE"]' --data 'config.credentials=true'
```











