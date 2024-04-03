# 1. 服务端

```bash
apt install snmp snmpd 

vi /etc/snmp/snmpd.conf
agentaddress  127.0.0.1,[::1],192.168.3.104
view   all         included   .1

net-snmp-create-v3-user -ro -A tk@xdt168 -X tk@xdt168 -a MD5 -x DES tksmmp
```



```bash
apt install libsnmp-dev

# 只读认证且加密账号
net-snmp-create-v3-user -ro -A tk@xdt168 -X tk@xdt168 -a MD5 -x DES tksmmp

# 读写认证且加密账号
net-snmp-create-v3-user  -A auth123456 -a MD5 -X priv123456 -x DES fxw 

# 只读认证但不加密账号()
net-snmp-create-v3-user -ro -A auth123456 -a MD5 fxa
```

参数说明：

- `-ro`:用户读写权限，表示用户fx为只具有读权限
- `fx`：用户名
- `-a MD5`:认证方式，MD5散列方式
- `-A auth123456`：设置认证密码，密码必须大于8个字符
- `-x DES`:加密方式，这边支持AES、DES两种
- `priv123456`：加密口令，必须大于8位



# 2. 客户端

```bash



snmpwalk -v1 -c public 192.168.3.104


snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 1.3.6.1.2.1.25.2.3.1.3



snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 1.3.6.1.2.1.6.13.1.3

# cpu
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.11.9.0

snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.2.1.25.3.2

# icmp
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 1.3.6.1.2.1.5

# disk
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.9

# netlink
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.2.1.2.1


snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.2.1.25.2.2.0


```



```bash
snmpbulkget -v3 -u tksmmp -l authPriv -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.2.1.25.2.2.0

# memory
snmpbulkget -t 5 -r 3 -On -v3 -u tksmmp -l authPriv -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.4.5.0

# disk
snmpbulkwalk -Cc -t 5 -r 3 -On -v 3 -u tksmmp -l authPriv -a MD5 -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.9.1

# cpu
snmpbulkget -t 5 -r 3 -On -v3 -u tksmmp -l authPriv -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.11

# load
snmpbulkget -t 5 -r 3 -On -v3 -u tksmmp -l authPriv -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.4.1.2021.10.1.3.1


# system
snmpbulkget -t 5 -r 3 -On -v3 -u tksmmp -l authPriv -A tk@xdt168 -x DES -X tk@xdt168 192.168.3.104 .1.3.6.1.2.1.1.1
```

