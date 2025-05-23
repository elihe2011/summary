# 1. SNMP

SNMP，Simple Network Management Protocol，简单网络管理协议。

SNMP 作为广泛用于 TCP/IP 网络的管理标准协议，提供了统一的接口，实现不同种类和厂商的网络设备之间的统一管理。

SNMP 协议的三个版本：

- SNMPv1：最初版本，提供最小限度的网络管理功能。它基于团队名认证，安全性交叉，且返回报文的错误码也较少。
- SNMPv2：也采用团体名认证，在v1的基础上，引入了 GetBulk 和 Inform 操作，支持更多的标准错误码信息，支持更多的数据类型 (Counter32、Counter64)。
- SNMPv3：在安全性方面进行了增强，提供了基于 USM (User Security Module) 的认证加密和基于 VACM (View-based Access Control Model) 的访问控制。v3支持的操作和v2一样。



## 1.1 系统组成

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-system-diagram.png)  



### 1.1.1 NMS

**NMS (Network Management System)**，网络中的管理者，是一个采用 SNMP 协议对网络设备进行管理、监视的系统，运行在 NMS 服务器上。

- NMS 可以向设备上的 SNMP Agent 发出请求，查询或修改一个或多个具体的参数值
- NMS 可以接受设备上的 SNMP Agent 主动发送的 SNMP Traps，以获知被管理设备当前的状态



### 1.1.2 SNMP Agent

**SNMP Agent** 被管理设备中的一个代理进程，用于维护被管理设备的信息数据并响应来自 NMS 的请求，把管理数据汇报给发送请求的NMS。

- SNMP Agent 接收到 NMS 请求信息后，通过 MIB 表来完成相应指令后，并把操作结果响应给 NMS
- 当设备发生故障或者其它事件时，设备会通过 SNMP Agent 主动发送 SNMP Traps 给 NMS，向 NMS 报告设备当前的状态变化



### 1.1.3 Managed Object

**Managed Object** 被管理的对象。每个设备可能包含多个被管理对象，被管理对象可以是设备中的某个硬件，也可以是在硬件、软件上配置的参数集合。



### 1.1.4 MIB

**MIB** 是一个数据库，定义了被管理对象的一系列属性：对象的名称、对象的状态、对象的访问权限和对象的数据类型等。MIB 也可以看作是 NMS 和 SNMP Agent 之间的一个接口，通过这个接口，NMS 对被管理设备所维护的变量进行查询、设置操作。

**MIB，Management Information Base**，主要负责为所有被管理网络节点建立一个接口，本质是类似 Ip 地址的一串数字，例如：

```
.1.3.6.1.2.1.1.5.0
```

参考含义：

| 1    | 3    | 6    | 1        | 2    | 1     | 1      | 5       | 0    |
| ---- | ---- | ---- | -------- | ---- | ----- | ------ | ------- | ---- |
| iso  | org  | dod  | internet | mgmt | mib-2 | system | sysName | end  |

MIB 以树状结构进行存储。树的节点表示被管理对象，它可以用从根开始的一条路径唯一地识别，称为 OID。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-oid-tree.png)  

MIB 两种对象类型：

- **标量 (Scalar)，单节点，OID 以 `0` 结尾**
  - 单一值，表示设备的某个状态和属性，不需要使用索引来访问
  - `oid` 以 `0` 结尾，`1.3.6.1.2.1.1.3.0`
  - 由唯一的 oid 标识，可使用 SNMP GET 操作之间获取值
  - 常用于表示设备的全局性能指标，例如系统描述、系统运行时间等
- **表量 (Tabular)，表格, OID 以`数字索引`结尾**
  - 表格对象，表示一组相关的数据，多行多列结构
  - 每一行表示一个实例，每一列表示一个属性或字段
  - 表格由 oid 来唯一标识，每一行的实例可以通过在表格 oid 的末尾追加索引来标识
  - 可以通过 SNMP `GETNEXT` 或 `GETBULK` 来进行操作



## 1.2 查询

SNMP查询：NMS主动向 SNMP Agent 发送查询请求，SNMP Agent 接收到查询请求后，通过 MIB 表完成相应指令，并将结果反馈给 NMS。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-op-get.png)  

三种查询操作：

- `Get`：从 SNMP Agent 获取一个或多个参数值
- `GetNext`：从 SNMP Agent 获取一个或多个参数的下一个参数值
- `GetBulk`：基于 `GetNext` 实现，相当于执行多次 `GetNext` 操作。在 NMS 上可以设置被管理对象在一次 `GetBulk` 报文交互时，执行 `GetNext` 操作的次数



## 1.3 设置

SNMP 设置：NMS主动向 SNMP Agent 发送对设备进行 Set 操作的请求。SNMP Agent 接收到 Set 请求后，通过 MIB 表完成相应指令，并将结果反馈给 NMS。

SNMP 设置只有一种 Set，NMS 使用该操作可设置 SNMP Agent 中的一个或多个参数值。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-op-set.png)  



## 1.4 Traps

SNMP Traps：指 SNMP Agent 主动将设备产生的告警或事件上报给 NMS，以便网络管理员及时了解设备当前的运行状态。

SNMP Traps 有两种方式：

- Trap
- Inform，SNMPv1不支持，与 Trap相比，SNMP Agent 通过 Inform 向 NMS 发送告警或事件后，NMS 需要回复 InformResponse 进行确认

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-op-traps.png)  



## 1.5 端口号

SNMP 报文是普通的 UDP 报文，协议中规定有两个默认端口号：

- 161：NMS 发送 `Get`、`GetNext`、`GetBulk` 和 `Set` 操作请求及 SNMP Agent 响应这些请求时，使用该端口号。
- 162：SNMP Agent 向 NMS 发送 Trap 或 Inform 时，使用该端口号。



# 2. NetSNMP

`NetSNMP` 是实现 SNMP 协议的 Library 库，提供支持 SNMP 的一套应用程序和开发库，包含代理端软件和管理端查询工具。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-netsnmp.jpg)

## 2.1 账号管理

`net-snmp-create-v3-user [-ro] [-A MD5|SHA] [-a authpass] [-x privpass] [-X DES|AES] username`

参数说明：

- `-ro`: 指定用户为只读权限（默认是读写权限）。

- `-a authpass`: 设置认证密码（用于认证协议，如 MD5 或 SHA）。

- `-x privpass`: 设置加密密码（用于加密协议，如 DES 或 AES）。

- `-X DES|AES`: 指定加密协议，DES 或 AES（默认是 DES）。

- `username`: 要创建的 SNMPv3 用户名。



创建账号：

```bash
# 停止服务
systemctl stop snmpd

# 创建用户
net-snmp-create-v3-user -ro -A MD5 -a eli@Auth -X DES -x eli@Priv eli

# 启动服务
systemctl start snmpd
```



## 2.2 获取指标

`snmpwalk` 和 `snmpbulkwalk` 的区别：

- `snmpwalk` 从指定的根 OID 开始，按照字典顺序逐步获取下一个 OID 的值，直至遍历完整个 MIB 树或达到指定的终止条件。
- `snmpbulkwalk` 更高效的遍历工具，它使用率 SNMP 的 `BulkWalk` 操作，允许一次性获取多个 OID 的值，减少往返的 SNMP 请求次数。



```bash
# 获取hostname
snmpget -v3 -l authPriv -u eli -a MD5 -A 'eli@Auth' -x DES -X 'eli@Priv' 192.168.3.100 .1.3.6.1.2.1.1.5.0

# 获取扩展项
snmpwalk -v3 -u eli -l auth -a MD5 -A eli@Auth -X eli@Priv 172.16.7.181 NET-SNMP-EXTEND-MIB::nsExtendOutputFull

# 获取dskPath
snmpwalk -v3 -u eli -l auth -a MD5 -A eli@Auth -X eli@Priv 172.16.7.181 .1.3.6.1.4.1.2021.9.1.2
```



# 3. SNMP Exporter

## 3.1 与 NetSNMP 的关系

`NetSNMP` 和 `SNMP Exporter` 以及配置生成器之间的关系如下：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/snmp-netsnmp-exporter.jpg)  

`Telegraf` 支持 `NetSNMP` 和 `gosmi`，默认使用 `gosmi`，而 `SNMP Exporter` 默认使用 `NetSNMP` 库，暂不支持 `gosmi`.



SNMP Exporter 遍历方式：

- SNMP v1：默认使用 `snmpwalk`
- v2c 或 v3：默认使用 `snmpbulkwalk`



## 3.2 部署

### 3.2.1 docker

```bash
mkdir -p /opt/snmp_exporter/conf
cd /opt/snmp_exporter

# 启动配置
cat > docker-compose.yml <<EOF
services:
  snmp_exporter:
    image: prom/snmp-exporter:v0.28.0
    volumes:
      - /opt/snmp_exporter/conf:/etc/snmp_exporter
    ports:
      - "9116:9116"
      - "161:161/udp"
    restart: always
    command: 
      - "--config.file=/etc/snmp_exporter/snmp_*.yml"
EOF

# 启动
docker-compose up -d
```



### 3.2.2 二进制

先编译源码：

```bash
# Debian-based distributions.
sudo apt-get install unzip build-essential libsnmp-dev
# Redhat-based distributions.
sudo yum install gcc make net-snmp net-snmp-utils net-snmp-libs net-snmp-devel

# 下载源码
cd /opt/gosrc
git clone https://github.com/prometheus/snmp_exporter.git

# 编译
cd snmp_exporter
go env -w GO111MODULE=on
go env -w GOPROXY=https://goproxy.cn,direct
make build
```



然后再按如下步骤安装：

```bash
mkdir -p /opt/snmp_exporter/conf
cd /opt/snmp_exporter
cp /opt/gosrc/snmp_exporter/snmp_exporter .

# 修改目录属主
useradd  -s /sbin/nologin -M snmp_exporter
chown -R snmp_exporter:snmp_exporter /opt/snmp_exporter/

# 启动配置
cat <<EOF > /etc/systemd/system/snmp_exporter.service
[Unit]
Description=Prometheus SNMP Exporter
After=network-online.target

[Service]
User=snmp_exporter
Group=snmp_exporter
Restart=on-failure
Type=simple
ExecStart=/opt/snmp_exporter/snmp_exporter --config.file conf/snmp_*.yml
WorkingDirectory=/opt/snmp_exporter/

[Install]
WantedBy=multi-user.target
EOF

# 启动
systemctl start snmp_exporter
systemctl restart snmp_exporter
systemctl stop snmp_exporter
systemctl status snmp_exporter
systemctl enable snmp_exporter
```



## 3.3 配置生成器

### 3.3.1 编译源码

```bash
cd generator

# 编译
make generator

# 携带下载 mibs
make generator mibs
```



### 3.3.2 生成配置

**环境变量**：`export MIBDIRS=/xxx/mibs`：mibs 库文件环境变量，可代替 args 参数 `-m`

**命令行**：`./generator [<flags>] <command> [<args> ...]`

`args` 参数：

- `-m`：指定 mibs 库文件目录，可同时指定多个，不指定时使用系统 mibs
- `-g`：待读取的生成器配置文件，默认 generator.yml
- `-o`：生成的配置文件

`command`:

- `generate`：生成采集配置
- `parse_errors`：输出 mibs 解析错误
- `dump`：导出解析到的 oids

`flags` 参数：

- `--fail-on-parse-errors`    如果存在 MIB 解析错误，则以非空的状态退出
- `--snmp.mibopts`        切换控制 MIB 解析的各种默认设置
  - u           允许在MIB符号中使用下划线
  - c            禁止使用 "--" 来终止注释
  - d           保存MIB对象的描述
  - e           当MIB符号冲突时禁用错误
  - w          MIB符号冲突时启用警告
  - W         MIB符号冲突时启用详细警告
  - R          替换最新模块中的MIB符号
- `--log.level=info`        输出日志信息等级 debug, info, warn, error
- `--log.format=logfmt`       输出日志格式 logfmt, json
- `--parse_errors`          调试，打印 NetSNMP 输出的解析错误
- `--dump`                         调试，转储已解析和准备的 MIB



示例：

```bash
# 生成采集配置
./generator generate \
  -m /tmp/deviceFamilyMibs \
  -m /tmp/sharedMibs \
  -g /tmp/generator.yml \
  -o /tmp/snmp.yml
  
# 测试 mibs 库是否正确
./generator30 parse_errors -m huawei/mibs/switch/
```



### 3.3.3 配置说明

```yaml
auths:
  auth_name:
    version: 2  # SNMP version to use. Defaults to 2.
                # 1 will use GETNEXT, 2 and 3 use GETBULK.

    # Community string is used with SNMP v1 and v2. Defaults to "public".
    community: public

    # v3 has different and more complex settings.
    # Which are required depends on the security_level.
    # The equivalent options on NetSNMP commands like snmpbulkwalk
    # and snmpget are also listed. See snmpcmd(1).
    username: user  # Required, no default. -u option to NetSNMP.
    security_level: noAuthNoPriv  # Defaults to noAuthNoPriv. -l option to NetSNMP.
                                  # Can be noAuthNoPriv, authNoPriv or authPriv.
    password: pass  # Has no default. Also known as authKey, -A option to NetSNMP.
                    # Required if security_level is authNoPriv or authPriv.
    auth_protocol: MD5  # MD5, SHA, SHA224, SHA256, SHA384, or SHA512. Defaults to MD5. -a option to NetSNMP.
                        # Used if security_level is authNoPriv or authPriv.
    priv_protocol: DES  # DES, AES, AES192, AES256, AES192C, or AES256C. Defaults to DES. -x option to NetSNMP.
                        # Used if security_level is authPriv.
    priv_password: otherPass # Has no default. Also known as privKey, -X option to NetSNMP.
                             # Required if security_level is authPriv.
    context_name: context # Has no default. -n option to NetSNMP.
                          # Required if context is configured on the device.

modules:
  module_name:  # The module name. You can have as many modules as you want.
    # List of OIDs to walk. Can also be SNMP object names or specific instances.
    # Object names can be fully-qualified with the MIB name separated by `::`.
    walk:
      - 1.3.6.1.2.1.2              # Same as "interfaces"
      - "SNMPv2-MIB::sysUpTime"    # Same as "1.3.6.1.2.1.1.3"
      - 1.3.6.1.2.1.31.1.1.1.6.40  # Instance of "ifHCInOctets" with index "40"
      - 1.3.6.1.2.1.2.2.1.4        # Same as ifMtu (used for filter example)
      - bsnDot11EssSsid            # Same as 1.3.6.1.4.1.14179.2.1.1.1.2 (used for filter example)

    max_repetitions: 25  # How many objects to request with GET/GETBULK, defaults to 25.
                         # May need to be reduced for buggy devices.
    retries: 3   # How many times to retry a failed request, defaults to 3.
    timeout: 5s  # Timeout for each individual SNMP request, defaults to 5s.

    allow_nonincreasing_oids: false # Do not check whether the returned OIDs are increasing, defaults to false
                                    # Some agents return OIDs out of order, but can complete the walk anyway.
                                    # -Cc option of NetSNMP

    use_unconnected_udp_socket: false # Use a unconnected udp socket, defaults to false
                                      # Some multi-homed network gear isn't smart enough to send SNMP responses
                                      # from the address it received the requests on. To work around that,
                                      # we can open unconnected UDP socket and use sendto/recvfrom

    lookups:  # Optional list of lookups to perform.
              # The default for `keep_source_indexes` is false. Indexes must be unique for this option to be used.

      # If the index of a table is bsnDot11EssIndex, usually that'd be the label
      # on the resulting metrics from that table. Instead, use the index to
      # lookup the bsnDot11EssSsid table entry and create a bsnDot11EssSsid label
      # with that value.
      - source_indexes: [bsnDot11EssIndex]
        lookup: bsnDot11EssSsid
        drop_source_indexes: false  # If true, delete source index labels for this lookup.
                                    # This avoids label clutter when the new index is unique.

      # It is also possible to chain lookups or use multiple labels to gather label values.
      # This might be helpful to resolve multiple index labels to a proper human readable label.
      # Please be aware that ordering matters here.

      # In this example, we first do a lookup to get the `cbQosConfigIndex` as another label.
      - source_indexes: [cbQosPolicyIndex, cbQosObjectsIndex]
        lookup: cbQosConfigIndex
      # Using the newly added label, we have another lookup to fetch the `cbQosCMName` based on `cbQosConfigIndex`.
      - source_indexes: [cbQosConfigIndex]
        lookup: cbQosCMName

    overrides: # Allows for per-module overrides of bits of MIBs
      metricName:
        ignore: true # Drops the metric from the output.
        help: "string" # Override the generated HELP text provided by the MIB Description.
        name: "string" # Override the OID name provided in the MIB Description.
        regex_extracts:
          Temp: # A new metric will be created appending this to the metricName to become metricNameTemp.
            - regex: '(.*)' # Regex to extract a value from the returned SNMP walks's value.
              value: '$1' # The result will be parsed as a float64, defaults to $1.
          Status:
            - regex: '.*Example'
              value: '1' # The first entry whose regex matches and whose value parses wins.
            - regex: '.*'
              value: '0'
        datetime_pattern: # Used if type = ParseDateAndTime. Uses the strptime format (See: man 3 strptime)
        offset: 1.0 # Add the value to the same. Applied after scale.
        scale: 1.0 # Scale the value of the sample by this value.
        type: DisplayString # Override the metric type, possible types are:
                             #   gauge:   An integer with type gauge.
                             #   counter: An integer with type counter.
                             #   OctetString: A bit string, rendered as 0xff34.
                             #   DateAndTime: An RFC 2579 DateAndTime byte sequence. If the device has no time zone data, UTC is used.
                             #   ParseDateAndTime: Parse a DisplayString and return the timestamp. See datetime_pattern config option
                             #   NTPTimeStamp: Parse the NTP timestamp (RFC-1305, March 1992, Section 3.1) and return Unix timestamp as float.
                             #   DisplayString: An ASCII or UTF-8 string.
                             #   PhysAddress48: A 48 bit MAC address, rendered as 00:01:02:03:04:ff.
                             #   Float: A 32 bit floating-point value with type gauge.
                             #   Double: A 64 bit floating-point value with type gauge.
                             #   InetAddressIPv4: An IPv4 address, rendered as 192.0.0.8.
                             #   InetAddressIPv6: An IPv6 address, rendered as 0102:0304:0506:0708:090A:0B0C:0D0E:0F10.
                             #   InetAddress: An InetAddress per RFC 4001. Must be preceded by an InetAddressType.
                             #   InetAddressMissingSize: An InetAddress that violates section 4.1 of RFC 4001 by
                             #       not having the size in the index. Must be preceded by an InetAddressType.
                             #   EnumAsInfo: An enum for which a single timeseries is created. Good for constant values.
                             #   EnumAsStateSet: An enum with a time series per state. Good for variable low-cardinality enums.
                             #   Bits: An RFC 2578 BITS construct, which produces a StateSet with a time series per bit.

    filters: # Define filters to collect only a subset of OID table indices
      static: # static filters are handled in the generator. They will convert walks to multiple gets with the specified indices
              # in the resulting snmp.yml output.
              # the index filter will reduce a walk of a table to only the defined indices to get
              # If one of the target OIDs is used in a lookup, the filter will apply ALL tables using this lookup
              # For a network switch, this could be used to collect a subset of interfaces such as uplinks
              # For a router, this could be used to collect all real ports but not vlans and other virtual interfaces
              # Specifying ifAlias or ifName if they are used in lookups with ifIndex will apply to the filter to
              # all the OIDs that depend on the lookup, such as ifSpeed, ifInHcOctets, etc.
              # This feature applies to any table(s) OIDs using a common index
        - targets:
          - bsnDot11EssSsid
          indices: ["2","3","4"]  # List of interface indices to get

      dynamic: # dynamic filters are handed by the snmp exporter. The generator will simply pass on the configuration in the snmp.yml.
               # The exporter will do a snmp walk of the oid and will restrict snmp walk made on the targets
               # to the index matching the value in the values list.
               # This would be typically used to specify a filter for interfaces with a certain name in ifAlias, ifSpeed or admin status.
               # For example, only get interfaces that a gig and faster, or get interfaces that are named Up or interfaces that are admin Up
        - oid: 1.3.6.1.2.1.2.2.1.7
          targets:
            - "1.3.6.1.2.1.2.2.1.4"
          values: ["1", "2"]
```



#### 3.3.3.1 auths 认证

```bash
auths:
  auth_v2:
    version: 2
    community: public
    
  auth_v3:
    version: 3
    username: eli 
    security_level: authPriv
    password: 'eli@Auth'
    auth_protocol: MD5
    priv_protocol: DES
    priv_password: 'eli@Priv'
```



#### 3.3.3.2 modules 指标

```yaml
modules:
  # 指标模块名 可自定义名称 可定义多个模块 每个模块负责监控一个特定设备或服务
  module_name:
    # SNMP Exporter 遍历 Walk 操作并获取相关数据
    # 这些 OID 可以是原始的数字表示法 也可以是 SNMP 对象的名称
    walk:
      - 1.3.6.1.2.1.2
      - sysUpTime
      - 1.3.6.1.2.1.31.1.1.1.6.40
      - 1.3.6.1.2.1.2.2.1.4
      - bsnDot11EssSsid
    
    # SNMP 请求中一次性获取多少个对象的配置项
    max_repetitions: 25
    # 请求失败重试次数
    retries: 3
    # 每个 SNMP 请求的超时时间为 5 秒
    timeout: 5s
    
    # 具体的查找操作的定义 它执行了一个 OID 指标到标签的转换操作
    lookups:
      # 对表格对象的操作 以 bsnDot11EssIndex 为索引
      # 把 bsnDot11EssSsid 插入到遍历 walk oid 以 bsnDot11EssIndex 为索引的指标中
      - source_indexes: [bsnDot11EssIndex]
        lookup: bsnDot11EssSsid
        # 源索引不删除 bsnDot11EssIndex 保留
        drop_source_indexes: false
      
      # 通过链式查找（chaining lookups）或使用多个标签来生成标签值
      # 这样的配置为了解决多个索引标签并生成适当的易读标签
      # 下面案例就是通过 cbQosPolicyIndex, cbQosObjectsIndex 两个索引查找
      # 把 cbQosConfigIndex 插入到指标中，并通过 cbQosConfigIndex标签
      # 把 cbQosCMName 标签插入到指标中
      - source_indexes: [cbQosPolicyIndex, cbQosObjectsIndex]
        lookup: cbQosConfigIndex
      - source_indexes: [cbQosConfigIndex]
        lookup: cbQosCMName

    # 针对指标的覆盖与否操作 以及指标的数据类型指定 避免因为编码问题导致错误
    overrides:
      # 指标名称 一般都以 oid 对象的名称为标准
      metricName:
        # 可以将metricName指标从输出中删除 即不进行收集和暴露
        ignore: true
        # regex_extracts 是一种用于通过正则表达式从 SNMP 返回的原始文本中提取信息的配置选项
        # 这个功能允许你从 SNMP 设备返回的原始数据中抽取感兴趣的部分 以便更好地组织和标记指标
        regex_extracts:
          # 创建一个新指标 **metricNameTemp**
          Temp:
            # 正则表达式从返回的 SNMP walks 值中提取值
            - regex: '(.*)'
              # 结果将被解析为 float64 默认为 $1
              value: '$1'
          # 创建一个新指标 metricNameStatus
          Status:
            - regex: '.*Example'
              value: '1'
            - regex: '.*'
              value: '0'
        # metricName 指标的值在原有基础上增加1.0  
        offset: 1.0
        # metricName 指标的值在原有基础上乘上1.0 
        scale: 1.0
        # 覆盖指标类型
        type: DisplayString
    
    # 定义过滤器 仅收集 OID 表索引的子集 允许在生成指标之前应用条件和转换
    filters:
      static:
        - targets:
          - bsnDot11EssSsid
          # 获取接口索引列表
          indices: ["2","3","4"]

      dynamic:
        - oid: 1.3.6.1.2.1.2.2.1.7
          targets:
            - "1.3.6.1.2.1.2.2.1.4"
          values: ["1", "2"]
```



字段说明：

- walk：需要采集的指标 oid 或对象名称

- `lookups` ：主要利用在有索引的表量中。利用源索引标签生成指标标签，但标签必选是通过 OID 查找到的；另一种用途就是如果表量有多个索引，可以根据多个索引生成可读性更好的索引标签，以达到索引标签的唯一性。

  ```yaml
  lookups:
    # 通过接口表中唯一索引标签 ifIndex 把当前查找的指标 ifAlias 作为标签插入当前表量指标中
    - source_indexes: [ifIndex]
      lookup: ifAlias
    - source_indexes: [ifIndex]
      lookup: ifName
  ```

- `overrides` ：主要利用在有索引的表量中。指定当前抓取的指标是否显示，以及指定抓取的指标数据类型，通常结合 `lookups` 一起使用：

  ```yaml
  # `ifAlias` 和 `ifName` 已经作为标签插入表量指标中，一般情况下不再需要以指标形式存在，因此直接忽略该指标再暴露出来。
  overrides:
    ifAlias:
      ignore: true
    ifName:
      ignore: true
      type: DisplayString
    powerState:
      type: DisplayString
      ignore: false
      regex_extracts:
        '':
          - regex: 'normal'
            value: '1'
          - regex: '.*'
            value: '0'
    infTransceiverTemperature:
      type: DisplayString
      ignore: false
      regex_extracts:
        '':
          - regex: '(.*)'
            value: '$1'
  ```

  - `ignore`：当设置为 `true` 时，输出中将不再暴露该指标信息，而是以标签形式插入已存在的索引表指标中

  - `offset`：在原指标值基础上增加或减少相应的值，一般应用在零点调整

  - `scale`：在原指标值基础上的倍数，一般应用在单位调整。比如 `sysUptime` 以时间戳 `Timeticks` 形式存在，单位百分之一秒，在此可以乘以100来达到以秒为单位

  - `type`：覆盖数据类型

    | 数据类型               | 含义                                                         |
    | ---------------------- | ------------------------------------------------------------ |
    | gauge                  | 用于表示带有 gauge 类型的整数。在 Prometheus 中，gauge 类型的指标代表瞬时值，可以任意增加或减少。 |
    | counter                | 用于表示带有 counter 类型的整数。在 Prometheus 中，counter 类型的指标代表一个随时间递增的计数器，通常用于表示计数或计时的值。 |
    | OctetString            | 用于表示 RFC 2578 中的 OctetString 数据类型，通常渲染为 0xff34。 |
    | DateAndTime            | 用于表示 RFC 2579 中的 DateAndTime 字节序列，通常用于表示日期和时间信息。 |
    | DisplayString          | 用于表示 ASCII 或 UTF-8 字符串。                             |
    | PhysAddress48          | 用于表示 48 位 MAC 地址，通常渲染为 00:01:02:03:04:ff。      |
    | Float                  | 用于表示带有 gauge 类型的 32 位浮点值。                      |
    | Double                 | 用于表示带有 gauge 类型的 64 位浮点值。                      |
    | InetAddressIPv4        | 用于表示 IPv4 地址，通常渲染为 192.168.1.1。                 |
    | InetAddressIPv6        | 用于表示 IPv6 地址，通常渲染为 0102:0304:0506:0708:090A:0B0C:0D0E:0F10。 |
    | InetAddress            | 用于表示 RFC 4001 中的 InetAddress。必须由 InetAddressType 预先引导。 |
    | InetAddressMissingSize | 用于表示违反 RFC 4001 第 4.1 节规定的 InetAddress，没有在索引中包含大小信息，必须由 InetAddressType 预先引导。 |
    | EnumAsInfo             | 用于表示单个时间序列的枚举，适用于常量值。                   |
    | EnumAsStateSet         | 用于表示每个状态一个时间序列的枚举，适用于可变的低基数枚举。 |
    | Bits                   | 用于表示 RFC 2578 中的 BITS 结构，生成一个 StateSet，每个位都有一个时间序列。 |

- `filters`：过滤器，对表索引的指标进行过滤
  - `static`：静态过滤器由 generator 处理。
    - 生成器将 `oid walk` 转换为具有指定索引的多个 `GET` 操作，并在生成的 `snmp.yml` 输出中进行处理。
    - 索引过滤将使表的 walk 仅限于获取定义的索引。
    - 如果目标 oid 中的一个用于查找，过滤器将应用于该查找的所有表
    - 示例：
      - 交换机收集部分接口，如上行链路；
      - 路由器收集真实端口，但不包括 VLAN 和其它虚拟接口；
      - 如果在与 `ifIndex` 进行查找的情况下指定了 `ifAlias` 或 `ifName` ，对于依赖 `ifIndex` 索引的 oid (`ifSpeed`、`ifInHcOctets` 等）都会应用该过滤器。
  - `dynamic`：动态过滤器，由 SNMP Exporter 处理
    - 生成器仅仅将配置传递到 `snmp.yml` 中，而 SNMP Exporter 将对 oid 进行 SNMP walk，并将 walk 限制在与值列表中的值匹配的索引上
    - 通常用于指定接口的特定名称、速度或管理员状态的过滤条件。
    - 示例：仅获取千兆速度及以上的接口，或者获取名称为 `up` 或管理员状态为 `up` 的接口

```yaml
filters:
  dynamic:
    # 这里可以根据接口管理状态动态剔除手动 shutdown 接口的指标
    - oid: 1.3.6.1.2.1.2.2.1.7
      targets:
        - "1.3.6.1.2.1.2.2.1.2"
        - "1.3.6.1.2.1.2.2.1.7"
        - "1.3.6.1.2.1.2.2.1.8"
        - "1.3.6.1.2.1.31.1.1.1.15"
      values: ["1", "2"]
```



### 3.3.4 工程化

| 品牌  | 品类   | MIB文件目录          | 生成器配置文件                | 采集配置文件             |
| ----- | ------ | -------------------- | ----------------------------- | ------------------------ |
| 华为  | 防火墙 | huawei/mibs/firewall | generator_huawei_firewall.yml | snmp_huawei_firewall.yml |
|       | 交换机 | huawei/mibs/switch   | generator_huawei_switch.yml   | snmp_huawei_switch.yml   |
| 华三  | 交换机 | h3c/mibs/switch      | generator_h3c_switch.yml      | snmp_h3c_switch.yml      |
|       |        |                      |                               |                          |
| Linux | 服务器 | linux/mibs           | generator_linux.yml           | snmp_linux.yml           |
|       |        |                      |                               |                          |



生成采集配置文件：

```bash
## 1.1 服务器和工作站
./generator generate -m linux/mibs -g linux/generator_linux.yml -o /opt/snmp_exporter/conf/snmp_linux.yml

## 1.2 华为交换机
./generator generate -m huawei/mibs/switch -g huawei/generator_huawei_switch.yml -o /opt/snmp_exporter/conf/snmp_huawei_switch.yml

## 1.3 华为防火墙
./generator generate -m huawei/mibs/firewall -g huawei/generator_huawei_firewall.yml -o /opt/snmp_exporter/conf/snmp_huawei_firewall.yml

## 1.4 华三交换机
./generator30 generate -m h3c/mibs/switch -g h3c/generator_h3c_switch.yml -o /opt/snmp_exporter/conf/snmp_h3c_switch.yml
```































