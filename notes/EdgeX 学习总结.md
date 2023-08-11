# 1. 简介

EdgeX是LF Edge主持的开源项目，目的是在IoT边缘计算场景下构建一个与供应商无关（vendor-neutral）的通用框架。核心是一个交互框架，承载于与硬件和操作系统无关的（a full hardware- and OS-agnostic）参考软件平台，以实现即插即用（plug-and-play）的组件生态系统，从而统一市场并加速物联网解决方案的部署。



## 1.1 系统架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-coreservices.png)

EdgeX 架构设计遵循的指导原则：

- 技术中立：硬件、操作系统、南向协议无关。服务可以部署在边缘计算节点、雾计算节点、云端等地方
- 灵活性：可升级、替换任何一个子服务；可更加硬件的性能高低进行伸缩
- 存储转发：在断网离线的情况下，支持本地存储转发功能
- 智能分析：可在边缘侧进行智能分析，从而降低反应延迟、减少网络流量和云端存储成本。
- 应用场景支持：支持 Greenfield 和 Brownfield 两个环境下的应用场景
- 安全、易于管理



补充说明：

Greenfield：在全新的环境上从头开发的软件项目

Brownfield：在遗留系统上开发和部署新的软件系统，或需要与已经在使用的其他软件共存



EdgeX 把边缘计算任务分到若干个软件模块上完成，每个软件模块负责一个功能内聚的任务。不同软件模块之间通过预定义的API进行交互。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-sys-components.png) 

- **设备服务**：数据采集；设备控制
- **核心服务**：数据分析、存储和转发；控制命令下发
- **导出服务**：上传数据到云端或第三方系统；接收控制命令并转发给核心服务
- **支持服务**：日志记录、任务调度、数据清理、规则引擎和告警通知
- 安全服务：数据保护；安全运行
- 管理服务：服务启停；监控监控等

服务间通信交互：RESTful API 接口；有的服务为提高性能，通过消息总线交互数据



## 1.2 微服务

微服务分层：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-microservice-arch.png)

微服务功能：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-microservice-func.png)

微服务集成：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-neutral-framework.png)



### 1.2.1 Core Services

核心服务层提供 EdgeX 南北向的中介，是 EdgeX 功能的核心。它涉及事物连接、传感器数据收集、edgex 配置存储。

核心服务层包含：

- **Core Data**：持久化存储和关联管理从南向收集的数据

  设备数据上送的两种方式：

  - 消息总线

  ​	![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-coredata-subscriber.png)

  - Restful-API

  ​	![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-coredata-restendpoint.png)

- **Command**：使北向发往南向的请求简便并可以受控制的服务

  命令主要来自：

  - 其他微服务命令（本地边缘数据分析、规则引擎微服务）
  - 其他应用命令（系统管理agent关闭一个设备）
  - 外部系统命令（修改一系列设备配置文件）

  提供统一规范方式与设备通信：

  - GET命令：获取设备数据
  - PUT命令：下发 action 或下发配置数据

  命令微服务通过设备服务与设备交互，不直接与设备交互

- **Metadata**：元数据服务主要包括管理**设备配置文件，包括设备信息、设备数据结构类型和设备命令**。

  每个被 edgex 管理的设备，都在元数据有关联的ID，设备关联设备配置文件、设备服务。

  元数据微服务管理设备服务信息，其他微服务通过设备服务与设备交互。

  设备服务，对应一个特定设备协议，比如modbus设备服务，负责管理所有modbus设备。

  元数据服务是唯一能获取设备、设备配置、设备服务的微服务，数据本地存储交互通过REST API进行

  ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-metadata-arch.png)



- **Registry and Configuration**：向其他微服务提供系统和微服务配置属性信息(既初始化值存储库)

  对于注册服务，采用ping各微服务方式来探活，每 10s 一次。配置发送变更，本服务会及时通知对应微服务，配置信息会覆盖微服务内配置信息，支持动态切换环境，满足微服务架构动态扩展需求。在配置注册微服务不可用时，微服务可脱离本服务，使用自身内嵌配置启动。



### 1.2.2 Supporting Services

支持服务层包含广泛的边缘侧分析(本地分析)的微服务。日志、计划、数据清洗等常用软件应用由该层提供，这些服务通常以来一些核心服务。所有的支持层服务都是可选的，即支持层服务是非必须的。

- **Rule Engine**：本地分析的参考实现。在边缘侧基于 edgex 实例收集的传感器数据，执行 if-then 条件驱动。当前版本的实现基于 EMQ kuiper

  规则引擎提供了一种边缘事件触发机制，监控边缘设备数据。符合规则，查封行为，通过命令服务下发指令。

  ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ruleengine-arch.png)

  eKuiper 规则引擎组件：

  - Source：流数据源，比如来自 MQTT 服务端。在edgex中。数据源是一个通过ZeroMQ或MQTT实现的edgex消息总线
  - SQL：被处理的特定业务逻辑，eKuiper 提供数据抽取、过滤和转换SQL
  - Sink：用于发送分析结果到一个特定的目标上，比如发送分析结果到命令服务或者云端的 MQTT broker

  数据交互：

  ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ruleengine-data.png)

- **Scheduling**：一个内部时钟，可以在指定时间，通过 REST 调用 EdgeX 服务 API URL 操作任何 EdgeX 服务

  轻量型的调度服务、只负责定时清理设备数据。默认没30分钟执行一次，调用 core-data API 执行清理操作

- **Alerts and Notifications**：为 EdgeX 提供预警和通知的中心设施服务

  负责在设备发生故障时，生成告警，然后将告警发生到目的email或REST回调。

  告警类型：

  - NORMAL：等下消息调度器统一处理
  - CRITICAL：立即发送通知到分发协调组

  ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-notification-arch.png)

  左边：API提供给其他服务或应用调用，能通过 REST、AMQP、MQTT 等协议，目前支持 REST

  右边：消息订阅者通过订阅 RESTful，订阅特定类型通知。消息接收者，在事件发生时，可通过 SMS、email、REST callback，AMQP、MQTT等



### 1.2.3 Application Services

应该服务从 EdgeX 提取、处理、转换和发送感测数据到其他端点或进程的方式。EdgeX 提供了将数据导出到 Amazon Iot Hub，Google IoT Core, Azure IoT Hub，HTTP(s), MQTT(s)的示例

App service 基于管道思想，按顺序处理消息，包含：触发器(数据源)、过滤、转换、压缩、加密，结束后通过 MQTT/HTTP发出。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-app-service-pipeline.png)

- EdgeX 内部数据导出服务，当需要把边缘数据和智能分析传输到云平台时，将使用该功能
- 允许第三方应用，在EdgeX 内注册为核心数据的接收者



### 1.2.4 Device Servcies

设备服务连接 EdgeX 和 真实的事物，如传感器设备等。设备服务提供 EdgeX 和物理设备之间的抽象，即：设备服务“包装”协议通信代码、设备驱动程序(固件)和实际设备。

设备服务通过 device service SDK创建，SDK 提供了所有设备服务所需的通用基础功能

- Device Service SDK
- Device Profile
- 现有服务协议：Modbus, MQTT, BLE, BACnet, REST, ONVIF, SNMP等

设备服务功能：

- 负责与边缘设备进行交互，支持同时为多个设备进行服务
- 将采集的数据转换为 EdgeX 通用的数据结构并上送核心服务



设备服务的主要任务时完成设备数据的采集，并发送到 edgex 的 pipeline.

数据上报的两种类型：

- **被动采集式：modbus属典型的被动采集，需要下发采集/读指令，然后收取响应数据**
- **主动上报式：一些TCP协议的气象设备或MQTT设备，具备以固定的频率向指定目标发送数据的能力**

数据处理：

- 被动采集的设备：如果要融入 edgex 体系，需要与其内部的机制进行对接
- 主动上报的设备：只要做好接收和处理，然后发送到 edgex 的 pipeline 即可



### 1.2.5 Security

保护 EdgeX 管理的设备、传感器及其他 IoT 对象的数据和控制命令安全，基于 “vendor-neutral open source software platform at the edge of the network”，EdgeX 安全功能也建立在开放接口和可插拔、可更换模块的基础上。

- Security Store：保存 EdgeX 密钥
- API Gateway Serves：反向代理，限制 API 访问



### 1.2.6 System Management

对 EdgeX 服务状态进行管理，提供安装、升级、启动、停止和监控 EdgeX 微服务、BIOS固件、操作系统及其他相关软件



## 1.3 部署模式

支持多种部署方式

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-deploy-mode.png)

**场景一**：现场靠近设备侧部署设备服务，用于采集设备数据和执行控制命令。核心服务、分析服务和导出服务则部署在云端。

**场景二**：现场靠近设备侧部署设备服务，其余服务部署在网关上，网关将数据再发送到云端。

**场景三**：设备服务、核心服务、导出服务和分析服务都部署在边缘侧。

**场景四**：设备服务和核心服务部署在网关上，导出服务和分析服务部署在雾计算节点上，分析后的数据由雾计算节点发送到云端。

**场景五**：设备服务部署在现场嵌入式单片机上，核心服务、分析服务和导出服务部署在雾计算节点上，雾计算节点再连到云端。



# 2. 部署

## 2.1 基础软件

```bash
apt install docker.io

curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
```



## 2.2 EdgeX

仓库地址：https://github.com/edgexfoundry/edgex-compose

暂定版本：jakarta，未带安全认证，AMD64

```bash
mkdir edgex && cd $_
curl -L https://raw.githubusercontent.com/edgexfoundry/edgex-compose/jakarta/docker-compose-no-secty-with-app-sample.yml -o docker-compose.yaml

# 拉取镜像
docker-compose pull

# 服务列表
docker-compose config --services

# 以daemon模式启动
docker-compose up -d

# 容器运行状态
docker-compose ps

# 容器日志
docker-compose logs -f consul

# 停止并删除
docker-compose down
```



## 2.3 服务

### 2.3.1 服务列表

| EdgeX Microservice         | Docker Compose Service | Container Name              | Port  | Ping URL                        |
| :------------------------- | :--------------------- | :-------------------------- | :---- | :------------------------------ |
| Core Data                  | data                   | edgex-core-data             | 59880 | http://localhost:59880/api/v2/ping |
| Metadata              | metadata               | edgex-core-metadata         | 59881 | http://localhost:59881/api/v2/ping |
| Command               | command                | edgex-core-command          | 59882 | http://localhost:59882/api/v2/ping |
| Registry and Configuration | consul | edgex-core-consul | 8500 | -- |
|                            |                        |                             |       |                                 |
| Rules Engine               | rulesengine            | edgex-kuiper | 59720 | -- |
| Alerts and Notifications | notifications          | edgex-support-notifications | 59860 | http://localhost:59860/api/v2/ping |
| Scheduling       | scheduler              | edgex-support-scheduler     | 59861 | http://localhost:59861/api/v2/ping |
|                            |                        |                             |       |                                 |
| System Management |    system                    |                    edgex-sys-mgmt-agent         | 58890 |http://localhost:58890/api/v2/ping|
|                            |                        |                             |       |                                 |
| Virtual Device Service     | device-virtual         | edgex-device-virtual        | 59900 | http://localhost:59900/api/v2/ping |
| Device Restful | device-rest        | edgex-device-rest        | 59986 | http://localhost:59986/api/v2/ping |
|                            |                        |                             |       |                                 |
| Application Services | app-service-sample     | edgex-app-sample            | 59700 | http://localhost:59700/api/v2/ping |
|  | app-service-rules      | edgex-app-rules-engine      | 59701 | http://localhost:59701/api/v2/ping |
|                            |                        |                             |       |                                    |
| Redis | database               | edgex-redis | 6379 | - |
| WebUI | ui | edgex-ui-go | 4000 | - |



### 2.3.2 服务注册

http://10.40.0.100:8500/ui



### 2.3.3 微服务信息

```bash
# 服务是否正常
curl -s http://localhost:59881/api/v2/ping | jq

# 服务配置信息
curl http://localhost:59881/api/v2/config

# 设备服务信息（deviceName、profileName、sourceName、valueType等），在cmd/res/devices/xxx.toml中定义
curl http://localhost:59880/api/v2/event/device/name/Random-Integer-Device

# 查询所有设备的 Commands（name、url、path、parameters、get or set等）
curl http://localhost:59882/api/v2/device/all

# 查询指定设备的 Commands（name、url、path、parameters、get or set等）
curl http://localhost:59882/api/v2/device/name/Random-Integer-Device

# 读取设备的 Command 值
curl -X GET http://localhost:59882/api/v2/device/name/Random-Integer-Device/Int16

# 修改设备的 Command 值
curl -X PUT -d '{"Int16":"42", "EnableRandomization_Int16":"false"}' http://localhost:59882/api/v2/device/name/Random-Integer-Device/WriteInt16Value

# 删除设备
curl -X DELETE http://localhost:59881/api/v2/device/name/Random-Integer-Device

# 删除设备profile
curl -X DELETE http://localhost:59881/api/v2/deviceprofile/name/Random-Integer-Device
```



# 3. 开发总结

## 3.1 环境准备

涉及较多的 CGO 支持，代码调试在 Linux 上进行

### 3.1.1 工具包安装

```bash
apt install pkg-config -y
apt install libzmq5 libczmq-dev -y
apt install make gcc -y
```



### 3.1.2 golang 安装

```bash
wget https://go.dev/dl/go1.18.5.linux-amd64.tar.gz

tar zxvf go1.18.5.linux-amd64.tar.gz -C /usr/local

cat >> /etc/profile <<EOF

export GOROOT=/usr/local/go
export PATH=\$GOROOT/bin:\$PATH

export GOPROXY=https://goproxy.io,direct
EOF

source /etc/profile
go version
```



## 3.2 设备服务

使用 `device-sdk-go` 示例创建新服务



### 3.2.1 新建工程

**Step 1**：下载 device-sdk-go

```bash
git clone --depth 1 --branch v2.1.1 https://github.com/edgexfoundry/device-sdk-go.git
```



**Step 2**：通过示例创建工程

```bash
mkdir -p device-simple/cmd

cp -rf ./device-sdk-go/example/cmd/* ./device-simple
cp ./device-sdk-go/Makefile ./device-simple
cp ./device-sdk-go/version.go ./device-simple/

mv ./device-simple/cmd/device-simple/* ./device-simple/cmd/
rm -rf ./device-simple/cmd/device-simple

# 工程目录
$ tree device-simple/
device-simple/
├── Dockerfile
├── Makefile
├── README.md
├── cmd
│   ├── main.go
│   └── res
│       ├── configuration.toml
│       ├── devices
│       │   ├── simple-device.json.example
│       │   └── simple-device.toml
│       ├── off.jpg
│       ├── on.png
│       ├── profiles
│       │   ├── Simple-Driver.json.example
│       │   └── Simple-Driver.yaml
│       └── provisionwatcher.json
├── config
│   └── configuration.go
├── driver
│   └── simpledriver.go
├── go.mod
├── go.sum
└── version.go

# 开启模块支持，并指定版本
go mod init xtwl.com/edgex-app/device-simple
go get github.com/edgexfoundry/device-sdk-go/v2@v2.1.1
go get github.com/edgexfoundry/go-mod-core-contracts/v2@v2.1.1
```



**Step 3**：调整文件中包的引用路径

替换 `github.com/edgexfoundry/device-sdk-go/example` 为 `xtwl.com/edgex-app/device-simple`

- `device-simple/cmd/main.go`
- `device-simple/driver/simpledriver.go`



**Step 4**：支撑包更新

```bash
go mod tidy
```



### 3.2.2 Device Profile

**设备资源属性和命令定义**，支持 yaml/yml 或 json 两种格式，`cmd/res/profiles/xxx-driver.yaml`

- deviceResources：设备资源属性

- deviceCommands：设备操作命令定义

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-device-command.png)

```yaml
apiVersion: "v2"
name: "Simple-Device"
manufacturer: "Simple Corp."
model: "SP-01"
labels:
  - "modbus"
description: "Example of Simple Device"

deviceResources:
  -
    name: "SwitchButton"
    isHidden: false
    description: "Switch On/Off."
    properties:
        valueType: "Bool"
        readWrite: "RW"
        defaultValue: "true"
  -
    name: "Image"
    isHidden: false
    description: "Visual representation of Switch state."
    properties:
        valueType: "Binary"
        readWrite: "R"
        mediaType: "image/jpeg"
  -
    name: "Xrotation"
    isHidden: true
    description: "X axis rotation rate"
    properties:
        valueType: "Int32"
        readWrite: "RW"
  -
    name: "Yrotation"
    isHidden: true
    description: "Y axis rotation rate"
    properties:
        valueType: "Int32"
        readWrite: "RW"
  -
    name: "Zrotation"
    isHidden: true
    description: "Z axis rotation rate"
    properties:
        valueType: "Int32"
        readWrite: "RW"
  -
    name: "StringArray"
    isHidden: false
    description: "String array"
    properties:
      valueType: "StringArray"
      readWrite: "RW"
  -
    name: "Uint8Array"
    isHidden: false
    description: "Unsigned 8bit array"
    properties:
        valueType: "Uint8Array"
        readWrite: "RW"
  -
    name: "Counter"
    isHidden: false
    description: "Counter data"
    properties:
      valueType: "Object"
      readWrite: "RW"

deviceCommands:
  -
    name: "Switch"
    isHidden: false
    readWrite: "RW"
    resourceOperations:
      - { deviceResource: "SwitchButton", defaultValue: "false" }
  -
    name: "Image"
    isHidden: false
    readWrite: "R"
    resourceOperations:
      - { deviceResource: "Image" }
  -
    name: "Rotation"
    isHidden: false
    readWrite: "RW"
    resourceOperations:
      - { deviceResource: "Xrotation", defaultValue: "0" }
      - { deviceResource: "Yrotation", defaultValue: "0" }
      - { deviceResource: "Zrotation", defaultValue: "0" }

```

对应的数据结构：

```go
// github.com/edgexfoundry/go-mod-core-contracts/v2/models/deviceprofile.go
type DeviceProfile struct {
	DBTimestamp
	Description     string
	Id              string
	Name            string
	Manufacturer    string
	Model           string
	Labels          []string
	DeviceResources []DeviceResource
	DeviceCommands  []DeviceCommand
}

type DeviceResource struct {
	Description string
	Name        string
	IsHidden    bool
	Tag         string
	Properties  ResourceProperties
	Attributes  map[string]interface{}
}

type ResourceProperties struct {
	ValueType    string
	ReadWrite    string
	Units        string
	Minimum      string
	Maximum      string
	DefaultValue string
	Mask         string
	Shift        string
	Scale        string
	Offset       string
	Base         string
	Assertion    string
	MediaType    string
}

type DeviceCommand struct {
	Name               string
	IsHidden           bool
	ReadWrite          string
	ResourceOperations []ResourceOperation
}

type ResourceOperation struct {
	DeviceResource string
	DefaultValue   string
	Mappings       map[string]string
}

// github.com/edgexfoundry/go-mod-core-contracts/v2/common/utils.go
var valueTypes = []string{
	ValueTypeBool, ValueTypeString,
	ValueTypeUint8, ValueTypeUint16, ValueTypeUint32, ValueTypeUint64,
	ValueTypeInt8, ValueTypeInt16, ValueTypeInt32, ValueTypeInt64,
	ValueTypeFloat32, ValueTypeFloat64,
	ValueTypeBinary,
	ValueTypeBoolArray, ValueTypeStringArray,
	ValueTypeUint8Array, ValueTypeUint16Array, ValueTypeUint32Array, ValueTypeUint64Array,
	ValueTypeInt8Array, ValueTypeInt16Array, ValueTypeInt32Array, ValueTypeInt64Array,
	ValueTypeFloat32Array, ValueTypeFloat64Array,
	ValueTypeObject,
}
```



### 3.2.3 Device

设备协议和自动采集数据定义，支持 toml 或 json 格式，`cmd/res/devices/xxx-device.toml` 

如下定义设备自动采集数据，即如何通过 command 对设备发送命令

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-device-autoevents.png)

```toml
[[DeviceList]]
  Name = "Simple-Device01"
  ProfileName = "Simple-Device"
  Description = "Example of Simple Device"
  Labels = [ "industrial" ]
  [DeviceList.Protocols]
  [DeviceList.Protocols.other]
    Address = "simple01"
    Port = "300"
  [[DeviceList.AutoEvents]]
    Interval = "10s"
    OnChange = false
    SourceName = "Switch"
  [[DeviceList.AutoEvents]]
    Interval = "30s"
    OnChange = false
    SourceName = "Image"
```

对应数据结构：

```go
// github.com/edgexfoundry/go-mod-core-contracts/v2/models/device.go
type Device struct {
	DBTimestamp
	Id             string
	Name           string
	Description    string
	AdminState     AdminState
	OperatingState OperatingState
	Protocols      map[string]ProtocolProperties
	LastConnected  int64 // Deprecated: will be replaced by Metrics in v3
	LastReported   int64 // Deprecated: will be replaced by Metrics in v3
	Labels         []string
	Location       interface{}
	ServiceName    string
	ProfileName    string
	AutoEvents     []AutoEvent
	Notify         bool
	Tags           map[string]any
}

// ProtocolProperties contains the device connection information in key/value pair
type ProtocolProperties map[string]string

// AdminState controls the range of values which constitute valid administrative states for a device
type AdminState string

// OperatingState is an indication of the operations of the device.
type OperatingState string

type AutoEvent struct {
	Interval   string
	OnChange   bool
	SourceName string
}
```



### 3.2.4 Device Service Configuration

配置 device service，路径 `cmd/device-xxx/res/device-xxx.toml`

```toml
[Writable]
LogLevel = "INFO"
  # Example InsecureSecrets configuration that simulates SecretStore for when EDGEX_SECURITY_SECRET_STORE=false
  # InsecureSecrets are required for when Redis is used for message bus
  [Writable.InsecureSecrets]
    [Writable.InsecureSecrets.DB]
    path = "redisdb"
      [Writable.InsecureSecrets.DB.Secrets]
      username = ""
      password = ""

[Service]
HealthCheckInterval = "10s"
Host = "localhost"
Port = 59999 # Device serivce are assigned the 599xx range
ServerBindAddr = ""  # blank value defaults to Service.Host value
StartupMsg = "device simple started"
# MaxRequestSize limit the request body size in byte of put command
MaxRequestSize = 0 # value 0 unlimit the request size.
RequestTimeout = "20s"
  [Service.CORSConfiguration]
  EnableCORS = false
  CORSAllowCredentials = false
  CORSAllowedOrigin = "https://localhost"
  CORSAllowedMethods = "GET, POST, PUT, PATCH, DELETE"
  CORSAllowedHeaders = "Authorization, Accept, Accept-Language, Content-Language, Content-Type, X-Correlation-ID"
  CORSExposeHeaders = "Cache-Control, Content-Language, Content-Length, Content-Type, Expires, Last-Modified, Pragma, X-Correlation-ID"
  CORSMaxAge = 3600

[Registry]
Host = "localhost"
Port = 8500
Type = "consul"

[Clients]
  [Clients.core-data]
  Protocol = "http"
  Host = "localhost"
  Port = 59880

  [Clients.core-metadata]
  Protocol = "http"
  Host = "localhost"
  Port = 59881

[MessageQueue]
Protocol = "redis"
Host = "localhost"
Port = 6379
Type = "redis"
AuthMode = "usernamepassword"  # required for redis messagebus (secure or insecure).
SecretName = "redisdb"
PublishTopicPrefix = "edgex/events/device" # /<device-profile-name>/<device-name>/<source-name> will be added to this Publish Topic prefix
  [MessageQueue.Optional]
  # Default MQTT Specific options that need to be here to enable environment variable overrides of them
  # Client Identifiers
  ClientId = "device-simple"
  # Connection information
  Qos = "0" # Quality of Sevice values are 0 (At most once), 1 (At least once) or 2 (Exactly once)
  KeepAlive = "10" # Seconds (must be 2 or greater)
  Retained = "false"
  AutoReconnect = "true"
  ConnectTimeout = "5" # Seconds
  SkipCertVerify = "false" # Only used if Cert/Key file or Cert/Key PEMblock are specified

# Example SecretStore configuration.
# Only used when EDGEX_SECURITY_SECRET_STORE=true
# Must also add `ADD_SECRETSTORE_TOKENS: "device-simple"` to vault-worker environment so it generates
# the token and secret store in vault for "device-simple"
[SecretStore]
Type = "vault"
Host = "localhost"
Port = 8200
Path = "device-simple/"
Protocol = "http"
RootCaCertPath = ""
ServerName = ""
SecretsFile = ""
DisableScrubSecretsFile = false
TokenFile = "/tmp/edgex/secrets/device-simple/secrets-token.json"
  [SecretStore.Authentication]
  AuthType = "X-Vault-Token"

[Device]
  DataTransform = true
  MaxCmdOps = 128
  MaxCmdValueLen = 256
  ProfilesDir = "./res/profiles"
  DevicesDir = "./res/devices"
  UpdateLastConnected = false
  AsyncBufferSize = 1
  EnableAsyncReadings = true
  Labels = []
  UseMessageBus = true
  [Device.Discovery]
    Enabled = false
    Interval = "30s"

# Example structured custom configuration
[SimpleCustom]
OnImageLocation = "./res/on.png"
OffImageLocation = "./res/off.jpg"
  [SimpleCustom.Writable]
  DiscoverSleepDurationSecs = 10
```

配置功能：

- 设备微服务的 host、port 等
- 注册中心的 host、 port
- core-data 和 core-metadata等服务的 host、port

- MessageQueue 配置，基于redis
- Device的 ProfilesDir, DevicesDir 和 Discovery 等



### 3.2.5 启动应用

```go
export EDGEX_SECURITY_SECRET_STORE=false

cd cmd
go run main.go
```



设备详情：

```bash
curl -s http://localhost:59882/api/v2/device/name/Simple-Device01 | jq
{
  "apiVersion": "v2",
  "statusCode": 200,
  "deviceCoreCommand": {
    "deviceName": "Simple-Device01",
    "profileName": "Simple-Device",
    "coreCommands": [
      ...
      {
        "name": "Counter",
        "get": true,
        "set": true,
        "path": "/api/v2/device/name/Simple-Device01/Counter",
        "url": "http://edgex-core-command:59882",
        "parameters": [
          {
            "resourceName": "Counter",
            "valueType": "Object"
          }
        ]
      },
      {
        "name": "Switch",
        "get": true,
        "set": true,
        "path": "/api/v2/device/name/Simple-Device01/Switch",
        "url": "http://edgex-core-command:59882",
        "parameters": [
          {
            "resourceName": "SwitchButton",
            "valueType": "Bool"
          }
        ]
      },
     ...
    ]
  }
}
```



### 3.2.6 Makefile

```makefile
.PHONY: build test clean docker

GO=CGO_ENABLED=0 GO111MODULE=on go
GOCGO=CGO_ENABLED=1 GO111MODULE=on go

MICROSERVICES=cmd/device-simple
.PHONY: $(MICROSERVICES)

VERSION=$(shell cat ./VERSION 2>/dev/null || echo 0.0.0)
DOCKER_TAG=$(VERSION)-dev

GOFLAGS=-ldflags "-X xtwl.com/edgex-app/device-simple.Version=$(VERSION)"
GOTESTFLAGS?=-race

tidy:
	go mod tidy

build: $(MICROSERVICES)
	$(GOCGO) install -tags=safe

cmd/device-simple:
	$(GOCGO) build $(GOFLAGS) -o $@ ./cmd

docker:
	docker build \
		-f Dockerfile \
		-t device-simple:$(DOCKER_TAG) \
		.

test:
	GO111MODULE=on go test $(GOTESTFLAGS) -coverprofile=coverage.out ./...
	GO111MODULE=on go vet ./...
	gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")
	[ "`gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")`" = "" ]

clean:
	rm -f $(MICROSERVICES)

vendor:
	$(GO) mod vendor
```



### 3.2.7 Dockerfile

```dockerfile
ARG BASE=golang:1.18.5-alpine3.16
FROM ${BASE} AS builder

WORKDIR /device-simple

RUN sed -e 's/dl-cdn[.]alpinelinux.org/nl.alpinelinux.org/g' -i~ /etc/apk/repositories

RUN apk add --update --no-cache make git gcc libc-dev zeromq-dev libsodium-dev

COPY . .
RUN [ ! -d "vendor" ] && go mod download all || echo "skipping..."

RUN make build

# Next image - Copy built Go binary into new workspace
FROM alpine:3.16

RUN sed -e 's/dl-cdn[.]alpinelinux.org/nl.alpinelinux.org/g' -i~ /etc/apk/repositories

RUN apk add --update --no-cache zeromq

WORKDIR /
COPY --from=builder /device-simple/cmd/device-simple /device-simple
COPY --from=builder /device-simple/cmd/res/ /res

EXPOSE 59999

ENTRYPOINT ["/device-simple"]
CMD ["-cp=consul.http://edgex-core-consul:8500", "--registry", "--confdir=/res"]
```



编译镜像：

```bash
make tidy && make vendor && make docker
```



配置 docker-compose.yml，增加应用配置：

```yaml
...
  device-simple:
    container_name: edgex-device-simple
    depends_on:
    - consul
    - data
    - metadata
    environment:
      CLIENTS_CORE_COMMAND_HOST: edgex-core-command
      CLIENTS_CORE_DATA_HOST: edgex-core-data
      CLIENTS_CORE_METADATA_HOST: edgex-core-metadata
      CLIENTS_SUPPORT_NOTIFICATIONS_HOST: edgex-support-notifications
      CLIENTS_SUPPORT_SCHEDULER_HOST: edgex-support-scheduler
      DATABASES_PRIMARY_HOST: edgex-redis
      EDGEX_SECURITY_SECRET_STORE: "false"
      MESSAGEQUEUE_HOST: edgex-redis
      REGISTRY_HOST: edgex-core-consul
      SERVICE_HOST: edgex-device-simple
    hostname: edgex-device-simple
    image: device-simple:0.0.0-dev
    networks:
      edgex-network: {}
    ports:
    - 59999:59999/tcp
    read_only: false
    privileged: true
    volumes:
    - "/sys:/sys"
    - "/dev:/dev"
    security_opt:
    - no-new-privileges:false
    user: root:root
...
```



### 3.2.8 使用总结

device service 主要依赖以下两个包:

```
github.com/edgexfoundry/device-sdk-go/v2 v2.1.1
github.com/edgexfoundry/go-mod-core-contracts/v2 v2.1.1
```



1）**pkg/startup** 启动服务

```go
// github.com/edgexfoundry/device-sdk-go/v2/pkg/bootstrap.go
func Bootstrap(serviceName string, serviceVersion string, driver interface{}) {
	ctx, cancel := context.WithCancel(context.Background())
	service.Main(serviceName, serviceVersion, driver, ctx, cancel, mux.NewRouter())
}
```



2）**pkg/service** 业务处理

```go
// github.com/edgexfoundry/device-sdk-go/v2/pkg/service/main.go
func Main(serviceName string, serviceVersion string, proto interface{}, ctx context.Context, cancel context.CancelFunc, router *mux.Router) {
	...
	bootstrap.Run(
		ctx,
		cancel,
		sdkFlags,
		ds.ServiceName,
		common.ConfigStemDevice,
		ds.config,
		startupTimer,
		ds.dic,
		true,
		[]interfaces.BootstrapHandler{
			httpServer.BootstrapHandler,
			messaging.BootstrapHandler,
			clients.BootstrapHandler,
			autoevent.BootstrapHandler,
			NewBootstrap(router).BootstrapHandler,
			autodiscovery.BootstrapHandler,
			handlers.NewStartMessage(serviceName, serviceVersion).BootstrapHandler,
		})

	ds.Stop(false)
}
```



3）**pkg/models**

实现 `CoreCommand`, `ProtocolDriver` 及 `ProtocolDiscovery` 的相关接口，负责设备驱动与 `CoreCommand` 的中间层交互。

```go
// github.com/edgexfoundry/device-sdk-go/v2/pkg/models/protocoldriver.go
type ProtocolDriver interface {
	Initialize(lc logger.LoggingClient, asyncCh chan<- *AsyncValues, deviceCh chan<- []DiscoveredDevice) error

	HandleReadCommands(deviceName string, protocols map[string]models.ProtocolProperties, reqs []CommandRequest) ([]*CommandValue, error)

	HandleWriteCommands(deviceName string, protocols map[string]models.ProtocolProperties, reqs []CommandRequest, params []*CommandValue) error

	Stop(force bool) error

	AddDevice(deviceName string, protocols map[string]models.ProtocolProperties, adminState models.AdminState) error

	UpdateDevice(deviceName string, protocols map[string]models.ProtocolProperties, adminState models.AdminState) error

	RemoveDevice(deviceName string, protocols map[string]models.ProtocolProperties) error
}
```



协议发现：

```go
// github.com/edgexfoundry/device-sdk-go/v2/pkg/models/protocoldiscovery.go
type ProtocolDiscovery interface {
	Discover()
}

type DiscoveredDevice struct {
	Name        string
	Protocols   map[string]models.ProtocolProperties
	Description string
	Labels      []string
}

```



命令值转换，用于设备驱动中。值转换：

```go
// github.com/edgexfoundry/device-sdk-go/pkg/models/commandvalues.go
type CommandValue struct {
	DeviceResourceName string
	Type string
	Value interface{}
	Origin int64
	Tags map[string]string
}

func NewCommandValue(deviceResourceName string, valueType string, value interface{}) (*CommandValue, error) {
	...
	return &CommandValue{
		DeviceResourceName: deviceResourceName,
		Type:               valueType,
		Value:              value,
		Tags:               make(map[string]string)}, nil
}

func NewCommandValueWithOrigin(deviceResourceName string, valueType string, value interface{}, origin int64) (*CommandValue, error) {
	cv, err := NewCommandValue(deviceResourceName, valueType, value)
	if err != nil {
		return nil, errors.NewCommonEdgeXWrapper(err)
	}

	cv.Origin = origin
	return cv, nil
}

// 实现对 cv.Value 的类型断言取值
func (cv *CommandValue) ValueToString() string
func (cv *CommandValue) String() string
func (cv *CommandValue) BoolValue() (bool, error) 
func (cv *CommandValue) BoolArrayValue() ([]bool, error) 
func (cv *CommandValue) StringValue() (string, error) 
func (cv *CommandValue) Uint8Value() (uint8, error) 
func (cv *CommandValue) Uint8ArrayValue() ([]uint8, error) 
func (cv *CommandValue) Uint16Value() (uint16, error) 
func (cv *CommandValue) Uint16ArrayValue() ([]uint16, error) 
func (cv *CommandValue) Uint32Value() (uint32, error) 
func (cv *CommandValue) Uint32ArrayValue() ([]uint32, error) 
func (cv *CommandValue) Uint64Value() (uint64, error) 
func (cv *CommandValue) Uint64ArrayValue() ([]uint64, error) 
func (cv *CommandValue) Int8Value() (int8, error) 
func (cv *CommandValue) Int8ArrayValue() ([]int8, error) 
func (cv *CommandValue) Int16Value() (int16, error) 
func (cv *CommandValue) Int16ArrayValue() ([]int16, error) 
func (cv *CommandValue) Int32Value() (int32, error) 
func (cv *CommandValue) Int32ArrayValue() ([]int32, error) 
func (cv *CommandValue) Int64Value() (int64, error) 
func (cv *CommandValue) Int64ArrayValue() ([]int64, error) 
func (cv *CommandValue) Float32Value() (float32, error) 
func (cv *CommandValue) Float32ArrayValue() ([]float32, error) 
func (cv *CommandValue) Float64Value() (float64, error) 
func (cv *CommandValue) Float64ArrayValue() ([]float64, error) 
func (cv *CommandValue) BinaryValue() ([]byte, error) 
```



## 3.3 导出服务

TODO



# 4. 示例

## 4.1 device-modbus-go

### 4.1.1 代码工程

官方源码：https://github.com/edgexfoundry/device-modbus-go

在官方源码基础上，修改了如下内容：

- 官方只支持 `Int16` 和 `Uint16` 两个数据的读取(https://docs.edgexfoundry.org/2.1/examples/Ch-ExamplesModbusdatatypeconversion/)，本代码新增 读取`Float32`数据（正泰电表需要）
- 将 device & device profile 默认配置替换为了电表的
- golang 版本升级至 1.18
- 重写 `Dockerfile` 和 `Makefile`

```bash
$ tree device-modbus-go -L 3
device-modbus-go
├── Dockerfile
├── Makefile
├── README.md
├── cmd
│   ├── main.go
│   └── res
│       ├── configuration.toml
│       ├── devices
│       └── profiles
├── go.mod
├── go.sum
├── internal
│   └── driver
│       ├── config.go
│       ├── config_test.go
│       ├── constant.go
│       ├── deviceclient.go
│       ├── deviceclient_test.go
│       ├── driver.go
│       ├── driver_test.go
│       ├── modbusclient.go
│       ├── protocolpropertykey.go
│       ├── swap.go
│       ├── swap_test.go
│       └── utils.go
├── vendor
│   ├── bitbucket.org
│   │   └── bertimus9
│   ├── github.com
│   │   ├── OneOfOne
│   │   ├── armon
│   │   ├── cenkalti
│   │   ├── davecgh
│   │   ├── eclipse
│   │   ├── edgexfoundry
│   │   ├── fatih
│   │   ├── fxamacker
│   │   ├── go-kit
│   │   ├── go-logfmt
│   │   ├── go-playground
│   │   ├── go-redis
│   │   ├── goburrow
│   │   ├── google
│   │   ├── gorilla
│   │   ├── hashicorp
│   │   ├── leodido
│   │   ├── mattn
│   │   ├── mitchellh
│   │   ├── pebbe
│   │   ├── pelletier
│   │   ├── pmezard
│   │   ├── stretchr
│   │   └── x448
│   ├── golang.org
│   │   └── x
│   ├── gopkg.in
│   │   └── yaml.v3
│   └── modules.txt
└── version.go
```



### 4.1.2 编译打包

二进制方式：

```bash
make build
```



docker镜像：

```bash
make docker
```



### 4.1.3 调试

以二进制运行包为例

```bash
# 使用环境变量替换配置文件中的默认值
export EDGEX_SECURITY_SECRET_STORE=false
export CLIENTS_CORE_DATA_HOST=192.168.3.107
export CLIENTS_CORE_METADATA_HOST=192.168.3.107
export MESSAGEQUEUE_HOST=192.168.3.107
export REGISTRY_HOST=192.168.3.107
export SERVICE_HOST=192.168.3.30

# 启动程序
cd cmd
./device-modbus
```



```bash
# 获取环境信息
curl -s http://localhost:59882/api/v2/device/name/Modbus-RTU-ammeter-device | jq
```



### 4.1.4 页面配置

#### 4.1.4.1 设备服务

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-service.png)



#### 4.1.4.2 设备

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-list.png)



设备命令：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-command.png)



新增/编辑设备：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-edit-1.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-edit-2.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-edit-3.png)



#### 4.1.4.3 设备元数据

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-metadata.png)



新增/编辑设备元数据：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/edgex/edgex-ui-device-metadata-edit.png)



### 4.1.5 总结

应用即协议，一个协议一个应用，通过配置 device 和 device profile 来使应用功能激活。

应用配置文件(`configuration.toml`)中指定 device 和 device profile 的配置：

```toml
[Device]
DataTransform = true
MaxCmdOps = 128
MaxCmdValueLen = 256
ProfilesDir = "./res/profiles"   # 默认配置，可以为空
DevicesDir = "./res/devices"     # 默认配置，可以为空
UpdateLastConnected = false
Labels = []
EnableAsyncReadings = true
AsyncBufferSize = 16
UseMessageBus = true
  [Device.Discovery]
  Enable = false
  Interval = '30s'
```

当应用启动后，配置将被更新到数据库中，**此时修改配置文件将不生效**。除非在页面上把 device 和 device  profile 配置删除。

另外，通过页面修改  device 和 device  profile 配置，将不会持久化到配置文件中。

建议：

- 应用默认不带 device 和 device profile 配置，在页面配置
- 每个协议一个应用





