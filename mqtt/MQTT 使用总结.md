# 1. QOS

MQTT服务质量(Quality of Service 缩写 QoS)正是用于告知物联网系统，哪些信息是重要信息需要准确无误的传输，而哪些信息不那么重要，即使丢失也没有问题。

**QoS是Sender和Receiver之间的协议，而不是Publisher和Subscriber之间的协议**。换句话说，Publisher发布了一条QoS为1的消息，只能保证Broker能至少收到一次这个消息；而对于Subscriber能否至少收到一次这个消息，还要取决于Subscriber在Subscibe的时候和Broker协商的QoS等级。



## 1.1 三种服务质量

MQTT协议有三种服务质量：

- QoS 0：消息最多传递一次，如果当时客户端不可用，则会丢失该消息。
- QoS 1：消息传递至少 1 次。
- QoS 2：消息仅传送一次。



QOS实际是客户端和Broker之间的一个服务可靠等级。这个可靠等级最终计算也是取决于订阅和发布双方。
**实际的client和broker的QOS是 MIN(Publish QoS, Subscribe QoS)**。假设现在发布方的主题是2，但是订阅方的主题是0，那么你订阅方最终和Broker之间的QOS也是0。假设发布方的主题是0，订阅方订阅了设置为了1，那最终订阅方和Broker之间也是0.



### 1.1.1 QoS = 0 – **最多一次**

最小的等级就是 0。并且它保证一次信息尽力交付。一个消息不会被接收端应答，也不会被发送者存储并再发送。这个也被叫做 “即发即弃” 。并且在TCP协议下也是会有相同的担保。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_0.png) 



### 1.1.2 QoS = 1 – **最少一次**

当使用QoS 等级1 时， 它保证信息将会被至少发送一次给接受者。 但是消息也可能被发送两次甚至更多 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_1.png) 

**发送者将会存储发送的信息直到发送者收到一次来自接收者的PUBACK格式的应答。**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/mqtt/qos_1_puback_packet.png) 

PUBLISH 与PUBACK的关联是通过比较数据包中的 packet identifier完成的。如果在特定的时间内（timeout）发送端没有收到PUBACK应答，那么发送者会重新发送PUBLISH消息。如果接受者接收到QoS为1 的消息，它会立即处理这里消息，比如把这个包发送给订阅该主题的接收端，并回复PUBACK包。

The duplicate（DUP）flag，用来标记PUBLISH 被重新分发的情况。仅仅是为了内部使用的目的，并且当QoS 为1 是不会被broker 或者client处理。接受者都会发送PUBACK消息，而不管DUP flag。



### 1.1.3 QoS = 2 – 保证仅一次**

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





## 1.2 QoS 降级

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



### 1.2.1 QoS=1

如想在MQTT通讯中实现服务质量等级为1级（QoS=1），我们要分别对消息的发布端课接收端进行相应的设置。以下列表中的内容是具体需要采取的措施。

- 接收端连接服务端时cleanSession设置为false
- 接收端订阅主题时QoS=1
- 发布端发布消息时QoS=1

------

### 1.2.2 QoS=2

如想在MQTT通讯中实现服务质量等级为2级（QoS=2），我们要分别对消息的发布端和接收端进行相应的设置。以下列表中的内容是具体需要采取的措施。

- 接收端连接服务端时cleanSession设置为false
- 接收端订阅主题时QoS=2
- 发布端发布消息时QoS=2

------

### 1.2.3 小结

- 若想实现QoS>0，订阅端连接服务端时cleanSession需要设置为false，订阅端订阅主题时QoS>0，发布端发布消息时的QoS>0。
- 服务端会选择发布消息和订阅消息中较低的QoS来实现消息传输，这也被称作“服务降级”。
- QoS = 0, 占用的网络资源最低，但是接收端可能会出现无法接收消息的情况，所以适用于传输重要性较低的信息。
- QoS = 1, MQTT会确保接收端能够接收到消息，但是有可能出现接收端反复接收同一消息的情况。
- QoS = 2, MQTT会确保接收端只接收到一次消息。但是QoS为2时消息传输最慢，另外消息传输需要多次确认，因此所占用的网络资源也是最多的。此类服务等级适用于重要消息传输。
- 由于QoS1和QoS2都能确保客户端接收到消息，但是QoS1所占用的资源较QoS2占用资源更小。因此建议使用QoS1来实现网络资源较为珍贵的环境下传输重要信息。



## 1.3 QoS 等级选取

QoS 级别越高，流程越复杂，系统资源消耗越大。应用程序可以根据自己的网络场景和业务需求，选择合适的 QoS 级别。

### 1.3.1 QoS 0

- 可以接受消息偶尔丢失。
- 在同一个子网内部的服务间的消息交互，或其他客户端与服务端网络非常稳定的场景。

### 1.3.2 QoS 1

- 对系统资源消耗较为关注，希望性能最优化。
- 消息不能丢失，但能接受并处理重复的消息。

### 1.3.3 QoS 2

- 不能忍受消息丢失（消息的丢失会造成生命或财产的损失），且不希望收到重复的消息。
- 数据完整性与及时性要求较高的银行、消防、航空等行业。



# 2. 主题匹配（Topic Match)

## 2.1 通配符
MQTT中的通配符目前只有两个：

- ‘#’
- ‘+’

层级分隔符（‘/’）：它作为每一级主题的分隔符，从而为主题名称提供层级结构。连续的正斜杠（“//”）表示长度为0的主题。



## 2.2 多级通配符（‘#’）

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



## 2.3 单级通配符（‘+’）

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



## 2.4 特殊符号：系统保留主题（‘$’）
在‘#’或‘/’进行匹配时，以‘$’开头的主题将不会被匹配到。 换言之，服务器将禁止客户端使用此类话题与其他客户端通信，以‘$’开头的话题作为系统保留主题，供内部使用，这些主题的消息不会被客户端所发布或订阅。在MQTT中，“$SYS/”被广泛用作包含特定于服务器的信息或控件API的主题的前缀。在下列例子中，展示了‘$’和两种通配符共存时的一些情况：

- “#”（匹配不到以‘$’开头的主题）
- “ + /monitor/Clients”将匹配不到 “$SYS/monitor/Clients”
- “ $SYS/monitor/+”可以匹配到 “$SYS/monitor/Clients”







