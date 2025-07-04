# 1. snmp

## 1.1 安装

**Ubuntu**:

```bash
apt install snmp snmpd libsnmp-dev

vi /etc/snmp/snmpd.conf
agentaddress  127.0.0.1,[::1],192.168.3.104
view   all         included   .1
```



**CentOS**:

```bash
yum install net-snmp net-snmp-utils -y

vi /etc/snmp/snmpd.conf
view all    included  .1                               80
```



## 1.2 账号

命令 `net-snmp-create-v3-user` 参数：

-  `-ro`：用户只具有读权限
-  `-A authpass`：认证密码，至少8个字符
-  `-X privpass`：加密密码，至少8个字符
-  `-a MD5|SHA|SHA-512|SHA-384|SHA-256|SHA-224` ：认证方式
-  `-x DES|AES`：加密算法
-  `username`：用户名



```bash
# 必须先停止snmpd服务
systemctl stop snmpd

# authPriv 既认证又加密
net-snmp-create-v3-user -A eli@Auth -X eli@Priv -a MD5 -x DES eli

snmpwalk -v3 -u eli -l auth -a MD5 -A eli@Auth -X eli@Priv 192.168.3.100

# authNoPriv 认证但不加密
net-snmp-create-v3-user -A eli@Auth -a MD5 eli
snmpwalk -v3 -u eli -l authNoPriv -a MD5 -A eli@Auth 192.168.3.100

# noAuthNoPriv 不认证也不加密
net-snmp-create-v3-user eli
snmpwalk -v3 -u eli -l noAuthnoPriv 192.168.3.100

# 只读用户
net-snmp-create-v3-user -ro eli
```



## 1.3 示例

```bash
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.25.2.3.1.3

snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.6.13.1.3

# cpu
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.4.1.2021.11.9.0

snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.25.3.2

# icmp
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 1.3.6.1.2.1.5

# disk
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.4.1.2021.9

# netlink
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.2.1


snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u abc -l authPriv -a MD5 -A abc@Auth -x DES -X abc@Priv 192.168.3.104 .1.3.6.1.2.1.25.2.2.0
```



## 1.4 扩展

开启主机磁盘查询 .1.3.6.1.4.1.2021.9.1

```bash
vi /etc/snmp/snmpd.conf
# disk checks
disk / 10000

systemctl restart snmpd
```



# 2. 内存采集

## 2.1 free 命令

```
              total        used        free      shared  buff/cache   available
Mem:       32927528    14297604     3653144     1584932    14976780    16642228
Swap:             0           0           0
```



字段说明：

| 字段       | 中文解释      | 含义说明                                                     |
| ---------- | ------------- | ------------------------------------------------------------ |
| total      | 总内存        | 系统物理内存总量。这里是 32,927,528 KB ≈ 31.4 GB             |
| used       | 已使用内存    | 已被使用的内存（不包括 buff/cache）。这里是 14,297,604 KB ≈ 13.6 GB |
| free       | 空闲内存      | 完全未被使用的内存。这里是 3,653,144 KB ≈ 3.5 GB             |
| shared     | 共享内存      | 多个进程共享的内存，通常是 tmpfs 等共享文件系统使用的内存。约 1.5 GB |
| buff/cache | 缓冲/缓存内存 | 系统用于缓存文件数据或磁盘读写的内存。这里是 14,976,780 KB ≈ 14.3 GB |
| available  | 可用内存      | 系统评估的当前可用于新程序的内存，不一定等于 free。这里是 16,642,228 KB ≈ 15.9 GB，比 free 多，是因为包含了一部分可以回收的 buff/cache。 |



**当前系统状态**：

- **总内存**：约 31.4 GB
- **真正被使用的进程内存**：约 13.6 GB
- **可供使用的内存**：约 15.9 GB
- **缓存和缓冲区（可被回收）**：约 14.3 GB



**内存使用率：**

```python
memory_usage_rate = (total - available) / total × 100%

used_real = total - available = 32927528 - 16642228 = 16285300 KB

内存使用率 = (16285300 / 32927528) ≈ 49.46%
```



## 2.2 snmp 采集

采集到的字段及值：

| 字段             | 值 (KB) |含义                                                     |
| ---------------- | --|-------------------------------------------------------- |
| **memTotalReal** | 32927528 |物理内存总量，对应 `MemTotal`                            |
| **memAvailReal** | 2213504 | 可用物理内存，不包括 buffer/cache |
| **memTotalFree** | 2213504 |未使用的内存 (包含交互分区内存)                         |
| **memShared**    | 1609444 |共享内存，对应 `Shmem`，但现代内核中意义不大             |
| **memBuffer**    | 32 |buffer 内存（缓存块设备数据），对应 `Buffers`            |
| **memCached**    | 15111660 |cache 内存（缓存文件内容），对应 `Cached`                |
| **memTotalSwap** | 0 |交换空间总量，对应 `SwapTotal`                           |
| **memAvailSwap** | 0 |可用交换空间，对应 `SwapFree`                            |



**推荐内存使用率计算方式（只考虑实际 RAM）**：

```
memory_usage_rate = (memTotalReal - memTotalFreeReal - memBuffer - memCached) / memTotalReal

used_real = memTotalReal - memTotalFreeReal - memBuffer - memCached = 32927528 - 2213504 - 32 - 15111660 = 15602332 KB

内存使用率 = (15602332 / 32927528) ≈ 47.38%
```



## 2.3 对应关系

| snmp             | free                  |
| ---------------- | --------------------- |
| **memTotalReal** | total(Mem)            |
| **memAvailReal** | free(Mem)             |
| **memTotalFree** | free(Mem) + free(Swap) |
| **memShared**    | shared(Mem)           |
| **memBuffer**    | buf(Mem)              |
| **memCached**    | cache(Mem)            |
| **memTotalSwap**    | total(Swap)              |
| **memAvailSwap**    | free(Mem)            |