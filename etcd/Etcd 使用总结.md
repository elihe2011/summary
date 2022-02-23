# 1. 简介

Etcd API 特性：

- 原子性：一个操作要么全部执行，要么全部不执行
- 一致性：不论客户端请求的是哪个etcd服务器，它都能读取到相同的事件，而且这些事件的顺序也是保持一致的。
- 隔离性：etcd保证可串行化隔离(serializable isolation)，读操作永远不会看到任何中间数据
- 持久性：任何完成的操作都是持久性的。读操作永远不会返回未持久化存储的数据



# 2. 集群状态

```bash
$ curl http://192.168.3.191:2379/version | python3 -m json.tool
{
    "etcdserver": "3.5.1",
    "etcdcluster": "3.5.0"
}

$ curl http://192.168.3.191:2379/health | python3 -m json.tool
{
    "health": "true",
    "reason": ""
}

$ etcdctl version
etcdctl version: 3.5.1
API version: 3.5

$ etcdctl endpoint status
$ etcdctl endpoint health

$ ETCDCTL_API=2 etcdctl  cluster-health
member 7fe4b7b1994a2a9f is healthy: got healthy result from http://192.168.3.191:2379
member 96c03e6d8f6451f3 is healthy: got healthy result from http://192.168.3.192:2379
member cac6c28b4a6bf042 is healthy: got healthy result from http://192.168.3.193:2379
```



# 3. Etcd API V2

## 3.1 KV

```bash
curl http://127.0.0.1:2379/v2/keys/age -X PUT -d value=12
curl http://127.0.0.1:2379/v2/keys/age
curl http://127.0.0.1:2379/v2/keys/age -X DELETE

# TTL
curl http://127.0.0.1:2379/v2/keys/age -X PUT -d value=10 -d ttl=5

# 集群全局信息
curl http://127.0.0.1:2379/v2/keys/age -I   
HTTP/1.1 200 OK
Access-Control-Allow-Headers: accept, content-type, authorization
Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE
Access-Control-Allow-Origin: *
Content-Type: application/json
X-Etcd-Cluster-Id: be7c242d574aadc5
X-Etcd-Index: 11
X-Raft-Index: 16
X-Raft-Term: 2
Date: Wed, 12 Jan 2022 05:39:02 GMT
Content-Length: 89

# 动态刷新已存在的key
curl http://127.0.0.1:2379/v2/keys/age -X PUT -d ttl=5 -d refresh=true -d preExist=true
```

TTL 原理：

- Etcd 在接收客户端PUT请求时，如果请求参数中包含TTL，会将其值加入当前系统时间，作为key的过期时间。
- 当前节点将这个请求通过Raft协议RPC消息同步到其他节点。如果接收客户端是Leader，则直接同步；如果是Follower，需要先将其转发给Leader后再同步到其他节点，单该key的 "expiration" 以follower为准，可能存在与leader不一致的情况，所以在follower上，将设置了TTL的key加到一个有序的map中(ttlKeyHeap)
- 在Leader中允许一个tick，每 500ms 触发一次带leader系统时间的同步消息(syncTime)，follower收到该消息后，查询ttlKeyHeap，删除已过期的key

`refresh=true`: 动态刷新TTL，可解决Etcd节点之间时钟不同步，导致定义的TTL被早删或晚删问题。另外，指定该参数后，无法更新其value



## 3.2 Watch

watch 机制：Etcd 在客户端等待key的变化并接收通知。它是通过一个 long polling 来实现的。

watch目录时，指定参数：`recursive=true`

```bash
# 一次性watch
$ curl http://127.0.0.1:2379/v2/keys/age?wait=true
{"action":"set","node":{"key":"/age","value":"12","modifiedIndex":26,"createdIndex":26}}

# 带索引watch
$ curl 'http://127.0.0.1:2379/v2/keys/age?wait=true&waitIndex=27'

# 持久化watch
$ curl 'http://127.0.0.1:2379/v2/keys/age?wait=true&recursive=true&stream=true'

# watch被清除
curl 'http://127.0.0.1:2379/v2/keys/age?wait=true&waitIndex=0'
```



## 3.3 统计

```bash
# leader数据，注意该请求只能发往leader节点
$ curl http://127.0.0.1:2379/v2/stats/leader | python3 -m json.tool
{
    "leader": "7fe4b7b1994a2a9f",
    "followers": {
        "12971f2c752331ba": {
            "latency": {
                "current": 0.00286,
                "average": 0.004560272727272729,
                "standardDeviation": 0.0031605226500513463,
                "minimum": 0.00042,
                "maximum": 0.0314
            },
            "counts": {
                "fail": 1,
                "success": 242
            }
        },
        "96c03e6d8f6451f3": {
            "latency": {
                "current": 0.0036,
                "average": 0.004349815261044178,
                "standardDeviation": 0.0045908728796599,
                "minimum": 0.00038,
                "maximum": 0.04868
            },
            "counts": {
                "fail": 0,
                "success": 249
            }
        }
    }
}

# 查询leader
$ ETCDCTL_API=2 etcdctl --endpoints http://192.168.3.192:2379 member list
12971f2c752331ba: name=etcd-3 peerURLs=http://192.168.3.193:2380 clientURLs=http://192.168.3.193:2379,http://localhost:2379 isLeader=false
7fe4b7b1994a2a9f: name=etcd-1 peerURLs=http://192.168.3.191:2380 clientURLs=http://192.168.3.191:2379,http://localhost:2379 isLeader=true
96c03e6d8f6451f3: name=etcd-2 peerURLs=http://192.168.3.192:2380 clientURLs=http://192.168.3.192:2379,http://localhost:2379 isLeader=false
```



```bash
# 节点自身数据
$ curl http://192.168.3.192:2379/v2/stats/self | python3 -m json.tool
{
    "name": "etcd-2",
    "id": "96c03e6d8f6451f3",
    "state": "StateFollower",
    "startTime": "2022-01-12T13:12:54.345682074+08:00",
    "leaderInfo": {
        "leader": "7fe4b7b1994a2a9f",
        "uptime": "1h38m34.91545621s",
        "startTime": "2022-01-12T13:12:55.583282779+08:00"
    },
    "recvAppendRequestCnt": 249,
    "sendAppendRequestCnt": 0
}
```



```bash
# 其他统计
$ curl http://192.168.3.192:2379/v2/stats/store | python3 -m json.tool
{
    "getsSuccess": 3,
    "getsFail": 14,
    "setsSuccess": 24,
    "setsFail": 4,
    "deleteSuccess": 1,
    "deleteFail": 0,
    "updateSuccess": 0,
    "updateFail": 0,
    "createSuccess": 4,
    "createFail": 0,
    "compareAndSwapSuccess": 0,
    "compareAndSwapFail": 0,
    "compareAndDeleteSuccess": 0,
    "compareAndDeleteFail": 0,
    "expireCount": 6,
    "watchers": 0
}
```



## 3.4 成员维护

**注意**：已存在的节点重新加入集群，需要修改配置`initial-cluster-state: 'existing'`

```bash
# 获取所有成员
$ curl http://192.168.3.191:2379/v2/members | python3 -m json.tool
{
    "members": [
        {
            "id": "12971f2c752331ba",
            "name": "etcd-3",
            "peerURLs": [
                "http://192.168.3.193:2380"
            ],
            "clientURLs": [
                "http://192.168.3.193:2379",
                "http://localhost:2379"
            ]
        },
        {
            "id": "7fe4b7b1994a2a9f",
            "name": "etcd-1",
            "peerURLs": [
                "http://192.168.3.191:2380"
            ],
            "clientURLs": [
                "http://192.168.3.191:2379",
                "http://localhost:2379"
            ]
        },
        {
            "id": "96c03e6d8f6451f3",
            "name": "etcd-2",
            "peerURLs": [
                "http://192.168.3.192:2380"
            ],
            "clientURLs": [
                "http://192.168.3.192:2379",
                "http://localhost:2379"
            ]
        }
    ]
}
```



```bash
# 删除成员
$ curl http://192.168.3.191:2379/v2/members/12971f2c752331ba -X DELETE

# 新增成员
$ curl http://192.168.3.191:2379/v2/members -X POST -H "Content-Type:application/json" -d '{"peerURLs": ["http://192.168.3.193:2380"]}'
{"id":"87c40f906dbafc3f","name":"","peerURLs":["http://192.168.3.193:2380"],"clientURLs":[]}

# 修改成员
curl http://192.168.3.191:2379/v2/members/87c40f906dbafc3f -X PUT -H "Content-Type:application/json" -d '{"peerURLs": ["http://192.168.3.193:2381"]}'
```



# 4. Etcd API V3

接口文档：https://github.com/etcd-io/etcd/blob/main/Documentation/dev-guide/apispec/swagger/rpc.swagger.json

```bash
/v3/auth/authenticate
/v3/auth/disable
/v3/auth/enable
/v3/auth/role/add
/v3/auth/role/delete
/v3/auth/role/get
/v3/auth/role/grant
/v3/auth/role/list
/v3/auth/role/revoke
/v3/auth/status
/v3/auth/user/add
/v3/auth/user/changepw
/v3/auth/user/delete
/v3/auth/user/get
/v3/auth/user/grant
/v3/auth/user/list
/v3/auth/user/revoke
/v3/cluster/member/add
/v3/cluster/member/list
/v3/cluster/member/promote
/v3/cluster/member/remove
/v3/cluster/member/update
/v3/kv/compaction
/v3/kv/deleterange
/v3/kv/lease/leases
/v3/kv/lease/revoke
/v3/kv/lease/timetolive
/v3/kv/put
/v3/kv/range
/v3/kv/txn
/v3/lease/grant
/v3/lease/keepalive
/v3/lease/leases
/v3/lease/revoke
/v3/lease/timetolive
/v3/maintenance/alarm
/v3/maintenance/defragment
/v3/maintenance/downgrade
/v3/maintenance/hash
/v3/maintenance/snapshot
/v3/maintenance/status
/v3/maintenance/transfer-leadership
/v3/watch
```



## 4.1 KV

参数需要先base64转换：`foo:Zm9v, bar:YmFy`

```bash
curl -L http://localhost:2379/v3/kv/put \
  -X POST -d '{"key": "Zm9v", "value": "YmFy"}'
  
curl -L http://localhost:2379/v3/kv/range \
  -X POST -d '{"key": "Zm9v"}'
  
curl -L http://localhost:2379/v3/kv/range \
  -X POST -d '{"key": "Zm9v", "range_end": "Zm9w"}'
```



## 4.2 Watch

```bash
curl -N http://localhost:2379/v3/watch \
  -X POST -d '{"create_request": {"key":"Zm9v"} }'
```



## 4.3 Transactions

```bash
# target CREATE
curl -L http://localhost:2379/v3/kv/txn \
  -X POST \
  -d '{"compare":[{"target":"CREATE","key":"Zm9v","createRevision":"2"}],"success":[{"requestPut":{"key":"Zm9v","value":"YmFy"}}]}'
  
# target VERSION
curl -L http://localhost:2379/v3/kv/txn \
  -X POST \
  -d '{"compare":[{"version":"4","result":"EQUAL","target":"VERSION","key":"Zm9v"}],"success":[{"requestRange":{"key":"Zm9v"}}]}'
```



## 4.4 Auth

```bash
# create root user
curl -L http://localhost:2379/v3/auth/user/add \
  -X POST -d '{"name": "root", "password": "pass"}'

# create root role
curl -L http://localhost:2379/v3/auth/role/add \
  -X POST -d '{"name": "root"}'

# grant root role
curl -L http://localhost:2379/v3/auth/user/grant \
  -X POST -d '{"user": "root", "role": "root"}'

# enable auth
curl -L http://localhost:2379/v3/auth/enable -X POST -d '{}'

# get the auth token for the root user
curl -L http://localhost:2379/v3/auth/authenticate \
  -X POST -d '{"name": "root", "password": "pass"}'
# {"header":{"cluster_id":"6617056074685781600","member_id":"15300616325842721311","revision":"46","raft_term":"3"},"token":"PpNSrukaCCPpbzGT.30"}

# fetch a key using authentication credentials
curl -L http://localhost:2379/v3/kv/put \
  -H 'Authorization: PpNSrukaCCPpbzGT.30' \
  -X POST -d '{"key": "Zm9v", "value": "YmFy"}'

# disable auth
curl -L http://localhost:2379/v3/auth/disable \
  -H 'Authorization: BLAWaOJuPEiGzRft.36' \
  -X POST -d '{}'
```



# 5. etcdctl

API 版本选择：`ETCDCTL_API=2/3`, 默认版本为3



## 5.1 KV

```bash
# 写
$ etcdctl put /test/name jack
$ etcdctl put /test/age 12

# 读
$ etcdctl get /test/name
$ etcdctl get /test/name --print-value-only
$ etcdctl get /test --prefix --keys-only
$ etcdctl get / --prefix --limit=2

# 读取历史版本：revision, 需要支持才行，详见配置
$ etcdctl put /test/age 13
$ etcdctl put /test/age 14
$ etcdctl put /test/age 15
$ etcdctl put /test/age 16
$ etcdctl get /test/age -w json | python3 -m json.tool
{
    "header": {
        "cluster_id": 13725885541475069381,
        "member_id": 9215692710915746463,
        "revision": 12,
        "raft_term": 9
    },
    "kvs": [
        {
            "key": "L3Rlc3QvYWdl",
            "create_revision": 4,
            "mod_revision": 12,
            "version": 9,
            "value": "MTY="
        }
    ],
    "count": 1
}

$ etcdctl get /test/age --rev=8
/test/age
12

$ etcdctl get /test/age --rev=11
/test/age
15

$ etcdctl get /test/age --rev=12
/test/age
16

# compact up to revision 10
$ etcdctl compact 10
$ compacted revision 10

$ etcdctl get /test/age --rev=8
{"level":"warn","ts":"2022-01-13T09:48:59.105+0800","logger":"etcd-client","caller":"v3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000408700/127.0.0.1:2379","attempt":0,"error":"rpc error: code = OutOfRange desc = etcdserver: mvcc: required revision has been compacted"}
Error: etcdserver: mvcc: required revision has been compacted

$ etcdctl get /test/age --rev=11
/test/age
15

$ etcdctl get /test/age --rev=12
/test/age
16

# 按key字段序读取
$ etcdctl put /abc/a 1
$ etcdctl put /abc/b 2
$ etcdctl put /abc/z 9

$ etcdctl get --from-key /abc/b
/abc/b
2
/abc/z
9
/test/age
16
/test/name
jack
age
12

$ etcdctl get --from-key /abc --keys-only
/abc/a
/abc/b
/abc/z
/test/age
/test/name
age

# 删
$ etcdctl del age name
$ etcdctl del --prev-kv /abc/z   # 删除并同时返回值
$ etcdctl del --prefix /abc

$ etcdctl put a 1
$ etcdctl put b 2
$ etcdctl put c 3
$ etcdctl del --from-key b       # 按字段序删除
$ etcdctl get --prefix ''  --keys-only
/test/age
/test/name
a
```



## 5.2 Watch

watch机制：一旦某个 Key 返生变化，客户端就能够感知到变化。除非watch命令捕获到退出信号量，否则会一直等待而不会退出

```bash
$ etcdctl watch /test/name
PUT
/test/name
joe
PUT
/test/name
tom
DELETE
/test/name

$ etcdctl watch --prefix /
PUT
/test/name
tom
PUT
/test/age
20

$ etcdctl watch -i
watch /test/age
PUT
/test/age
21

$ etcdctl watch --rev=10 /test/age
PUT
/test/age
14
PUT
/test/age
15
PUT
/test/age
16
PUT
/test/age
20
PUT
/test/age
21
PUT
/test/age
21

$ etcdctl watch --prev-kv /test/age
PUT
/test/age
21
/test/age
22
```



## 5.3 Lease

租约是 v3 API 的特性。客户端可以为 key 授予租约（lease）。当一个 key 绑定一个租约时，它的生命周期便会与该租约的 TTL（time-to-live）保持一致。每个租约都有一个由用户授予的 TTL 值。如果某个租约的 TTL 超时了，那么该租约就会过期而且上面绑定的所有 Key 也会被自动删除。

```bash
# 创建租约
$ etcdctl lease grant 600
lease 2a9f7e511bbf1043 granted with TTL(600s)

# 租约有效期
$ etcdctl lease timetolive 2a9f7e511bbf1043 
lease 2a9f7e511bbf1043 granted with TTL(600s), remaining(575s)

# 绑定key
$ etcdctl put --lease=2a9f7e511bbf1043 /test/name tom

# 租约绑定的keys
$ etcdctl lease timetolive --keys 2a9f7e511bbf1043
lease 2a9f7e511bbf1043 granted with TTL(600s), remaining(477s), attached keys([/test/name])

# 自动续租，每次续租都发生在TTL快要过期时
$ etcdctl lease keep-alive 2a9f7e511bbf1043

# 租约撤销后，它绑定的key也会被清除
$ etcdctl lease revoke 2a9f7e511bbf1043   
```



## 5.4 Cluster

```bash
$ etcdctl member list
7fe4b7b1994a2a9f, started, etcd-1, http://192.168.3.191:2380, http://192.168.3.191:2379,http://localhost:2379, false
96c03e6d8f6451f3, started, etcd-2, http://192.168.3.192:2380, http://192.168.3.192:2379,http://localhost:2379, false
e26dd4722a25bb82, unstarted, , http://192.168.3.193:2380, , false

$ etcdctl member remove e26dd4722a25bb82

# etcd-3上执行
$ systemctl stop etcd
$ rm -rf /var/lib/etcd
$ systemctl start etcd

$ etcdctl member add etcd-3 --peer-urls=http://192.168.3.193:2380
```



## 5.5 灾难恢复

### 5.5.1 备份

```bash
etcdctl snapshot save snapshot.db
```



### 5.5.2 恢复

```bash
# 检查数据文件
etcdutl snapshot status snapshot.db -w table
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 667a1338 |       35 |         46 |      25 kB |
+----------+----------+------------+------------+

# 恢复数据文件：注意--data-dir指定的目录必须为空
etcdutl snapshot restore snapshot.db --data-dir /var/lib/etcd/default.etcd --name etcd-1 --initial-advertise-peer-urls http://192.168.80.200:2380 --initial-cluster etcd-1=http://192.168.80.200:2380 --initial-cluster-token etcd-cluster

# 启动etcd
systemctl start etcd

# 检查数据
etcdctl get / --prefix
/test/age
22
/test/name
tom
```



## 5.6 历史版本

```bash
# 保留一小时历史版本
etcd --auto-compaction-mode=periodic --auto-compaction-retention=1

# 保留1000个版本，每5分钟减少1000个历史版本，例如当前版本为30000，那么最老的版本为29000
etcd --auto-compaction-mode=revision --auto-compaction-retention=1000

# 版本压缩，即删除小于等于它的历史版本
etcdctl compact 3
etcdctl get --rev=2 somekey  # 无法获取历史版本
```



## 5.7 碎片化

压缩历史版本之后，后台数据库将会存在内部的碎片。这些碎片无法被后台存储使用，却仍占据节点的存储空间。因此消除碎片化的过程就是释放这些存储空间。压缩旧的历史版本会对后台数据库打个 ”洞”，从而导致碎片的产生。这些碎片空间对 Etcd 是可用的，但对宿主机文件系统是不可用的。

```bash
etcdctl defrag
etcdctl defrag --cluster
```



## 5.8 存储配额

Etcd 的存储配额可保证集群操作的可靠性。如果没有存储配额，那么 Etcd 的性能就会因为存储空间的持续增长而严重下降，甚至有耗完集群磁盘空间导致不可预测集群行为的风险。一旦其中一个节点的后台数据库的存储空间超出了存储配额，Etcd 就会触发集群范围的告警，并将集群置于接受读 key 和删除 key 的维护模式。只有在释放足够的空间和消除后端数据库的碎片之后，清除存储配额告警，集群才能恢复正常操作。

```bash
$ etcd --quota-backend-bytes=$((16*1024*1024))   # 16M

# 压测
$ while true; do dd if=/dev/urandom bs=1024 count=1024 | etcdctl put key || break; done

# 状态
$ etcdctl endpoint status --write-out=table 
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------------------------------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX |             ERRORS             |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------------------------------+
| 127.0.0.1:2379 | d456b57b7265da1f |   3.5.1 |   17 MB |      true |      false |         3 |         19 |                 19 |  memberID:15300616325842721311 |
|                |                  |         |         |           |            |           |            |                    |                 alarm:NOSPACE  |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------------------------------+

# 告警
$ etcdctl alarm list
memberID:15300616325842721311 alarm:NOSPACE

# 最新的版本
$ etcdctl endpoint status -w json | python3 -m json.tool
[
    {
        "Endpoint": "127.0.0.1:2379",
        "Status": {
            "header": {
                "cluster_id": 6617056074685781600,
                "member_id": 15300616325842721311,
                "revision": 45,
                "raft_term": 3
            },
            "version": "3.5.1",
            "dbSize": 16830464,
            "leader": 15300616325842721311,
            "raftIndex": 21,
            "raftTerm": 3,
            "raftAppliedIndex": 21,
            "errors": [
                "memberID:15300616325842721311 alarm:NOSPACE "
            ],
            "dbSizeInUse": 11587584
        }
    }
]

# 清除碎片
$ etcdctl defrag

# 消除告警
$ etcdctl alarm disarm

# 测试写入是否正常
$ etcdctl put key newvalue
```



# 6. TLS

```bash
# restful api
curl --cacert ./ca.pem --cert ./etcd.pem --key ./etcd-key.pem -sL https://127.0.0.1:2379/version

$ echo -n '/registry' | base64
L3JlZ2lzdHJ5

$ echo -n '\0' | base64
XDA=

$ curl --cacert ./ca.pem --cert ./etcd.pem --key ./etcd-key.pem -sL https://127.0.0.1:2379/v3/kv/range \
-X POST -d '{"key": "L3JlZ2lzdHJ5", "range_end": "XDA=", "keys_only": true}'

# etcdctl
$ etcdctl --cacert=/etc/kubernetes/pki/ca.pem --cert=/etc/kubernetes/pki/etcd.pem --key=/etc/kubernetes/pki/etcd-key.pem get /registry --prefix --keys-only=true
```

