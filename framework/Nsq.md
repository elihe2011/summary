# 1. 简介

- NSQ 是Go语言开发的，内存分布式消息队列中间件
- 可大规模地处理每天数以十亿计级别的消息
- 分布式和去中心化拓扑结构，无单点故障


# 2. NSQ 组件

- nsqd: 负责消息接收、保存及发送给消费者的进程
- nsqlookupd: 负责维护所有nsqd的状态，提供服务发现的进程
- nsqadmin：web管理平台，实时监控集群及执行各种管理任务

# 3. NSQ 特性

- 消息默认不持久化，可以配置成持久化
- 每条消息至少传递一次
- 消息不保证有序

# 4. 安装nsq服务器

```bash
cat docker-compose.yml 
version: '3'
services:
  nsqlookupd:
    container_name: nsqlookupd
    image: nsqio/nsq
    command: /nsqlookupd
    ports:
      - "4160:4160"
      - "4161:4161"

  nsqd:
    container_name: nsqd
    image: nsqio/nsq
    command: /nsqd --lookupd-tcp-address=nsqlookupd:4160 --broadcast-address=192.168.31.200 # 设置为宿主机的IP，否则客户端无法访问
    depends_on:
      - nsqlookupd
    ports:
      - "4150:4150"
      - "4151:4151"

  nsqadmin:
    container_name: nsqadmin
    image: nsqio/nsq
    command: /nsqadmin --lookupd-http-address=nsqlookupd:4161
    depends_on:
      - nsqlookupd
    ports:
      - "4171:4171"
      
docker-compose up -d
docker-compose ps

curl http://localhost:4171
```

# 5. 使用

```bash
go get github.com/nsqio/go-nsq
```

## 5.1 生产者

```go
var producer *nsq.Producer

func main() {
	nsqAddr := "192.168.31.200:4150"
	err := initProducer(nsqAddr)
	if err != nil {
		log.Fatalf("init producer error: %v", err)
	}

	// 读取控制台输入
	reader := bufio.NewReader(os.Stdin)
	for {
		s, err := reader.ReadString('\n')
		if err != nil {
			log.Printf("read from stdin error: %v", err)
			continue
		}

		s = strings.TrimSpace(s)
		if s == "q" {
			break
		}

		err = producer.Publish("order_queue", []byte(s))
		if err != nil {
			log.Printf("publish msg error: %v", err)
		} else {
			log.Printf("publish msg success: %s", s)
		}
	}
}

func initProducer(nsqAddr string) (err error) {
	cfg := nsq.NewConfig()
	producer, err = nsq.NewProducer(nsqAddr, cfg)
	return
}
```

## 5.2 消费者

```go
type Consumer struct{}

func (*Consumer) HandleMessage(msg *nsq.Message) error {
	log.Printf("receive from %v: %v", msg.NSQDAddress, string(msg.Body))
	return nil
}

func main() {
	err := initConsumer("order_queue", "first", "192.168.31.200:4161")
	if err != nil {
		log.Fatalf("init consumer error: %v", err)
	}

	ch := make(chan os.Signal)
	signal.Notify(ch, syscall.SIGINT)
	<-ch
}

func initConsumer(topic, channel, address string) error {
	cfg := nsq.NewConfig()
	cfg.LookupdPollInterval = 15 * time.Second // 服务发现的轮询时间
	c, err := nsq.NewConsumer(topic, channel, cfg)
	if err != nil {
		return err
	}

	consumer := &Consumer{}
	c.AddHandler(consumer) // 添加消费者接口

	// 建立NSQLookupd连接
	if err = c.ConnectToNSQLookupd(address); err != nil {
		return err
	}

	return nil
}
```

