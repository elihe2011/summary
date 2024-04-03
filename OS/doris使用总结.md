# 1. 安装

## 1.1 准备操作

```bash
# 修改系统参数
vi /etc/sysctl.conf
vm.max_map_count=2000000

sysctl -p

# 创建相关目录
mkdir -p /data/fe/doris-meta
mkdir -p /data/fe/log
mkdir -p /data/be/storage
mkdir -p /data/be/script
```



## 1.2 docker-compse 配置

192.168.3.103 为宿主机IP地址

```yaml
version: "3"
services:
  fe:
    image: apache/doris:2.0.0_alpha-fe-x86_64
    hostname: fe
    environment:
     - FE_SERVERS=fe1:192.168.3.103:9010
     - FE_ID=1
    volumes:
     - /data/fe/doris-meta/:/opt/apache-doris/fe/doris-meta/
     - /data/fe/log/:/opt/apache-doris/fe/log/
    network_mode: host
  be:
    image: apache/doris:2.0.0_alpha-be-x86_64
    hostname: be
    environment:
     - FE_SERVERS=fe1:192.168.3.103:9010
     - BE_ADDR=192.168.3.103:9050
    volumes:
     - /data/be/storage/:/opt/apache-doris/be/storage/
     - /data/be/script/:/docker-entrypoint-initdb.d/
    depends_on:
      - fe
    network_mode: host
```



## 1.3 启动并验证

```bash
docker-compose up -d

docker-compose ps
   Name            Command         State   Ports
------------------------------------------------
doris_be_1   bash entry_point.sh   Up
doris_fe_1   bash init_fe.sh       Up
```

管理用户：root，密码默认为空

页面登录地址：http://192.168.3.103:8030/ 

通过MySQL客户登录：

```bash
apt install mysql-client

mysql -uroot -P9030 -h127.0.0.1
mysql> SHOW BACKENDS\G
*************************** 1. row ***************************
              BackendId: 10003
                Cluster: default_cluster
                     IP: 192.168.3.103
               HostName: 192.168.3.103
          HeartbeatPort: 9050
                 BePort: 9060
               HttpPort: 8040
               BrpcPort: 8060
          LastStartTime: 2023-11-29 06:01:48
          LastHeartbeat: 2023-11-29 06:13:41
                  Alive: true
   SystemDecommissioned: false
  ClusterDecommissioned: false
              TabletNum: 21
       DataUsedCapacity: 0.000
          AvailCapacity: 71.468 GB
          TotalCapacity: 97.928 GB
                UsedPct: 27.02 %
         MaxDiskUsedPct: 27.02 %
     RemoteUsedCapacity: 0.000
                    Tag: {"location" : "default"}
                 ErrMsg:
                Version: doris-2.0.0-alpha1-Unknown
                 Status: {"lastSuccessReportTabletsTime":"2023-11-29 06:13:24","lastStreamLoadTime":-1,"isQueryDisabled":false,"isLoadDisabled":false}
HeartbeatFailureCounter: 0
               NodeRole: mix
1 row in set (0.03 sec)
```



## 1.4 管理操作

```bash
mysql  -h node1 -P9030 -uroot

mysql> SET PASSWORD FOR 'root' = PASSWORD('your_password');

mysql> CREATE USER 'test' IDENTIFIED BY 'test_passwd';

mysql> CREATE DATABASE test_db;
mysql> show databases;
mysql> GRANT ALL ON test_db TO test;
```





```bash
vi /etc/security/limits.conf 
*   hard    nofile  65536
*   hard    nproc   65536
*   soft    nofile  65536
*   soft    nproc   65536


vi /etc/sysctl.conf
vm.swappiness=0
vm.overcommit_memory=1
vm.zone_reclaim_mode = 0
vm.max_map_count=2000000

sysctl -p
```





安装jdk

```bash
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.tar.gz

tar zxvf jdk-8u131-linux-x64.tar.gz -C /usr/local

vi /etc/profile.d/java.sh
export JAVA_HOME=/usr/local/jdk1.8.0_131
export PATH=$JAVA_HOME/bin:$PATH

source /etc/profile.d/java.sh
java -version
```



安装doris

```bash
wget https://apache-doris-releases.oss-accelerate.aliyuncs.com/apache-doris-2.0.2-bin-x64.tar.gz

tar zxvf apache-doris-2.0.2-bin-x64.tar.gz -C /opt
ln -s /opt/apache-doris-2.0.2-bin-x64 /opt/doris
```



配置 fe:

```bash
mkdir -p /data/fe/doris-meta
mkdir -p /data/be/storage

vi /opt/doris/fe/conf/fe.conf
meta_dir = /data/fe/doris-meta
priority_networks = 192.168.3.104/24


vi /opt/doris/be/conf/be.conf
priority_networks = 192.168.3.104/24
storage_root_path = /data/be/storage


cd /opt/doris/fe
bash bin/start_fe.sh --daemon

curl http://192.168.3.104:8030/api/bootstrap


cd /opt/doris/be
bash bin/start_be.sh --daemon
curl http://192.168.3.104:8040/api/health
```





```bash
apt install mysql-client

mysql -h127.0.0.1 -uroot -P9030

mysql> ALTER SYSTEM ADD FOLLOWER "fe2的ip:9010";

mysql> show proc '/frontends';

mysql> ALTER SYSTEM ADD BACKEND "192.168.3.104:9050";
Query OK, 0 rows affected (0.08 sec)

mysql> show proc '/backends';
```

