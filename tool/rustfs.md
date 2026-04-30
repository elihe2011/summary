# 1. docker-compose

```bash
wget https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64 -O /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```



# 2. minio (单节点)

```bash
# 数据目录
mkdir -p /opt/minio/{data,config}
chmod 755 /opt/minio/data

# 启动配置
cat > /opt/minio/docker-compose.yml <<EOF
networks:
  minio-network:
    driver: bridge

services:
  minio:
    image: quay.io/minio/minio:RELEASE.2022-09-25T15-44-53Z
    container_name: minio
    restart: always
    command: server --console-address ":9090" /data
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
      TZ: Asia/Shanghai
    volumes:
      - /data/minio/data:/data
      - /data/minio/config:/root/.minio
    ports:
      - "19000:9000"
      - "19090:9090"
    networks:
      - minio-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
EOF

# 启动服务
docker-compose up -d
```

访问地址：http://192.168.3.112:19090



# 3. rustfs (单节点)

```bash
# 数据目录
mkdir -p /opt/rustfs/{data,logs}
chmod 777 /opt/rustfs/data

# 启动配置
cat > /opt/rustfs/docker-compose.yml <<EOF
networks:
  rustfs-network:
    driver: bridge

services:
  rustfs:
    security_opt:
      - "no-new-privileges:true"
    image: rustfs/rustfs:latest
    container_name: rustfs
    ports:
      - "29000:9000"
      - "29001:9001"
    environment:
      - RUSTFS_VOLUMES=/data
      - RUSTFS_ADDRESS=0.0.0.0:9000
      - RUSTFS_CONSOLE_ADDRESS=0.0.0.0:9001
      - RUSTFS_CONSOLE_ENABLE=true
      - RUSTFS_EXTERNAL_ADDRESS=:9000  # Same as internal since no port mapping
      - RUSTFS_CORS_ALLOWED_ORIGINS=*
      - RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS=*
      - RUSTFS_ACCESS_KEY=rustfsadmin
      - RUSTFS_SECRET_KEY=rustfsadmin
      - RUSTFS_LOG_LEVEL=info
    volumes:
      - ./data:/data
      - ./logs:/app/logs
    networks:
      - rustfs-network
    restart: unless-stopped
    healthcheck:
      test:
        [
          "CMD",
          "sh", "-c",
          "curl -f http://localhost:9000/health && curl -f http://localhost:9001/health"
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# 启动服务
docker-compose up -d
```

访问地址：http://192.168.3.112:29001





# 4. kong

```bash
mkdir -p /opt/kong/plugins/{auth-plugin,log-plugin}

cat > /opt/kong/docker-compose.yml <<EOF
version: '3'

services:
  kong-database:
    image: postgres:9.6
    container_name: kong-database
    ports:
      - 15432:5432
    environment:
      - POSTGRES_USER=kong
      - POSTGRES_DB=kong
      - POSTGRES_PASSWORD=kong
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - db-data-kong-postgres:/var/lib/postgresql/data
    networks:
      - kong-net

  kong-migrations:
    image: kong:3.9.1
    container_name: kong-migrations
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
      - KONG_PG_PASSWORD=kong
      - KONG_CASSANDRA_CONTACT_POINTS=kong-database
    command: kong migrations bootstrap
    restart: on-failure
    depends_on:
      - kong-database
    networks:
      - kong-net

  kong:
    image: kong:3.9.1
    container_name: kong
    environment:
      - LC_CTYPE=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - LANG=en_US.UTF-8
      - LANGUAGE=en_US.UTF-8
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
      - KONG_PLUGINS=bundled,auth-log
      - KONG_PLUGINSERVER_NAMES=auth-log
      - KONG_PLUGINSERVER_AUTH_LOG_START_CMD=/usr/local/bin/auth-log
      - KONG_PLUGINSERVER_AUTH_LOG_QUERY_CMD="/usr/local/bin/auth-log -dump"
    restart: on-failure
    ports:
      - 8000:8000
      - 8443:8443
      - 8001:8001
      - 8444:8444
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./plugins/auth-log:/usr/local/bin/auth-log:ro
    networks:
      - kong-net
    links:
      - kong-database:kong-database
    depends_on:
      - kong-migrations

  konga:
    image: pantsel/konga:0.14.9
    ports:
      - 1337:1337
    container_name: konga
    environment:
      - NODE_ENV=production
    links:
      - kong:kong
    networks:
      - kong-net

volumes:
  db-data-kong-postgres:

networks:
  kong-net:
    driver: bridge
EOF
```





```bash
mkdir -p /opt/kong-gateway/plugins

cat > /opt/kong-gateway/docker-compose.yml <<EOF
version: '3'

services:
  kong-database:
    image: postgres:9.6
    container_name: kong-database
    ports:
      - 15432:5432
    environment:
      - POSTGRES_USER=kong
      - POSTGRES_DB=kong
      - POSTGRES_PASSWORD=kong
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - db-data-kong:/var/lib/postgresql/data
    networks:
      - kong-net

  kong-migrations:
    image: kong/kong-gateway:3.10
    container_name: kong-migrations
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
      - KONG_PG_PASSWORD=kong
      - KONG_CASSANDRA_CONTACT_POINTS=kong-database
    command: kong migrations bootstrap
    restart: on-failure
    depends_on:
      - kong-database
    networks:
      - kong-net

  kong:
    image: kong/kong-gateway:3.10
    container_name: kong
    environment:
      - LC_CTYPE=en_US.UTF-8
      - LC_ALL=en_US.UTF-8
      - LANG=en_US.UTF-8
      - LANGUAGE=en_US.UTF-8
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
      - KONG_PLUGINS=bundled,iam-auth-log
      - KONG_PLUGINSERVER_NAMES=iam-auth-log
      - KONG_PLUGINSERVER_AUTH_LOG_START_CMD=/usr/local/bin/iam-auth-log
      - KONG_PLUGINSERVER_AUTH_LOG_QUERY_CMD="/usr/local/bin/iam-auth-log -dump"
    restart: on-failure
    ports:
      - 8000:8000
      - 8443:8443
      - 8001:8001
      - 8444:8444
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./plugins/iam-auth-log:/usr/local/bin/iam-auth-log:ro
    networks:
      - kong-net
    links:
      - kong-database:kong-database
    depends_on:
      - kong-migrations

  konga:
    image: pantsel/konga:0.14.9
    ports:
      - 1337:1337
    container_name: konga
    environment:
      - NODE_ENV=production
    links:
      - kong:kong
    networks:
      - kong-net

volumes:
  db-data-kong:

networks:
  kong-net:
    driver: bridge
EOF
```



```bash
docker run --rm -it \
  -e KONG_DATABASE=postgres \
  -e KONG_PG_HOST=kong-database \
  -e KONG_PG_USER=kong \
  -e KONG_PG_PASSWORD=kong \
  -e KONG_CASSANDRA_CONTACT_POINTS=kong-database \
  --network=kong_kong-net --privileged \
   kong:3.3.0 sh
   
   

docker run --rm -it \
  -e KONG_DATABASE=postgres \
  -e KONG_PG_HOST=kong-database \
  -e KONG_PG_USER=kong \
  -e KONG_PG_PASSWORD=kong \
  -e KONG_CASSANDRA_CONTACT_POINTS=kong-database \
  -e KONG_ADMIN_LISTEN="0.0.0.0:8001, 0.0.0.0:8444 ssl" \
  -e KONG_PLUGINS=bundled,auth-log \
  -e KONG_PLUGINSERVER_NAMES=auth-log \
  -e KONG_PLUGINSERVER_AUTH_LOG_START_CMD=/usr/local/bin/auth-log \
  -e KONG_PLUGINSERVER_AUTH_LOG_QUERY_CMD="/usr/local/bin/auth-log -dump" \
  -v /opt/kong/plugins/auth-log:/usr/local/bin/auth-log:ro \
  --network=kong_kong-net --privileged \
   kong:3.9.1 sh
   
   
   

curl -X GET http://192.168.3.105:8001/upstreams



curl -X POST http://192.168.3.105:8001/upstreams --data "name=test"
curl -X POST http://192.168.3.105:8001/upstreams/test/targets --data "target=192.168.3.3:9090" --data "weight=100"
curl -X POST http://192.168.3.105:8001/services --data "name=test" --data "host=test"
curl -X POST http://192.168.3.105:8001/services/lap/routes --data "name=lap" --data 'strip_path=false' --data "paths[]=/lap"
curl -X POST http://192.168.3.105:8001/routes/lap/plugins --data 'name=custom-auth' --data 'config.introspection_endpoint=http://iam-svc:8888/xauth'
curl -X POST http://192.168.3.105:8001/routes/lap/plugins --data 'name=custom-log' --data 'config.http_endpoint=http://iam-svc:8888/xlog'
```

