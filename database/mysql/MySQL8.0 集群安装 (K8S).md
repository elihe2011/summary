尝试了很多版本的mysql镜像，都存在这样那样的的问题。原始需求中，需要同时支持x86_64(AMD64)和aarch64(ARM64V8)，最后找到Oracle官方出品的MySQL-Server 8.0镜像包，作为基础镜像包，并在其基础上做一些定制。当然还存在一些问题，比如my.cnf通过configmap定制等等，后续慢慢优化补充。



# 1. 构建镜像

## 1.1 重写 `my.cnf`

```ini
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
secure-file-priv=/var/lib/mysql-files
user=mysql
pid-file=/var/run/mysqld/mysqld.pid
gtid_mode=ON
enforce_gtid_consistency=ON
skip-host-cache
skip-name-resolve
authentication_policy=mysql_native_password
binlog_cache_size=1M
binlog_format=row
binlog_expire_logs_seconds=2592000
replica_skip_errors=1062

!includedir /etc/my.cnf.d/
```



## 1.2 重写 `entrypoint.sh`

为避免覆盖原始启动文件，将其复制一份，命名为`docker-entrypoint.sh`

```bash
#!/bin/bash
# Copyright (c) 2017, 2021, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
set -e

echo "[Entrypoint] MySQL Docker Image 8.0.28-1.2.7-server"
# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
    local conf="$1"; shift
    "$@" --verbose --help 2>/dev/null | grep "^$conf" | awk '$1 == "'"$conf"'" { print $2; exit }'
}

# Generate a random password
_mkpw() {
    letter=$(cat /dev/urandom| tr -dc a-zA-Z | dd bs=1 count=16 2> /dev/null )
    number=$(cat /dev/urandom| tr -dc 0-9 | dd bs=1 count=8 2> /dev/null)
    special=$(cat /dev/urandom| tr -dc '=+@#%^&*_.,;:?/' | dd bs=1 count=8 2> /dev/null)

    echo $letter$number$special | fold -w 1 | shuf | tr -d '\n'
}

# If command starts with an option, prepend mysqld
# This allows users to add command-line options without
# needing to specify the "mysqld" command
if [ "${1:0:1}" = '-' ]; then
    set -- mysqld "$@"
fi

# Check if entrypoint (and the container) is running as root
if [ $(id -u) = "0" ]; then
    is_root=1
    install_devnull="install /dev/null -m0600 -omysql -gmysql"
    MYSQLD_USER=mysql
else
    install_devnull="install /dev/null -m0600"
    MYSQLD_USER=$(id -u)
fi

if [ "$1" = 'mysqld' ]; then
    # Test that the server can start. We redirect stdout to /dev/null so
    # only the error messages are left.
    result=0
    output=$("$@" --validate-config) || result=$?
    if [ ! "$result" = "0" ]; then
        echo >&2 '[Entrypoint] ERROR: Unable to start MySQL. Please check your configuration.'
        echo >&2 "[Entrypoint] $output"
        exit 1
    fi

    # Get config
    DATADIR="$(_get_config 'datadir' "$@")"
    SOCKET="$(_get_config 'socket' "$@")"

    if [ ! -d "$DATADIR/mysql" ]; then
        # If the password variable is a filename we use the contents of the file. We
        # read this first to make sure that a proper error is generated for empty files.
        if [ -f "$MYSQL_ROOT_PASSWORD" ]; then
            MYSQL_ROOT_PASSWORD="$(cat $MYSQL_ROOT_PASSWORD)"
            if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
                echo >&2 '[Entrypoint] Empty MYSQL_ROOT_PASSWORD file specified.'
                exit 1
            fi
        fi
        if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
            echo >&2 '[Entrypoint] No password option specified for new database.'
            echo >&2 '[Entrypoint] A random onetime password will be generated.'
            MYSQL_RANDOM_ROOT_PASSWORD=true
            MYSQL_ONETIME_PASSWORD=true
        fi
        if [ ! -d "$DATADIR" ]; then
            mkdir -p "$DATADIR"
            chown mysql:mysql "$DATADIR"
        fi

        #### [BEGIN] mysql-cluster ############################################################################
        set -x
        if [ ! -z "$MYSQL_REPL_USER" ]; then
            if [[ ! $HOSTNAME  =~ -([0-9]+)$ ]]; then
                echo >&2 "[Entrypoint] Invalid mysql cluster hostname [$HOSTNAME]"
                exit 1
            fi

            ordinal=${HOSTNAME: -1}

            # it's a slave node, the master node host is required
            if [ "$ordinal" != "0" -a -z "$MYSQL_MASTER_HOST" ]; then
                echo >&2 "[Entrypoint] No master node host option specified for a slave node: MYSQL_MASTER_HOST"
                exit 1
            fi

            SERVER_ID=$((100 + $ordinal))

            if [ "$ordinal" = "0" ]; then
                cat > /etc/my.cnf.d/server-id.cnf <<EOF
[mysqld]
server-id=$SERVER_ID
EOF
            else
                cat > /etc/my.cnf.d/server-id.cnf <<EOF
[mysqld]
server-id=$SERVER_ID
relay-log=${HOSTNAME}-relay-bin
log_replica_updates=ON
read_only=ON
EOF
            fi
        fi
        set +x
        #### [END] mysql-cluster ##############################################################################

        # The user can set a default_timezone either in a my.cnf file
        # they mount into the container or on command line
        # (`docker run mysql/mysql-server:8.0 --default-time-zone=Europe/Berlin`)
        # however the timezone tables will only be populated in a later
        # stage of this script. By using +00:00 as timezone we override
        # the user's choice during initialization. Later the server
        # will be restarted using the user's option.

        echo '[Entrypoint] Initializing database'
        "$@" --user=$MYSQLD_USER --initialize-insecure  --default-time-zone=+00:00

        echo '[Entrypoint] Database initialized'
        "$@" --user=$MYSQLD_USER --daemonize --skip-networking --socket="$SOCKET" --default-time-zone=+00:00

        # To avoid using password on commandline, put it in a temporary file.
        # The file is only populated when and if the root password is set.
        PASSFILE=$(mktemp -u /var/lib/mysql-files/XXXXXXXXXX)
        $install_devnull "$PASSFILE"
        # Define the client command used throughout the script
        # "SET @@SESSION.SQL_LOG_BIN=0;" is required for products like group replication to work properly
        mysql=( mysql --defaults-extra-file="$PASSFILE" --protocol=socket -uroot -hlocalhost --socket="$SOCKET" --init-command="SET @@SESSION.SQL_LOG_BIN=0;")

        for i in {30..0}; do
            if mysqladmin --socket="$SOCKET" ping &>/dev/null; then
                break
            fi
            echo '[Entrypoint] Waiting for server...'
            sleep 1
        done
        if [ "$i" = 0 ]; then
            echo >&2 '[Entrypoint] Timeout during MySQL init.'
            exit 1
        fi

        mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql

        if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
            MYSQL_ROOT_PASSWORD="$(_mkpw)"
            echo "[Entrypoint] GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
        fi
        if [ -z "$MYSQL_ROOT_HOST" ]; then
            ROOTCREATE="ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
        else
            ROOTCREATE="ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; \
CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; \
GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ; \
GRANT PROXY ON ''@'' TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;"
        fi
        "${mysql[@]}" <<-EOSQL
DELETE FROM mysql.user WHERE user NOT IN ('mysql.infoschema', 'mysql.session', 'mysql.sys', 'root') OR host NOT IN ('localhost');
CREATE USER 'healthchecker'@'localhost' IDENTIFIED BY 'healthcheckpass';
${ROOTCREATE}
FLUSH PRIVILEGES ;
EOSQL
        if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
            # Put the password into the temporary config file
            cat >"$PASSFILE" <<EOF
[client]
password="${MYSQL_ROOT_PASSWORD}"
EOF
            #mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
        fi

        if [ "$MYSQL_DATABASE" ]; then
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
            mysql+=( "$MYSQL_DATABASE" )
        fi

        if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
            echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

            if [ "$MYSQL_DATABASE" ]; then
                echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
            fi

        elif [ "$MYSQL_USER" -a ! "$MYSQL_PASSWORD" -o ! "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
            echo '[Entrypoint] Not creating mysql user. MYSQL_USER and MYSQL_PASSWORD must be specified to create a mysql user.'
        fi
        echo
        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)  echo "[Entrypoint] running $f"; . "$f" ;;
                *.sql) echo "[Entrypoint] running $f"; "${mysql[@]}" < "$f" && echo ;;
                *)     echo "[Entrypoint] ignoring $f" ;;
            esac
            echo
        done

        #### [BEGIN] mysql-cluster ############################################################################
        set -x
        if [ ! -z "$MYSQL_REPL_USER" ]; then
            NODE_ID=${HOSTNAME: -1}
            if [ "${NODE_ID}" = "0" ]; then
                "${mysql[@]}" <<-EOSQL
CREATE USER '$MYSQL_REPL_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPL_PASS' ;
GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPL_USER'@'%' ;
EOSQL
            else
                "${mysql[@]}" <<-EOSQL
CHANGE REPLICATION SOURCE TO SOURCE_HOST='${MYSQL_MASTER_HOST}',SOURCE_PORT=3306,SOURCE_USER='$MYSQL_REPL_USER',SOURCE_PASSWORD='$MYSQL_REPL_PASS',SOURCE_AUTO_POSITION=1 ;
START REPLICA ;
EOSQL
            fi
        fi
        set +x
        #### [END] mysql-cluster ##############################################################################

        # When using a local socket, mysqladmin shutdown will only complete when the server is actually down
        mysqladmin --defaults-extra-file="$PASSFILE" shutdown -uroot --socket="$SOCKET"
        rm -f "$PASSFILE"
        unset PASSFILE
        echo "[Entrypoint] Server shut down"

        # This needs to be done outside the normal init, since mysqladmin shutdown will not work after
        if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
            echo "[Entrypoint] Setting root user as expired. Password will need to be changed before database can be used."
            SQL=$(mktemp -u /var/lib/mysql-files/XXXXXXXXXX)
            $install_devnull "$SQL"
            if [ ! -z "$MYSQL_ROOT_HOST" ]; then
                cat << EOF > "$SQL"
ALTER USER 'root'@'${MYSQL_ROOT_HOST}' PASSWORD EXPIRE;
ALTER USER 'root'@'localhost' PASSWORD EXPIRE;
EOF
            else
                cat << EOF > "$SQL"
ALTER USER 'root'@'localhost' PASSWORD EXPIRE;
EOF
            fi
            set -- "$@" --init-file="$SQL"
            unset SQL
        fi

        echo
        echo '[Entrypoint] MySQL init process done. Ready for start up.'
        echo
    fi

    # Used by healthcheck to make sure it doesn't mistakenly report container
    # healthy during startup
    # Put the password into the temporary config file
    touch /var/lib/mysql-files/healthcheck.cnf
    cat >"/var/lib/mysql-files/healthcheck.cnf" <<EOF
[client]
user=healthchecker
socket=${SOCKET}
password=healthcheckpass
EOF
    touch /var/lib/mysql-files/mysql-init-complete

    if [ -n "$MYSQL_INITIALIZE_ONLY" ]; then
        echo "[Entrypoint] MYSQL_INITIALIZE_ONLY is set, exiting without starting MySQL..."
        exit 0
    else
        echo "[Entrypoint] Starting MySQL 8.0.28-1.2.7-server"
    fi
    # 4th value of /proc/$pid/stat is the ppid, same as getppid()
    export MYSQLD_PARENT_PID=$(cat /proc/$$/stat|cut -d\  -f4)
    exec "$@" --user=$MYSQLD_USER
else
    exec "$@"
fi
```



## 1.3 Dockerfile

```dockerfile
FROM mysql/mysql-server:8.0.28

COPY my.cnf /etc/
COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

WORKDIR /
CMD ["mysqld"]
ENTRYPOINT [ "/docker-entrypoint.sh" ]
```



## 1.4 编译镜像

```bash
docker build -t elihe/mysql-server:8.0.28 .
```



# 2. 集群安装

## 2.1 创建 namespace

```bash
$ mkdir ~/mysql && cd $_

$ cat > mysql-namespace.yml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: mysql-cluster
  labels:
    name: mysql-cluster
EOF

$ kubectl apply -f mysql-namespace.yml
```



## 2.2 创建 **Secret** 

```bash
$ cat > mysql-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: mysql-cluster
  labels:
    app: mysql
type: Opaque
data:
  password: MTIzNDU2 # echo -n '123456' | base64
  repl-user: cmVwbA== # echo -n 'repl' | base64
  repl-pass: MTIzNDU2
EOF

$ kubectl apply -f mysql-secret.yml
```



## 2.3 创建 PV

暂时没有 Ceph 资源，先使用本地磁盘测试

```bash
# 1. 所有节点上，挂载相应的存储盘或路径
$ mkdir -p /data/mysql

# 2. 创建PV
$ cat > mysql-pv.yml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
  namespace: mysql-cluster
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: mysql-storage
  local:
    path: /data/mysql
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-master
          - k8s-node01
          - k8s-node02
EOF

$ kubectl apply -f mysql-pv.yml
```



## 2.4 创建 PVC

```bash
$ cat > mysql-pvc.yml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: mysql-cluster
spec:
  storageClassName: mysql-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

$ kubectl apply -f mysql-pvc.yml
```



## 2.5 创建 Service (无头服务)

```bash
$ cat > mysql-headless-svc.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: mysql-cluster
  labels:
    app: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  clusterIP: None
  selector:
    app: mysql
EOF

$ kubectl apply -f mysql-headless-svc.yml
```



## 2.6 创建 StatefulSet

```bash
$ vi mysql-statefulset.yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: mysql-cluster
spec:
  selector:
    matchLabels:
      app: mysql
  serviceName: mysql
  replicas: 3
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: elihe/mysql-server:8.0.28
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        - name: MYSQL_REPL_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: repl-user
        - name: MYSQL_REPL_PASS
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: repl-pass
        - name: SERVICE_NAME
          value: "mysql"
        - name: STS_NAME
          value: "mysql"
        - name: STS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MYSQL_MASTER_HOST
          value: "$(STS_NAME)-0.$(SERVICE_NAME).$(STS_NAMESPACE)"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - "-c"
            - MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"
            - mysqladmin ping
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - "-c"
            - MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"
            - mysql -h 127.0.0.1 -u root -e "SELECT 1"
          initialDelaySeconds: 60
          periodSeconds: 5
          timeoutSeconds: 2
      volumes:
      - name: conf
        emptyDir: {}
      - name: data
        persistentVolumeClaim:
          claimName: mysql-pvc
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - mysql
              topologyKey: kubernetes.io/hostname
              
              
$ kubectl apply -f mysql-statefulset.yml
```



## 2.7 创建 Service (外部访问)

```bash
$ cat > mysql-service.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  namespace: mysql-cluster
  labels:
    app: mysql
spec:
  type: NodePort
  selector:
    app: mysql
  ports:
  - protocol: TCP
    port: 3306
    targetPort: 3306
    nodePort: 33306
EOF

$ kubectl apply -f mysql-service.yml 
```



# 3. 验证结果

## 3.1 主节点写

```bash
$ kubectl exec -it mysql-0 -n mysql-cluster -- /bin/bash
bash-4.4# mysql -uroot -p123456
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 12
Server version: 8.0.28 MySQL Community Server - GPL

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> create database testdb;
Query OK, 1 row affected (0.11 sec)

mysql> use testdb;
Database changed
mysql> create table emp(id int, name varchar(20));
Query OK, 0 rows affected (0.39 sec)

mysql> insert into emp values(1, 'eli');
Query OK, 1 row affected (0.06 sec)
```



## 3.2 从节点读

```bash
$ kubectl exec -it mysql-2 -n mysql-cluster -- /bin/bash
bash-4.4# mysql -uroot -p123456
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 14
Server version: 8.0.28 MySQL Community Server - GPL

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| testdb             |
+--------------------+
5 rows in set (0.01 sec)

mysql> use testdb;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+------------------+
| Tables_in_testdb |
+------------------+
| emp              |
+------------------+
1 row in set (0.00 sec)

mysql> select * from emp;
+------+------+
| id   | name |
+------+------+
|    1 | eli  |
+------+------+
1 row in set (0.00 sec)
```



# 4. 补充：主从复制

## 4.1 基于二进制日志文件

步骤一：主库配置`my.cnf`

```ini
###主从数据库配置核心部分
[mysqld]
# 设置同步的binary log二进制日志文件名前缀，默认为binlog；在MySQL 8.0中，无论是否指定--log bin选项，默认情况下都会启用二进制日志记录，并将log_bin系统变量设置为ON。
log-bin=mysql-bin
# 服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
server-id=1          

###可选配置
# 需要主从复制的数据库，如多个则重复配置
binlog-do-db=test
# 复制过滤：也就是指定哪个数据库不用同步（mysql库一般不同步），如多个则重复配置
binlog-ignore-db=mysql
# 为每个session分配的内存，在事务过程中用来存储二进制日志的缓存
binlog_cache_size=1M
# 主从复制的格式（mixed,statement,row，默认格式是statement。建议是设置为row，主从复制时数据更加能够统一）
binlog_format=row
# 配置二进制日志自动删除/过期时间，单位秒，默认值为2592000，即30天；8.0.3版本之前使用expire_logs_days，单位天数，默认值为0，表示不自动删除。
binlog_expire_logs_seconds=2592000
# 跳过主从复制中遇到的所有错误或指定类型的错误，避免slave端复制中断，默认OFF关闭，可选值有OFF、all、ddl_exist_errors以及错误码列表。8.0.26版本之前使用slave_skip_errors
# 如：1062错误是指一些主键重复，1032错误是因为主从数据库数据不一致
replica_skip_errors=1062
```



步骤二：主库配置同步用户

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY '123456';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mysql/cluster-binlog-master.png)



步骤三：从库配置`my.cnf`

```ini
###主从数据库配置核心部分
[mysqld]
# 设置同步的binary log二进制日志文件名前缀，默认是binlog
log-bin=mysql-bin
# 服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
server-id=2

###可选配置
# 需要主从复制的数据库 ，如多个则重复配置
replicate-do-db=test
# 复制过滤：也就是指定哪个数据库不用同步（mysql库一般不同步） ，如多个则重复配置
binlog-ignore-db=mysql
# 为每个session分配的内存，在事务过程中用来存储二进制日志的缓存 
binlog_cache_size=1M
# 主从复制的格式（mixed,statement,row，默认格式是statement。建议是设置为row，主从复制时数据更加能够统一） 
binlog_format=row
# 配置二进制日志自动删除/过期时间，单位秒，默认值为2592000，即30天；8.0.3版本之前使用expire_logs_days，单位天数，默认值为0，表示不自动删除。
binlog_expire_logs_seconds=2592000
# 跳过主从复制中遇到的所有错误或指定类型的错误，避免slave端复制中断，默认OFF关闭，可选值有OFF、all、ddl_exist_errors以及错误码列表。8.0.26版本之前使用slave_skip_errors
# 如：1062错误是指一些主键重复，1032错误是因为主从数据库数据不一致
replica_skip_errors=1062
# relay_log配置中继日志，默认采用 主机名-relay-bin 的方式保存日志文件 
relay_log=replicas-mysql-relay-bin  
# log_replica_updates表示slave是否将复制事件写进自己的二进制日志，默认值ON开启；8.0.26版本之前使用log_slave_updates
log_replica_updates=ON
# 防止改变数据(只读操作，除了特殊的线程)
read_only=ON
```



步骤四：从库开启同步

```sql
# 8.0.22-
CHANGE MASTER TO MASTER_HOST='192.168.34.120',MASTER_PORT=3306,MASTER_USER='repl',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000007',MASTER_LOG_POS=825;
START SLAVE;
SHOW SLAVE STATUS;
STOP SLAVE;
RESTART SLAVE;

# 8.0.23+
CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.34.120',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='123456',SOURCE_LOG_FILE='mysql-bin.000007',SOURCE_LOG_POS=825;
START REPLICA;
SHOW REPLICA STATUS;
STOP REPLICA;
RESTART REPLICA;
```

`Slave_IO_Running/Replica_IO_Running`和 `Slave_SQL_Running/Replica_SQL_Running` 为 Yes ，以及`Slave_IO_State/Replica_IO_State` 为 Waiting for master to send event/Waiting for source to send event，说明主从复制成功

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mysql/cluster-binlog-slave.png)



## 4.2 基于全局事务标识符（GTID）

步骤一：主库配置`my.cnf`

```ini
###主从数据库配置核心部分
[mysqld]
# 设置同步的binary log二进制日志文件名前缀，默认为binlog
log-bin=mysql-bin
# 服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
server-id=1     
     
#开启 GTID
gtid_mode=ON
enforce_gtid_consistency=ON

###可选配置
# 需要主从复制的数据库，如多个则重复配置
binlog-do-db=test
# 复制过滤：也就是指定哪个数据库不用同步（mysql库一般不同步），如多个则重复配置
binlog-ignore-db=mysql
# 为每个session分配的内存，在事务过程中用来存储二进制日志的缓存
binlog_cache_size=1M
# 主从复制的格式（mixed,statement,row，默认格式是statement。建议是设置为row，主从复制时数据更加能够统一）
binlog_format=row
# 配置二进制日志自动删除/过期时间，单位秒，默认值为2592000，即30天；8.0.3版本之前使用expire_logs_days，单位天数，默认值为0，表示不自动删除。
binlog_expire_logs_seconds=2592000
# 跳过主从复制中遇到的所有错误或指定类型的错误，避免slave端复制中断，默认OFF关闭，可选值有OFF、all、ddl_exist_errors以及错误码列表。8.0.26版本之前使用slave_skip_errors
# 如：1062错误是指一些主键重复，1032错误是因为主从数据库数据不一致
replica_skip_errors=1062
```



步骤二：主库配置同步用户

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY '123456';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mysql/cluster-gtid-master.png)



步骤三：从库配置`my.cnf`

```ini
###主从数据库配置核心部分
[mysqld]
# 设置同步的binary log二进制日志文件名前缀，默认是binlog
log-bin=mysql-bin
# 服务器唯一id，默认为1，值范围为1～2^32−1. ；主数据库和从数据库的server-id不能重复
server-id=2

#开启 GTID
gtid_mode=ON
enforce_gtid_consistency=ON

###可选配置
# 需要主从复制的数据库 ，如多个则重复配置
replicate-do-db=test
# 复制过滤：也就是指定哪个数据库不用同步（mysql库一般不同步） ，如多个则重复配置
binlog-ignore-db=mysql
# 为每个session分配的内存，在事务过程中用来存储二进制日志的缓存 
binlog_cache_size=1M
# 主从复制的格式（mixed,statement,row，默认格式是statement。建议是设置为row，主从复制时数据更加能够统一） 
binlog_format=row
# 配置二进制日志自动删除/过期时间，单位秒，默认值为2592000，即30天；8.0.3版本之前使用expire_logs_days，单位天数，默认值为0，表示不自动删除。
binlog_expire_logs_seconds=2592000
# 跳过主从复制中遇到的所有错误或指定类型的错误，避免slave端复制中断，默认OFF关闭，可选值有OFF、all、ddl_exist_errors以及错误码列表。8.0.26版本之前使用slave_skip_errors
# 如：1062错误是指一些主键重复，1032错误是因为主从数据库数据不一致
replica_skip_errors=1062
# relay_log配置中继日志，默认采用 主机名-relay-bin 的方式保存日志文件 
relay_log=replicas-mysql-relay-bin
# log_replica_updates表示slave是否将复制事件写进自己的二进制日志，默认值ON开启；8.0.26版本之前使用log_slave_updates
log_replica_updates=ON
# 防止改变数据(只读操作，除了特殊的线程)
read_only=ON
```



步骤四：从库开启同步

```sql
# 8.0.22-
CHANGE MASTER TO MASTER_HOST='192.168.34.120',MASTER_PORT=3306,MASTER_USER='repl',MASTER_PASSWORD='123456',MASTER_LOG_FILE='mysql-bin.000007',MASTER_LOG_POS=825;
START SLAVE;
SHOW SLAVE STATUS;
STOP SLAVE;
RESTART SLAVE;

# 8.0.23+
CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.34.120',SOURCE_PORT=3306,SOURCE_USER='repl',SOURCE_PASSWORD='123456',SOURCE_LOG_FILE='mysql-bin.000007',SOURCE_LOG_POS=825;
START REPLICA;
SHOW REPLICA STATUS;
STOP REPLICA;
RESTART REPLICA;
```

`Slave_IO_Running/Replica_IO_Running`和 `Slave_SQL_Running/Replica_SQL_Running` 为 Yes ，以及`Slave_IO_State/Replica_IO_State` 为 Waiting for master to send event/Waiting for source to send event，说明主从复制成功

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mysql/cluster-gtid-slave.png)



# 5. 补充：集群安装（docker)

```bash
docker run --name master -h mysql-0 -e MYSQL_ROOT_PASSWORD=123456 -e MYSQL_REPL_USER=repl -e MYSQL_REPL_PASS=123456 -v ~/mysql-cluster/master.cnf:/etc/my.cnf.d/mysqld.cnf -d elihe/mysql-server:8.0.28

docker run --name slave1 -h mysql-1 -e MYSQL_ROOT_PASSWORD=123456 -e MYSQL_REPL_USER=repl -e MYSQL_REPL_PASS=123456 -e MYSQL_MASTER_HOST=172.17.0.2 -v ~/mysql-cluster/slave1.cnf:/etc/my.cnf.d/mysqld.cnf -d elihe/mysql-server:8.0.28

docker run --name slave2 -h mysql-2 -e MYSQL_ROOT_PASSWORD=123456 -e MYSQL_REPL_USER=repl -e MYSQL_REPL_PASS=123456 -e MYSQL_MASTER_HOST=172.17.0.2 -v ~/mysql-cluster/slave2.cnf:/etc/my.cnf.d/mysqld.cnf -d elihe/mysql-server:8.0.28
```

