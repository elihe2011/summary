# 1. MQTT

MQTT（Message Queuing Telemetry Transport，消息队列遥测传输协议），是一种基于发布/订阅（Publish/Subscribe）模式的轻量级通讯协议，该协议构建于TCP/IP协议上，由IBM在1999年发布。

MQTT最大的优点在于可以以极少的代码和有限的带宽，为远程设备提供实时可靠的消息服务。做为一种低开销、低带宽占用的即时通讯协议，MQTT在物联网、小型设备、移动应用等方面有广泛的应用。



# 2. 消息格式

每条MQTT命令消息的消息头都包含一个固定的报头，有些消息会携带一个可变报文头和一个负荷

```bash
固定报文头 | 可变报文头 | 负荷
```



## 2.1 固定报文头（Fixed Header）

**固定报头的格式:**

<table style="text-align:center">
  <tbody><tr>
    <td align="center"><strong>Bit</strong></td>
    <td align="center"><strong>7</strong></td>
    <td align="center"><strong>6</strong></td>
    <td align="center"><strong>5</strong></td>
    <td align="center"><strong>4</strong></td>
    <td align="center"><strong>3</strong></td>
    <td align="center"><strong>2</strong></td>
    <td align="center"><strong>1</strong></td>
    <td align="center"><strong>0</strong></td>
  </tr>
  <tr>
    <td>byte 1</td>
    <td colspan="4" align="center">控制报文类型</td>
    <td colspan="4" align="center">标志位</td>
  </tr>
  <tr>
    <td>byte 2</td>
    <td colspan="8" align="center">剩余长度</td>
  </tr>
</tbody></table>



**控制报文的类型 (Control Packet type):**

| **名字**    | **值** | **报文流动方向** | **描述**                            |
| ----------- | ------ | ---------------- | ----------------------------------- |
| Reserved    | 0      | 禁止             | 保留                                |
| CONNECT     | 1      | 客户端到服务端   | 客户端请求连接服务端                |
| CONNACK     | 2      | 服务端到客户端   | 连接报文确认                        |
| PUBLISH     | 3      | 两个方向都允许   | 发布消息                            |
| PUBACK      | 4      | 两个方向都允许   | QoS 1消息发布收到确认               |
| PUBREC      | 5      | 两个方向都允许   | 发布收到（保证交付第一步）          |
| PUBREL      | 6      | 两个方向都允许   | 发布释放（保证交付第二步）          |
| PUBCOMP     | 7      | 两个方向都允许   | QoS 2消息发布完成（保证交互第三步） |
| SUBSCRIBE   | 8      | 客户端到服务端   | 客户端订阅请求                      |
| SUBACK      | 9      | 服务端到客户端   | 订阅请求报文确认                    |
| UNSUBSCRIBE | 10     | 客户端到服务端   | 客户端取消订阅请求                  |
| UNSUBACK    | 11     | 服务端到客户端   | 取消订阅报文确认                    |
| PINGREQ     | 12     | 客户端到服务端   | 心跳请求                            |
| PINGRESP    | 13     | 服务端到客户端   | 心跳响应                            |
| DISCONNECT  | 14     | 客户端到服务端   | 客户端断开连接                      |
| Reserved    | 15     | 禁止             | 保留                                |



**标志 Flags:**

| **控制报文** | **固定报头标志**   | **Bit 3** | **Bit 2** | **Bit 1** | **Bit 0** |
| ------------ | ------------------ | --------- | --------- | --------- | --------- |
| CONNECT      | Reserved           | 0         | 0         | 0         | 0         |
| CONNACK      | Reserved           | 0         | 0         | 0         | 0         |
| PUBLISH      | Used in MQTT 3.1.1 | DUP1      | QoS2      | QoS2      | RETAIN3   |
| PUBACK       | Reserved           | 0         | 0         | 0         | 0         |
| PUBREC       | Reserved           | 0         | 0         | 0         | 0         |
| PUBREL       | Reserved           | 0         | 0         | 1         | 0         |
| PUBCOMP      | Reserved           | 0         | 0         | 0         | 0         |
| SUBSCRIBE    | Reserved           | 0         | 0         | 1         | 0         |
| SUBACK       | Reserved           | 0         | 0         | 0         | 0         |
| UNSUBSCRIBE  | Reserved           | 0         | 0         | 1         | 0         |
| UNSUBACK     | Reserved           | 0         | 0         | 0         | 0         |
| PINGREQ      | Reserved           | 0         | 0         | 0         | 0         |
| PINGRESP     | Reserved           | 0         | 0         | 0         | 0         |
| DISCONNECT   | Reserved           | 0         | 0         | 0         | 0         |

- DUP1 = 控制报文的重复分发标志
- QoS2 = PUBLISH报文的服务质量等级
- RETAIN3 = PUBLISH报文的保留标志



**剩余长度 Remaining Length:**

表示当前报文剩余部分的字节数，包括可变报头和负载的数据。剩余长度不包括用于编码剩余长度字段本身的字节数。

| **字节数** | **最小值**                         | **最大值**                           |
| ---------- | ---------------------------------- | ------------------------------------ |
| 1          | 0 (0x00)                           | 127 (0x7F)                           |
| 2          | 128 (0x80, 0x01)                   | 16 383 (0xFF, 0x7F)                  |
| 3          | 16 384 (0x80, 0x80, 0x01)          | 2 097 151 (0xFF, 0xFF, 0x7F)         |
| 4          | 2 097 152 (0x80, 0x80, 0x80, 0x01) | 268 435 455 (0xFF, 0xFF, 0xFF, 0x7F) |



## 2.2 可变报头 Variable header

某些MQTT控制报文包含一个可变报头部分。它在固定报头和负载之间。可变报头的内容根据报文类型的不同而不同。可变报头的报文标识符（Packet Identifier）字段存在于在多个类型的报文里。



**报文标识符字节 Packet Identifier bytes:**

| **Bit** | **7** - **0**  |
| ------- | -------------- |
| byte 1  | 报文标识符 MSB |
| byte 2  | 报文标识符 LSB |



**报文标识符的控制报文 Control Packets that contain a Packet Identifier:**

| **控制报文** | **报文标识符字段**  |
| ------------ | ------------------- |
| CONNECT      | 不需要              |
| CONNACK      | 不需要              |
| PUBLISH      | 需要（如果QoS > 0） |
| PUBACK       | 需要                |
| PUBREC       | 需要                |
| PUBREL       | 需要                |
| PUBCOMP      | 需要                |
| SUBSCRIBE    | 需要                |
| SUBACK       | 需要                |
| UNSUBSCRIBE  | 需要                |
| UNSUBACK     | 需要                |
| PINGREQ      | 不需要              |
| PINGRESP     | 不需要              |
| DISCONNECT   | 不需要              |



客户端和服务端彼此独立地分配报文标识符。因此，客户端服务端组合使用相同的报文标识符可以实现并发的消息交换。

**非规范评注**

客户端发送标识符为0x1234的PUBLISH报文，它有可能会在收到那个报文的PUBACK之前，先收到服务端发送的另一个不同的但是报文标识符也为0x1234的PUBLISH报文。

| Client    | Server                      |
| --------- | --------------------------- |
| PUBLISH   | Packet Identifier=0x1234--- |
| --PUBLISH | Packet Identifier=0x1234    |
| PUBACK    | Packet Identifier=0x1234--- |
| --PUBACK  | Packet Identifier=0x1234    |



## 2.3 有效载荷 Payload

**有效载荷的控制报文 Control Packets that contain a Payload**

| **控制报文** | **有效载荷** |
| ------------ | ------------ |
| CONNECT      | 需要         |
| CONNACK      | 不需要       |
| PUBLISH      | 可选         |
| PUBACK       | 不需要       |
| PUBREC       | 不需要       |
| PUBREL       | 不需要       |
| PUBCOMP      | 不需要       |
| SUBSCRIBE    | 需要         |
| SUBACK       | 需要         |
| UNSUBSCRIBE  | 需要         |
| UNSUBACK     | 不需要       |
| PINGREQ      | 不需要       |
| PINGRESP     | 不需要       |
| DISCONNECT   | 不需要       |



# 3. QOS

MQTT服务质量(Quality of Service 缩写 QoS)正是用于告知物联网系统，哪些信息是重要信息需要准确无误的传输，而哪些信息不那么重要，即使丢失也没有问题。

**QoS是Sender和Receiver之间的协议，而不是Publisher和Subscriber之间的协议**。换句话说，Publisher发布了一条QoS为1的消息，只能保证Broker能至少收到一次这个消息；而对于Subscriber能否至少收到一次这个消息，还要取决于Subscriber在Subscibe的时候和Broker协商的QoS等级。



## 3.1 三种服务质量

MQTT协议有三种服务质量：

- QoS 0：消息最多传递一次，如果当时客户端不可用，则会丢失该消息。
- QoS 1：消息传递至少 1 次。
- QoS 2：消息仅传送一次。



QOS实际是客户端和Broker之间的一个服务可靠等级。这个可靠等级最终计算也是取决于订阅和发布双方。
**实际的client和broker的QOS是 MIN(Publish QoS, Subscribe QoS)**。假设现在发布方的主题是2，但是订阅方的主题是0，那么你订阅方最终和Broker之间的QOS也是0。假设发布方的主题是0，订阅方订阅了设置为了1，那最终订阅方和Broker之间也是0.



### 3.1.1 QoS = 0 – **最多一次**

最小的等级就是 0。并且它保证一次信息尽力交付。一个消息不会被接收端应答，也不会被发送者存储并再发送。这个也被叫做 “即发即弃” 。并且在TCP协议下也是会有相同的担保。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_0.png) 



### 3.1.2 QoS = 1 – **最少一次**

当使用QoS 等级1 时， 它保证信息将会被至少发送一次给接受者。 但是消息也可能被发送两次甚至更多 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_1.png) 

**发送者将会存储发送的信息直到发送者收到一次来自接收者的PUBACK格式的应答。**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_1_puback_packet.png) 

PUBLISH 与PUBACK的关联是通过比较数据包中的 packet identifier完成的。如果在特定的时间内（timeout）发送端没有收到PUBACK应答，那么发送者会重新发送PUBLISH消息。如果接受者接收到QoS为1 的消息，它会立即处理这里消息，比如把这个包发送给订阅该主题的接收端，并回复PUBACK包。

The duplicate（DUP）flag，用来标记PUBLISH 被重新分发的情况。仅仅是为了内部使用的目的，并且当QoS 为1 是不会被broker 或者client处理。接受者都会发送PUBACK消息，而不管DUP flag。



### 3.1.3 QoS = 2 – 保证仅一次

最高的QoS就是2，它会确保每个消息都只被接收到的一次，他是最安全也是最慢的服务等级。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_2.png) 

如果接收端接收到了一个QoS 的PUBLISH消息，它将相应地处理 PUBLISH消息，并通过PUBREC消息向发送方确认。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_2_pubrec_packet.png) 

直到他发出一个PUBCOMP包为止，接收端都保存这个包packet identifier。这一点很重要，因为它避免了二次处理同一个PUBLISH包。 当发送者接收到PUBREC的时候，它可以放弃最开始的publish了，因为它已经知道另一端已经接收到消息，他将保存PUBREC并且回复PUBREL。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_2_pubrel_packet.png) 

当接收端接收到PUBREL，它就可以丢弃所有该包的存储状态并回复PUBCOMP。当发送端接收到PUBCOMP时也会做同样的处理。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_2_pubcomp_packet.png) 

当整个流程结束的时候，所有的参与者都确定消息被正确的发送和送达了。

无论什么时候，一个包丢失了，发送端有责任在特定时间后重新发送最后一次发送的消息。接收端有责任响应每一个指令消息。



## 3.2 QoS 降级

MQTT 发布与订阅操作中的 QoS 代表了不同的含义，发布时的 QoS 表示消息发送到服务端时使用的 QoS，订阅时的 QoS 表示服务端向自己转发消息时可以使用的最大 QoS。

- 当客户端 A 的发布 QoS 大于客户端 B 的订阅 QoS 时，服务端向客户端 B 转发消息时使用的 QoS 为客户端 B 的订阅 QoS。
- 当客户端 A 的发布 QoS 小于客户端 B 的订阅 QoS 时，服务端向客户端 B 转发消息时使用的 QoS 为客户端 A 的发布 QoS。

不同情况下客户端收到的消息 QoS 可参考下表：

| 发布消息的 QoS | 主题订阅的 QoS | 接收消息的 QoS |
| -------------- | -------------- | -------------- |
| 0              | 0              | 0              |
| 0              | 1              | 0              |
| 0              | 2              | 0              |
| 1              | 0              | 0              |
| 1              | 1              | 1              |
| 1              | 2              | 1              |
| 2              | 0              | 0              |
| 2              | 1              | 1              |
| 2              | 2              | 2              |



### 3.2.1 QoS=1

如想在MQTT通讯中实现服务质量等级为1级（QoS=1），我们要分别对消息的发布端课接收端进行相应的设置。以下列表中的内容是具体需要采取的措施。

- 接收端连接服务端时cleanSession设置为false
- 接收端订阅主题时QoS=1
- 发布端发布消息时QoS=1



### 3.2.2 QoS=2

如想在MQTT通讯中实现服务质量等级为2级（QoS=2），我们要分别对消息的发布端和接收端进行相应的设置。以下列表中的内容是具体需要采取的措施。

- 接收端连接服务端时cleanSession设置为false
- 接收端订阅主题时QoS=2
- 发布端发布消息时QoS=2



### 3.2.3 小结

- 若想实现QoS>0，订阅端连接服务端时cleanSession需要设置为false，订阅端订阅主题时QoS>0，发布端发布消息时的QoS>0。
- 服务端会选择发布消息和订阅消息中较低的QoS来实现消息传输，这也被称作“服务降级”。
- QoS = 0, 占用的网络资源最低，但是接收端可能会出现无法接收消息的情况，所以适用于传输重要性较低的信息。
- QoS = 1, MQTT会确保接收端能够接收到消息，但是有可能出现接收端反复接收同一消息的情况。
- QoS = 2, MQTT会确保接收端只接收到一次消息。但是QoS为2时消息传输最慢，另外消息传输需要多次确认，因此所占用的网络资源也是最多的。此类服务等级适用于重要消息传输。
- 由于QoS1和QoS2都能确保客户端接收到消息，但是QoS1所占用的资源较QoS2占用资源更小。因此建议使用QoS1来实现网络资源较为珍贵的环境下传输重要信息。



## 3.3 QoS 等级选取

QoS 级别越高，流程越复杂，系统资源消耗越大。应用程序可以根据自己的网络场景和业务需求，选择合适的 QoS 级别。



### 3.3.1 QoS 0

- 可以接受消息偶尔丢失。
- 在同一个子网内部的服务间的消息交互，或其他客户端与服务端网络非常稳定的场景。



### 3.3.2 QoS 1

- 对系统资源消耗较为关注，希望性能最优化。
- 消息不能丢失，但能接受并处理重复的消息。



### 3.3.3 QoS 2

- 不能忍受消息丢失（消息的丢失会造成生命或财产的损失），且不希望收到重复的消息。
- 数据完整性与及时性要求较高的银行、消防、航空等行业。



# 4. 主题匹配（Topic Match)

## 4.1 通配符
MQTT中的通配符目前只有两个：

- ‘#’
- ‘+’

层级分隔符（‘/’）：它作为每一级主题的分隔符，从而为主题名称提供层级结构。连续的正斜杠（“//”）表示长度为0的主题。



## 4.2 多级通配符（‘#’）

可以匹配包括父级和下属的多个子层级。字符可以单独存在，也可以作为匹配子主题存在，但无论哪种情况，‘#’必须为过滤器的最后一个字符。

- 当 ‘#’ 单独存在时，将匹配所有的主题。
  - “#”（匹配所有的主题，'$'开头的除外）

- 在匹配子主题时，例如，订阅“sport/tennis/player1/#”，将收到：

  - “sport/tennis/player1”（该话题本身，因为包含父级）

  - “sport/tennis/player1/ranking”（该话题的下属层级）

  - “sport/tennis/player1/score/yesterday”（所有间接下属层级）
  
- 在匹配子主题时，‘#’前面的字符必须是‘/’，如下不合法：
  - “sport/tennis/#/player”（不是最后一个字符）
  - “sport/tennis/player#”（是最后一个字符，但前一位不是‘/’）



## 4.3 单级通配符（‘+’）

- 单级匹配符只能匹配所在层级，且在使用时，必须占满整个层级：
  - “sport/+/player1”
  - “sport/+/#”（可以和其他通配符搭配使用）
  - “+/tennis”（匹配任意顶级主题）
  - “sport/tennis/+”（匹配tennis下一级的主题）
  
- 在匹配主题时，例如订阅“sport/tennis/+”，下列主题的新信息都将被收到：
  - “sport/tennis/player1”
  - “sport/tennis/player2”
  - “sport/tennis/player3”
  - “sport/tennis/”（空主题，可以被匹配）
  
  - “sport/tennis”（父级主题不在当前层级，无法被匹配）
  - “sport/tennis/player1/score”（间接子主题不在当前层级，无法被匹配）
  
- 无效的匹配：

  - “sport+/”（没有占满整个层级）



## 4.4 特殊符号：系统保留主题（‘$’）
在‘#’或‘/’进行匹配时，以‘$’开头的主题将不会被匹配到。 换言之，服务器将禁止客户端使用此类话题与其他客户端通信，以‘$’开头的话题作为系统保留主题，供内部使用，这些主题的消息不会被客户端所发布或订阅。在MQTT中，“$SYS/”被广泛用作包含特定于服务器的信息或控件API的主题的前缀。在下列例子中，展示了‘$’和两种通配符共存时的一些情况：

- “#”（匹配不到以‘$’开头的主题）
- “ + /monitor/Clients”将匹配不到 “$SYS/monitor/Clients”
- “ $SYS/monitor/+”可以匹配到 “$SYS/monitor/Clients”



# 5. MQTT服务器
**Apache-Apollo**：一个代理服务器，在ActiveMQ基础上发展而来，可以支持STOMP、AMQP、MQTT、Openwire、SSL和WebSockets等多种协议，并且Apollo提供后台管理页面，方便开发者管理和调试。

**EMQ**：EMQ 2.0，号称百万级开源MQTT消息服务器，基于Erlang/OTP语言平台开发，支持大规模连接和分布式集群，发布订阅模式的开源MQTT消息服务器。

**HiveMQ**：一个企业级的MQTT代理，主要用于企业和新兴的机器到机器M2M通讯和内部传输，最大程度的满足可伸缩性、易管理和安全特性，提供免费的个人版。HiveMQ提供了开源的插件开发包。

**Mosquitto**：一款实现了消息推送协议MQTT v3.1的开源消息代理软件，提供轻量级的、支持可发布/可订阅的消息推送模式。




