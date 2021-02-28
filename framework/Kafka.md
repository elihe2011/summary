# 1. Kafka

## 1.1 应用场景：

- 异步处理，非关键流程异步化，提高系统的响应时间和健壮性
- 应用解耦，通过消息队列

- 流量削峰，流控和过载保护

## 1.2 相关术语：

- Broker

  Kafka集群包含一个或多个服务器，这种服务器被称为broker

- Topic

  每条发布到Kafka集群的消息都有一个类别，这个类别被称为Topic。（物理上不同Topic的消息分开存储，逻辑上一个Topic的消息虽然保存于一个或多个broker上但用户只需指定消息的Topic即可生产或消费数据而不必关心数据存于何处）

- Partition

  Partition是物理上的概念，每个Topic包含一个或多个Partition.

- Producer

  负责发布消息到Kafka broker

- Consumer

  消息消费者，向Kafka broker读取消息的客户端。

- Consumer Group

  每个Consumer属于一个特定的Consumer Group（可为每个Consumer指定group name，若不指定group name则属于默认的group）。



# 2. Kafka 服务

```bash
./kafka-console-consumer.sh --bootstrap-server 192.168.31.200:9092 --topic nginx_log --from-beginning
```



# 3. 实例

```bash
go get github.com/Shopify/sarama
```



## 3.1 生成者

```go
func main() {
	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Partitioner = sarama.NewRandomPartitioner
	config.Producer.Return.Successes = true

	client, err := sarama.NewSyncProducer([]string{"192.168.31.200:9092"}, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	for i := 0; i < 10; i++ {
		text := fmt.Sprintf("kafka message %d", i+1)

		msg := &sarama.ProducerMessage{}
		msg.Topic = "nginx_log"
		msg.Value = sarama.StringEncoder(text)

		pid, offset, err := client.SendMessage(msg)
		if err != nil {
			log.Fatal(err)
		}

		log.Printf("pid=%v, offset=%v", pid, offset)

		time.Sleep(2 * time.Second)
	}
}
```

## 3.2 消费者

```go
var wg sync.WaitGroup

func main() {
	config := sarama.NewConfig()
	config.Consumer.Return.Errors = true

	consumer, err := sarama.NewConsumer([]string{"192.168.31.200:9092"}, config)
	if err != nil {
		log.Fatal(err)
	}

	partitionList, err := consumer.Partitions("nginx_log")
	if err != nil {
		log.Fatal(err)
	}
	log.Println(partitionList)

	for _, partition := range partitionList {
		pc, err := consumer.ConsumePartition("nginx_log", partition, sarama.OffsetNewest)
		if err != nil {
			log.Fatal(err)
		}

		wg.Add(1)
		go func(pc sarama.PartitionConsumer) {
			defer pc.AsyncClose()

			for msg := range pc.Messages() {
				fmt.Printf("Partition:%d, Offset:%d, Key:%s, Value:%s\n", msg.Partition, msg.Offset, msg.Key, msg.Value)
			}
			wg.Done()
		}(pc)
	}

	wg.Wait()
	consumer.Close()
}
```



