# 1. 安装

## 1.1 Linux

### 1.1.1 源码

https://github.com/taosdata/TDengine

```bash
sudo -i

apt install gcc cmake build-essential git

# 下载源码
wget https://github.com/taosdata/TDengine/archive/refs/tags/ver-2.2.2.0.tar.gz
tar zxvf ver-2.2.2.0.tar.gz
cd TDengine-ver-2.2.2.0/

# connectors for go & grafana，暂时无法成功下载
git submodule update --init --recursive

# 编译
mkdir debug && cd debug

# AMD64
cmake .. && cmake --build .

# ARM64
cmake .. -DCPUTYPE=aarch64 && cmake --build .

# 安装
make install

# 配置文件
cat /etc/taos/taos.cfg

# 启动
systemctl start taosd
systemctl status taosd
● taosd.service - TDengine server service
   Loaded: loaded (/etc/systemd/system/taosd.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2021-09-16 09:32:58 CST; 6s ago
  Process: 19820 ExecStartPre=/usr/local/taos/bin/startPre.sh (code=exited, status=0/SUCCESS)
 Main PID: 19825 (taosd)
    Tasks: 222 (limit: 9830)
   CGroup: /system.slice/taosd.service
           └─19825 /usr/bin/taosd

Sep 16 09:32:58 k8s-master systemd[1]: Starting TDengine server service...
Sep 16 09:32:58 k8s-master systemd[1]: Started TDengine server service.
Sep 16 09:32:58 k8s-master TDengine:[19825]: Starting TDengine service...
Sep 16 09:32:58 k8s-master TDengine:[19825]: Started TDengine service successfully.


tar zcvf TDengine-server-2.2.2.0-aarch64.tar.gz /etc/taos /usr/local/taos /etc/systemd/system/taosd.service

# 安装
tar zxvf TDengine-server-2.2.2.0-aarch64.tar.gz -C /

ln -s /usr/local/taos/bin/taos        /usr/bin/taos
ln -s /usr/local/taos/bin/taosd       /usr/bin/taosd
ln -s /usr/local/taos/bin/taosdump    /usr/bin/taosdump
ln -s /usr/local/taos/bin/taosdemo    /usr/bin/taosdemo
ln -s /usr/local/taos/bin/remove.sh   /usr/bin/rmtaos

ln -s /usr/local/taos/include/taoserror.h  /usr/include/taoserror.h
ln -s /usr/local/taos/include/taos.h  /usr/include/taos.h

ln -s /usr/local/taos/driver/libtaos.so.2.2.2.0  /usr/lib/libtaos.so.1
ln -s /usr/lib/libtaos.so.1 /usr/lib/libtaos.so 

mkdir -p /var/lib/taos
mkdir -p /var/log/taos
chmod 777 /var/log/taos

systemctl enable taosd
systemctl start taosd
```



### 1.1.2 debian 包

https://www.taosdata.com/cn/all-downloads/

```bash
wget https://www.taosdata.com/assets-download/TDengine-server-2.1.3.2-Linux-x64.deb
dpkg -i TDengine-server-2.1.3.2-Linux-x64.deb 
dpkg -r tdengine
```



### 1.1.3 二进制包

```bash
wget https://www.taosdata.com/assets-download/TDengine-server-2.1.3.2-Linux-x64.tar.gz
tar -xzvf  TDengine-server-2.1.3.2-Linux-x64.tar.gz

cd TDengine-server-2.1.3.2
./install.sh

systemctl start taosd
systemctl satus taosd

# 客户端连接数据库
taos

# 远程连接 (windows)
taos -h 192.168.80.221
```



## 1.2 Windows

1. 安装客户端

   https://www.taosdata.com/assets-download/TDengine-client-2.1.3.2-Windows-x64.exe

2. 安装稳定版的 MSYS2
   https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib/x86_64/msys2-x86_64-20210604.exe

2. 在c:\msys64\msys2_shell.cmd上点右键打开，然后在窗口上点右键， 选择 Options ，更改字符集：Locale选择zh_CN， Character set选择GBK。点击Apply后，save

3. 修改 pacman 配置

   编辑 c:\msys64\etc\pacman.d\mirrorlist.msys，在文件开头添加：

   ```bash
   Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/x86_64
   ```

4. 安装 gcc & make

   ```bash
   pacman -Sy
   
   pacman -S mingw-w64-x86_64-gcc 
   pacman -S make
   ```

5. 加入到PATH中 

   ```bash
   C:\msys64\mingw64\bin
   C:\msys64\usr\bin
   ```



# 2. 使用 taos

## 2.1 客户端

```bash
# 默认密码 taosdata
PS E:\> taos -h 192.168.80.250 -P 6030 -u root -p

Welcome to the TDengine shell from Linux, Client Version:2.1.3.2
Copyright (c) 2020 by TAOS Data, Inc. All rights reserved.

Enter password: taos> show databases\G;
*************************** 1.row ***************************
        name: log
created_time: 2021-07-05 09:41:58.994
     ntables: 4
     vgroups: 1
     replica: 1
      quorum: 1
        days: 10
        keep: 30
   cache(MB): 1
      blocks: 3
     minrows: 100
     maxrows: 4096
    wallevel: 1
       fsync: 3000
        comp: 2
   cachelast: 0
   precision: us
      update: 0
      status: ready
*************************** 2.row ***************************
        name: db
created_time: 2021-07-05 09:55:44.930
     ntables: 1
     vgroups: 1
     replica: 1
      quorum: 1
        days: 10
        keep: 3650
   cache(MB): 16
      blocks: 6
     minrows: 100
     maxrows: 4096
    wallevel: 1
       fsync: 3000
        comp: 2
   cachelast: 0
   precision: ms
      update: 0
      status: ready
Query OK, 2 row(s) in set (0.024000s)

taos> use db;
Query OK, 0 of 0 row(s) in database (0.000000s)

taos> show tables;
           table_name           |      created_time       | columns |          stable_name           |          uid          |     tid     |    vgId     |
==========================================================================================================================================================
 t                              | 2021-07-05 09:55:58.260 |       2 |                                |       844424946914086 |           1 |           3 |
Query OK, 1 row(s) in set (0.019000s)

taos> show tables\G;
*************************** 1.row ***************************
  table_name: t
created_time: 2021-07-05 09:55:58.260
     columns: 2
 stable_name:
         uid: 844424946914086
         tid: 1
        vgId: 3
Query OK, 1 row(s) in set (0.009000s)

taos> show create table t;
             Table              |          Create Table          |
==================================================================
 t                              | create table t (ts TIMESTAM... |
Query OK, 1 row(s) in set (0.010000s)

taos> show create table t\G
   -> ;
*************************** 1.row ***************************
       Table: t
Create Table: create table t (ts TIMESTAMP,cdata INT)
Query OK, 1 row(s) in set (0.005000s)
```



## 2.2 golang 连接器

```bash
go get github.com/taosdata/driver-go/v2
```







```bash
go get github.com/taosdata/driver-go/taosSql

# github.com/taosdata/driver-go/taosSql
C:/msys64/mingw64/bin/../lib/gcc/x86_64-w64-mingw32/10.3.0/../../../../x86_64-w64-mingw32/bin/ld.exe: $WORK\b001\_x003.o: in function `_cgo_604e892b494d_Cfunc_taosGetErrno':
/tmp/go-build/cgo-gcc-prolog:63: undefined reference to `taosGetErrno'
C:/msys64/mingw64/bin/../lib/gcc/x86_64-w64-mingw32/10.3.0/../../../../x86_64-w64-mingw32/bin/ld.exe: $WORK\b001\_x003.o: in function `_cgo_604e892b494d_Cfunc_taos_is_null':
/tmp/go-build/cgo-gcc-prolog:278: undefined reference to `taos_is_null'
C:/msys64/mingw64/bin/../lib/gcc/x86_64-w64-mingw32/10.3.0/../../../../x86_64-w64-mingw32/bin/ld.exe: $WORK\b001\_x003.o: in function `_cgo_604e892b494d_Cfunc_taos_stmt_is_insert':
/tmp/go-build/cgo-gcc-prolog:470: undefined reference to `taos_stmt_is_insert'
C:/msys64/mingw64/bin/../lib/gcc/x86_64-w64-mingw32/10.3.0/../../../../x86_64-w64-mingw32/bin/ld.exe: $WORK\b001\_x003.o: in function `_cgo_604e892b494d_Cfunc_tstrerror':
/tmp/go-build/cgo-gcc-prolog:581: undefined reference to `tstrerror'
collect2.exe: error: ld returned 1 exit status
```

windows 上编译失败，官方答复使用git下载，然后切换win分支，但是不支持stmt，即无法使用动态sql语句，需要自己的拼接sql，不安全，存在sql注入问题

代码比较：

```go
// win 分支，不支持动态参数
func (db *taosDB) Query(sql string) (rows driver.Rows, err error) {
	res := db.query(sql)
	if res == nil {
		err = errors.New("failed to query")
		return
	}
	errno := res.errno()
	if errno != 0 {
		err = errors.New(res.errstr())
		return
	}
	rows = res
	return
}

// master 分支
func (db *taosDB) Query(sql string, params ...driver.Value) (rows driver.Rows, err error) {
	var res *taosRes
	if len(params) == 0 {
		res = db.query(sql)
	} else {
		if res, err = db.execute(sql, params); err != nil {
			return
		}

	}
	if res == nil {
		if err = getError(); err == nil {
			err = errors.New("failed to query")
		}
		return
	}
	errno := res.errno()
	if errno != 0 {
		err = errors.New(res.errstr())
		return
	}
	rows = res
	return
}
```



## 2.3 python 连接器

```bash
pip install py_taos
```

windows完全不支持，支持 linux，centos/ubuntu16，其他操作系统，官方未承诺

```python
# C interface class
class CTaosInterface(object):

    libtaos = ctypes.CDLL('libtaos.so')   // 未关注平台，直接调用 linux 平台动态库

    libtaos.taos_fetch_fields.restype = ctypes.POINTER(TaosField)
    libtaos.taos_init.restype = None
    libtaos.taos_connect.restype = ctypes.c_void_p
    #libtaos.taos_use_result.restype = ctypes.c_void_p
    libtaos.taos_fetch_row.restype = ctypes.POINTER(ctypes.c_void_p)
    libtaos.taos_errstr.restype = ctypes.c_char_p
    libtaos.taos_subscribe.restype = ctypes.c_void_p
```



## 2.4 Restful Connector

```bash
curl -H 'Authorization: Basic cm9vdDp0YW9zZGF0YQ==' -d 'show databases;' 192.168.80.240:36041/rest/sql
{"status":"succ","head":["name","created_time","ntables","vgroups","replica","quorum","days","keep","cache(MB)","blocks","minrows","maxrows","wallevel","fsync","comp","cachelast","precision","update","status"],"column_meta":[["name",8,32],["created_time",9,8],["ntables",4,4],["vgroups",4,4],["replica",3,2],["quorum",3,2],["days",3,2],["keep",8,24],["cache(MB)",4,4],["blocks",4,4],["minrows",4,4],["maxrows",4,4],["wallevel",2,1],["fsync",4,4],["comp",2,1],["cachelast",2,1],["precision",8,3],["update",2,1],["status",8,10]],"data":[["log","2021-11-26 02:42:26.936",6,1,1,1,10,"30",1,3,100,4096,1,3000,2,0,"us",0,"ready"]],"rows":1}
```

请求格式：

```bash
http://<fqdn>:<port>/rest/sql/[db_name]

curl -H 'Authorization: Basic <TOKEN>' -d '<SQL>' <ip>:<PORT>/rest/sql/[db_name]
curl -u username:password -d '<SQL>' <ip>:<PORT>/rest/sql/[db_name]
```

获取授权码：

```bash
curl http://<fqnd>:<port>/rest/login/<username>/<password>

curl http://192.168.0.1:6041/rest/login/root/taosdata

curl http://192.168.80.240:36041/login/root/taosdata
```







# 3. 集群搭建

| IP             | name       | remark |
| -------------- | ---------- | ------ |
| 192.168.80.200 | k8s-master |        |
| 192.168.80.201 | k8s-node01 |        |
| 192.168.80.202 | k8s-node02 |        |

## 3.1 准备操作

```bash
# 设置主机名称
hostnamectl set-hostname k8s-master
hostnamectl set-hostname k8s-node01
hostnamectl set-hostname k8s-node02

# 域名解析
cat >> /etc/hosts <<EOF
192.168.80.200  k8s-master
192.168.80.201  k8s-node01
192.168.80.202  k8s-node02
EOF
```



## 3.2 安装操作

```bash
wget https://www.taosdata.com/assets-download/TDengine-server-2.2.0.2-Linux-x64.tar.gz
tar xzvf TDengine-server-2.2.0.2-Linux-x64.tar.gz
cd TDengine-server-2.2.0.2

# 暂不配置
./install.sh  
```



## 3.3 集群配置

```bash
vi /etc/taos/taos.cfg
firstEp                   k8s-master:6030    # 统一填写一样的值
fqdn                      k8s-master/k8s-node01/k8s-node02   # 填写实际的主机名或者域名
serverPort                6030
# arbitrator              k8s-master:6042    # 节点为偶数的时候指定

# 启动
systemctl start taosd
systemctl status taosd
```



## 3.4 节点管理

```bash
taos> show dnodes;
id   |   end_point            | vnodes | cores  |   status   | role  |       create_time       |      offline reason      |
===============================================================================================================================
1 | k8s-master:6030           |      1 |      2 | ready      | any   | 2021-09-17 05:53:45.277 |                          |

# 添加数据节点
taos> create dnode "k8s-node01:6030";
taos> create dnode "k8s-node02:6030";

# 节点列表
taos> show dnodes;
id   |   end_point            | vnodes | cores  |   status   | role  |       create_time       |      offline reason      |
===============================================================================================================================
1 | k8s-master:6030           |      0 |      2 | ready      | any   | 2021-09-17 05:53:45.277 |                          |
2 | k8s-node01:6030           |      1 |      2 | ready      | any   | 2021-09-17 06:22:40.340 |                          |
3 | k8s-node02:6030           |      0 |      2 | ready      | any   | 2021-09-17 06:22:44.923 |                          |

# 查看虚拟节点组
taos> show databases;
taos> use log;
taos> SHOW VGROUPS;
    vgId     |   tables    |  status  |   onlines   | v1_dnode | v1_status | compacting  |
==========================================================================================
           2 |           6 | ready    |           1 |        2 | master    |           0 |

# vnode的高可用性
taos> CREATE DATABASE mydb replica 3;

# Mnode的高可用性
taos> SHOW MNODES;
   id   |           end_point            |     role     |       create_time       |
===================================================================================
      1 | k8s-master:6030                | master       | 2021-09-17 05:53:45.277 |
      
      
```



## 3.5 使用

```bash
CREATE DATABASE mydb KEEP 365 DAYS 10 BLOCKS 6 UPDATE 1 REPLICA 3;
USE mydb;

# 超级表
CREATE STABLE meters (ts timestamp, current float, voltage int, phase float) TAGS (location binary(64), groupId int);

# 普通表
CREATE TABLE d1001 USING meters TAGS ("Beijing.Chaoyang", 2);
```






```
TDengine是涛思数据专为物联网、车联网、工业互联网、IT运维等设计和优化的大数据平台。除核心的快10倍以上的时序数据库功能外，还提供缓存、数据订阅、流式计算等功能，最大程度减少研发和运维的复杂度，且核心代码，包括集群功能全部开源。

TDengine是一个高效的存储、查询、分析时序大数据的平台，专为物联网、车联网、工业互联网、运维监测等优化而设计


物联网、工业互联网大数据的特点

时序的，一定带有时间戳；
结构化的；
数据极少有更新操作；
数据源是唯一的；
相对于互联网应用，读多写少；
用户关心的是一段时间的趋势；
数据是有保留期限的；
数据的查询往往是基于时间段和某组设备的；
除存储查询外，往往需要实时分析计算操作；
流量平稳可预测；
数据量巨大；
————————————————
版权声明：本文为CSDN博主「lime2019」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/weixin_44171004/article/details/110159464


数据特征
除时序特征外，仔细研究发现，物联网、车联网、运维监测类数据还具有很多其他明显的特征：

数据高度结构化；
数据极少有更新或删除操作；
无需传统数据库的事务处理；
相对互联网应用，写多读少；
流量平稳，根据设备数量和采集频次，可以预测出来；
用户关注的是一段时间的趋势，而不是某一特定时间点的值；
数据有保留期限；
数据的查询分析一定是基于时间段和空间区域；
除存储、查询操作外，还需要各种统计和实时计算操作；
数据量巨大，一天可能采集的数据就可以超过100亿条。


表用来代表一个具体的数据采集点，超级表用来代表一组相同类型的数据采集点集合

```



# 4. Taos SQL

## 4.1 用户管理

```bash
#创建用户，并指定用户名和密码，密码需要用单引号引起来,单引号为英文半角
create user admin pass 'admin123';

#删除用户，限root用户使用
drop user admin;

#修改用户密码, 为避免被转换为小写，密码需要用单引号引用,单引号为英文半角
alter user admin pass 'admin1234';

#修改用户权限为：super/write/read。 为避免被转换为小写，密码需要用单引号引用,单引号为英文半角
#语法：ALTER USER <user_name> PRIVILEGE <super|write|read>;
alter user admin privilege read;
```



## 4.1 数据库

```bash
#创建库：
#COMP参数是指修改数据库文件压缩标志位，取值范围为[0, 2]. 0表示不压缩，1表示一阶段压缩，2表示两阶段压缩。
#REPLICA参数是指修改数据库副本数，取值范围[1, 3]。在集群中使用，副本数必须小于dnode的数目。
#KEEP参数是指修改数据文件保存的天数，缺省值为3650，取值范围[days, 365000]，必须大于或等于days参数值。
#QUORUM参数是指数据写入成功所需要的确认数。取值范围[1, 3]。对于异步复制，quorum设为1，具有master角色的虚拟节点自己确认即可。对于同步复制，需要至少大于等于2。原则上，Quorum >=1 并且 Quorum <= replica(副本数)，这个参数在启动一个同步模块实例时需要提供。
#BLOCKS参数是每个VNODE (TSDB) 中有多少cache大小的内存块，因此一个VNODE的用的内存大小粗略为（cache * blocks）。取值范围[3, 1000]。
#DAYS一个数据文件存储数据的时间跨度，单位为天，默认值：10。
create database mydb keep 365 days 10 blocks 4;

#创建库（如果不存在）：
create database if not exists mydb keep 365 days 10 blocks 4;

#使用库：
use mydb;

#删除库：
drop database mydb;

#删除库（如果存在）：
drop database if exists mydb;

#显示所有数据库：
show databases;

#修改数据库文件压缩标志位：
alter database mydb comp 2;

#修改数据库副本数：
alter database mydb replica 2;

#修改数据文件保存的天数：
alter database mydb keep 365;

#修改数据写入成功所需要的确认数：
alter database mydb quorum 2;

#修改每个VNODE (TSDB) 中有多少cache大小的内存块：
alter database mydb blocks 100;
```



## 4.2 表

```bash
#创建表（搞了个包含所有数据类型的表）：
create table if not exists mytable(time timestamp, intfield int, bigintfield bigint, floatfield float, doublefield double, binaryfield binary(20), smallintfield smallint, tinyintfield tinyint, boolfield bool, ncharfiel
d nchar(50));

#删除数据表
drop table if exists mytable;

#显示当前数据库下的所有数据表信息
show tables;

#显示当前数据库下的所有数据表信息
#可在like中使用通配符进行名称的匹配。通配符匹配：1）’%’ (百分号)匹配0到任意个字符；2）’_’下划线匹配一个字符。
show tables like "%my%";

#获取表的结构信息
describe mytable;

#表增加列
alter table mytable add column addfield int;

#表删除列
alter table mytable drop column addfield;
```



## 4.3 超级表

```bash
#创建超级表
#创建STable, 与创建表的SQL语法相似，但需指定TAGS字段的名称和类型。说明：
#1) TAGS 列的数据类型不能是timestamp类型；
#2) TAGS 列名不能与其他列名相同；
#3) TAGS 列名不能为预留关键字；
#4) TAGS 最多允许128个，可以0个，总长度不超过16k个字符
create table if not exists mysupertable (time timestamp, intfield int, bigintfield bigint, floatfield float, doublefield double, binaryfield binary(20), smallintfield smallint, tinyintfield tinyint, boolfield bool, nch
arfield nchar(50)) TAGS (product nchar(50), device nchar(100));

#删除超级表
drop table if exists mysupertable;

#显示当前数据库下的所有超级表信息
show stables like "%super%";

#获取超级表的结构信息
describe mysupertable;

#超级表增加列
alter table mysupertable add column addfield int;

#超级表删除列
alter table mysupertable drop column addfield;

#添加标签
alter table mysupertable add tag devicetype nchar(60);

#删除标签
alter table mysupertable drop tag devicetype;

#修改标签名
alter table mysupertable change tag product productKey;

#修改子表标签值
#说明：除了更新标签的值的操作是针对子表进行，其他所有的标签操作（添加标签、删除标签等）均只能作用于STable，不能对单个子表操作。对STable添加标签以后，依托于该STable建立的所有表将自动增加了一个标签，所有新增标签的默认值都是NULL。
alter table mysupertable set tag productkey="abc";
```



## 4.4 数据插入

```bash
#插入一条数据
insert into mytable values(now, 1, 2, 3, 4, 0, 6, 7, 1, "s");

#插入一条记录，数据对应到指定的列
insert into mytable(time, intfield, bigintfield, floatfield, doublefield, binaryfield, smallintfield, tinyintfield, boolfield, ncharfield) values(now, 1, 2, 3, 4, 0, 6, 7, 1, "s");

#插入多条记录
insert into mytable values(now, 1, 2, 3, 4, 0, 6, 7, 1, "s") (now, 2, 3, 4, 5, 6, 7, 8, 0, "t");

#按指定的列插入多条记录
insert into mytable(time, intfield, bigintfield, floatfield, doublefield, binaryfield, smallintfield, tinyintfield, boolfield, ncharfield) values(now, 1, 2, 3, 4, 0, 6, 7, 1, "s") (now, 2, 3, 4, 5, 6, 7, 8, 0, "t");

#向多个表插入多条记录（本人没有验证此语句）
INSERT INTO tb1_name VALUES (field1_value1, ...)(field1_value2, ...)  tb2_name VALUES (field1_value1, ...)(field1_value2, ...);

#同时向多个表按列插入多条记录（本人没有验证此语句）
INSERT INTO tb1_name (tb1_field1_name, ...) VALUES (field1_value1, ...) (field1_value2, ...) tb2_name (tb2_field1_name, ...) VALUES (field1_value1, ...) (field1_value2, ...);
```



## 4.5 数据查询

```bash
SELECT select_expr [, select_expr ...]
    FROM {tb_name_list}
    [WHERE where_condition]
    [INTERVAL (interval_val [, interval_offset])]
    [FILL fill_val]
    [SLIDING fill_val]
    [GROUP BY col_list]
    [ORDER BY col_list { DESC | ASC }]    
    [SLIMIT limit_val [, SOFFSET offset_val]]
    [LIMIT limit_val [, OFFSET offset_val]]
    [>> export_file]
    
#查询表中的所有字段
select * from t_znsllj001;
#按照时间戳查询表中的所有字段
select * from t_znsllj001 where time > "2020-10-10 22:23:08.728";
#按照时间戳查询超级表中的所有字段
select * from st_znsllj where time > "2020-10-10 22:23:08.728";
#查询超级表中的指定字段
select time, forwardintegratedflow, product from st_znsllj;
#按照标签值查询超级表中的指定字段
select time, forwardintegratedflow, product from st_znsllj where product = "product1";
#查询结果按照时间倒序排序
select time, forwardintegratedflow, product from st_znsllj where product = "product1" order by time desc;
#结果集列名重命名
select time, forwardintegratedflow as ff, product from st_znsllj;
#查询超级表数据并附带表名（TBNAME： 在超级表查询中可视为一个特殊的标签，代表查询涉及的子表名，不区分大小写）
select tbname, * from st_znsllj;
#查询超级表的表名及第一列
 select tbname, _c0 from st_znsllj;

#获取当前所在的数据库
select database();
#获取客户端版本号
select client_version()
#获取服务器版本号
select server_version();
#服务器状态检测语句
select server_status()

#统计超级表下辖子表数量
select count(tbname) from st_znsllj;
```





## 4.6 数据删除







```sql
CREATE DATABASE IF NOT EXISTS iec61850 KEEP 365 DAYS 10 BLOCKS 6 UPDATE 0;
USE iec61850;

CREATE STABLE IF NOT EXISTS gooses (
    ts                   timestamp,
    go_cb_ref            binary(32),
    time_allowed_to_live int,
    dat_set              binary(32),
    go_id                binary(32),
    t                    timestamp,
    st_num               int,
    sq_num               int,
    simulation           bool,
    conf_rev             int,
    nds_com              bool,
    num_dat_set_entries  int,
    all_data             binary(16374)
) TAGS (dst_mac binary(20), src_mac binary(20), app_id int);


CREATE TABLE IF NOT EXISTS gapp001 USING gooses TAGS ("01:0c:cd:01:04:1e", "00:a0:1e:a8:01:98", 1054);

-- 自动创建表 gappXXX
INSERT INTO gapp%d USING gooses TAGS ('%s', '%s', %d) VALUES ('%s', '%s', %d, '%s', '%s', '%s', %d, %d, %t, %d, %t, %d, '%s');

-------------------------------------------

CREATE STABLE IF NOT EXISTS svs (
    ts                   timestamp,
    pdu_index            int,
    sv_id                binary(32),
    dat_set              binary(32),
    smp_cnt              int,
    conf_rev             int,
    refr_tm              int,
    smp_synch            bool,
    smp_mod              int,
    smp_rate             int,
    seq_data             binary(16374)
) TAGS (dst_mac binary(20), src_mac binary(20), app_id int);

INSERT INTO sapp%d USING svs TAGS ('%s', '%s', %d) VALUES ('%s', %d, '%s', '%s', %d, %d, %d, %t, %d, %d, '%s');
```

