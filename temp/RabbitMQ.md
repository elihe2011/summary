RabbitMQ解决的问题：

- 逻辑解构，异步任务
- 消息持久化，重启不影响
- 削峰，大规模消息处理



RabbitMQ的特性：

- 可靠性：持久化，传输确认、发布确认
- 可扩展性：多个节点可以组成一个集群，可动态更改
- 多语言客户端：几乎支持所有常用语言

- 管理界面：易用的用户界面，便于监控和管理



RabbitMQ关键术语：

- Exchange：消息交换机，决定消息按什么规则，路由到哪个队列
- Queue：消息载体，每个消息都会被偷盗一个或多个队列
- Binding：绑定，把exchange和queue按照路由规则绑定起来

- Routing Key：路由关键字，exchange根据这个关键字来投递消息
- Channel：消息通道，客户端的每个连接建立多个channel
- Producer/Publisher: 消息生产者，用于投递消息的程序
- Consumer：消息消费者，用于接收消息的程序



Exchange工作模式：

- Fanout: 类似广播，转发到所有绑定交换机的Queue上
- Direct：类似单播，RoutingKey和BindingKey完全匹配
- Topic：类似组播，转发到符合通配符的Queue上
- Headers：请求头与消息头匹配，才能接收消息



Fanout工作模式：

![fanout](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rabbitmq/Exchange_Fanout.PNG)



Direct工作模式：

![direct](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rabbitmq/Exchange_Direct.PNG)



Topic工作模式：

![topic](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rabbitmq/Exchange_Topic.PNG)





```sh
mkdir -p /data/rabbitmq

docker run -d --hostname rabbit-server --name rabbit-sever -p 5672:5672 -p 15672:15672 -p 25672:25672 -v /data/rabbitmq:/var/lib/rabbitmq rabbitmq:management

5672: API
15672: GUI 
25672: 集群通信
```



示例：

- 配置

```go
const (
	AsyncTransferEnable  = true
	RabbitURL            = "amqp://guest:guest@192.168.31.10:5672"
	TransExchangeName    = "uploadserver.trans"
	TransOSSQueueName    = "uploadserver.trans.oss"
	TransOSSErrQueueName = "uploadserver.trans.oss.err"
	TransOSSRoutingKey   = "oss"
)
```

- 生产者

```go
import (
	"github.com/streadway/amqp"
)

var (
	conn    *amqp.Connection
	channel *amqp.Channel
)

func initChannel() bool {
	// 1. 判断channel是否已经创建过
	if channel != nil {
		return true
	}

	// 2. 获得rbbaitmq连接
	var err error
	conn, err = amqp.Dial(config.RabbitURL)
	if err != nil {
		log.Println(err)
		return false
	}

	// 3. 打开一个channel，用于消息的发布和接收
	channel, err = conn.Channel()
	if err != nil {
		log.Println(err)
		return false
	}

	return true
}

func Publish(exchange, routingKey string, msg []byte) bool {
	// 1. 检查channel是否正常
	if !initChannel() {
		return false
	}

	// 2. 调用channel的publish方法
	err := channel.Publish(
		exchange,
		routingKey,
		false,
		false,
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        msg,
		})

	if err != nil {
		log.Println(err)
		return false
	}

	return true
}
```



- 消费者

```go
var done chan bool

func Consume(queue, consumer string, callback func(msg []byte) bool) {
	// 1. 通过channel.Consume获取消息信道
	autoAck := true
	exclusive := false // 是否唯一消费者，非唯一时，rabbitmq通过竞争机制派发
	noLocal := false   // rabbitmq无效
	noWait := false    // 等待rabbitmq返回信息

	delivery, err := channel.Consume(queue, consumer, autoAck, exclusive, noLocal, noWait, nil)
	if err != nil {
		log.Println(err)
		return
	}

	// 2. 循环获取队列消息
	done = make(chan bool)

	go func() {
		for msg := range delivery {
			// 3. 调用callback函数处理消息
			ok := callback(msg.Body)
			if !ok {
				// TODO: 将任务写到另一个队列，等待异常重试
			}

		}
	}()

	// 阻塞等待
	<-done

	channel.Close()
}
```

















- 



gRPC框架：

- 序列化协议：protobuf
- 底层通信协议：HTTP2 (支持多路复用)



Protobuf：

- 一种跨语言和跨平台的数据序列化协议
- 与XML/JSON相比，序列化效率更快、体积更小、更安全 (采用二进制组织)
- 与XML/JSON相比，可读性、灵活性较低
- 自带编译器，定义proto源文件，可编译成多种语言的代码



go-micro框架：

- 微服务架构的一种PRC框架

- 提供分布式系统相关的接口集合

  - 服务发现：支持服务注册与发现，底层支持ectd/consul/k8s
  - 负载均衡：rpc服务间的请求调度均衡策略
  - 同步通信：基于RPC通信，支持单向/双向流通信模式
  - 异步通信：提供pub/sub通信模型的接口

  - 高级接口：比如服务发现，提供调用的接口是一致的



Kubernetes:

- k8s是一个分布式系统的支撑平台：
  - 底层可以基于Docker来包装应用
  - 以集群的方式来运行/管理跨机器的容器应用
  - 解决了Docker跨机器场景的容器通信问题
  - 拥有自动修复能力

- 提供部署运行/资源调度/服务发现/动态伸缩等一系列功能