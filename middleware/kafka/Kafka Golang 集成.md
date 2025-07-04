```bash
go get -u github.com/Shopify/sarama
```



# 1. Topic

```go
// 客户端
client, err := sarama.NewClient(brokers, config)

// 管理员
clusterAdmin, err := sarama.NewClusterAdminFromClient(client)

// topic 新增
err = clusterAdmin.CreateTopic(topicName, topicDetail, true)

// topic 列表
topicDetails, err := clusterAdmin.ListTopics()

// topic 详情
metadatas, err := clusterAdmin.DescribeTopics([]string{"goose", "test"})

// 删除 topic
err = clusterAdmin.DeleteTopic("test")

// 获取 topic 所有的分区
ids, err := client.Partions(topicName)

// 获取 topic 某个 partition 的偏移量
maxOffset, err := client.GetOffset(topicName, partitionID, sarama.OffsetNewest)
```



示例：

```go
func main() {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0

	brokers := []string{"192.168.80.240:30090", "192.168.80.241:30091", "192.168.80.242:30092"}

	// 客户端
	client, err := sarama.NewClient(brokers, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	// 管理员
	clusterAdmin, err := sarama.NewClusterAdminFromClient(client)
	if err != nil {
		log.Fatal(err)
	}

	topicName := "nginx-log"
	topicDetail := &sarama.TopicDetail{
		NumPartitions:     5,
		ReplicationFactor: 3,
	}

	// topic 新增
	err = clusterAdmin.CreateTopic(topicName, topicDetail, true)
	if err != nil {
		log.Fatal(err)
	}

	// topic 列表
	topicDetails, err := clusterAdmin.ListTopics()
	if err != nil {
		log.Fatal(err)
	}
	for _, topicDetail := range topicDetails {
		log.Println(topicDetail.NumPartitions)
	}

	// topic 详情
	metadatas, err := clusterAdmin.DescribeTopics([]string{"goose", "test"})
	if err != nil {
		log.Fatal(err)
	}
	for _, metadata := range metadatas {
		log.Println(metadata.Name, len(metadata.Partitions))
	}

	// 删除 topic
	err = clusterAdmin.DeleteTopic("test")
	if err != nil {
		log.Fatal(err)
	}
}
```



# 2. Producer

## 2.1 Sync

```go
producer, err := sarama.NewSyncProducerFromClient(client)

msg := &sarama.ProducerMessage{
	Topic: "nginx-log",
	Value: sarama.StringEncoder(text),
}

pid, offset, err := producer.SendMessage(msg)
```

示例：

```go
func main() {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Partitioner = sarama.NewRandomPartitioner
	config.Producer.Return.Successes = true
	config.Consumer.Return.Errors = true

	brokers := []string{"192.168.80.240:30090", "192.168.80.241:30091", "192.168.80.242:30092"}

	client, err := sarama.NewClient(brokers, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	producer, err := sarama.NewSyncProducerFromClient(client)
	if err != nil {
		log.Fatal(err)
	}
	defer producer.Close()

	for i := 0; i < 10; i++ {
		text := fmt.Sprintf("kafka message %d", i+1)

		msg := &sarama.ProducerMessage{
			Topic: "nginx-log",
			Value: sarama.StringEncoder(text),
		}

		pid, offset, err := producer.SendMessage(msg)
		if err != nil {
			log.Fatal(err)
		}

		log.Printf("pid=%v, offset=%v", pid, offset)

		time.Sleep(2 * time.Second)
	}
}
```



## 2.2 Async

```go
producer, err := sarama.NewAsyncProducerFromClient(client)

producer.Input() <- &sarama.ProducerMessage{Topic: "nginx-log", Value: sarama.StringEncoder("hello world")}
```

示例：

```go
func main() {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0
	config.Producer.RequiredAcks = sarama.WaitForLocal                      // Only wait for the leader to ack
	config.Producer.Compression = sarama.CompressionSnappy                  // Compress messages
	config.Producer.Flush.Frequency = time.Duration(500) * time.Millisecond // Flush batches every 500ms
	config.Producer.Partitioner = sarama.NewRandomPartitioner
	config.Producer.Return.Successes = true
	config.Consumer.Return.Errors = true

	brokers := []string{"192.168.80.240:30090", "192.168.80.241:30091", "192.168.80.242:30092"}

	client, err := sarama.NewClient(brokers, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	producer, err := sarama.NewAsyncProducerFromClient(client)
	if err != nil {
		log.Fatal(err)
	}
	defer producer.Close()

	for i := 0; i < 10; i++ {
		text := fmt.Sprintf("kafka async message %d", i+1)

		msg := &sarama.ProducerMessage{
			Topic:     "nginx-log",
			Value:     sarama.StringEncoder(text),
			Timestamp: time.Now(),
		}

		producer.Input() <- msg
	}

	go func() {
	LOOP:
		for {
			select {
			case success := <-producer.Successes():
				log.Printf("Topic: %s, Partition: %d, Value: %s, Offset: %d, timestamp: %v\n",
					success.Topic, success.Partition, success.Value, success.Offset, success.Timestamp)
			case failure := <-producer.Errors():
				log.Printf("error: %v\n", failure.Error())
				break LOOP
			default:
				log.Println("waiting kafka server response")
				time.Sleep(time.Second)
			}
		}
	}()

	sigterm := make(chan os.Signal, 1)
	signal.Notify(sigterm, syscall.SIGINT, syscall.SIGTERM)
	<-sigterm
}
```



# 3. Consumer

```go
consumer, err := sarama.NewConsumerFromClient(client)

partitionList, err := consumer.Partitions("nginx-log")

// 按偏移量查询消息
partitionConsumer, err := consumer.ConsumePartition("nginx-log", partition, sarama.OffsetOldest)
for msg := range partitionConsumer.Messages() {
	log.Println(msg.Topic, msg.Value, msg.Offset)
}

// 按时间查询消息
startOffset, err := client.GetOffset(topic, partition, startTime)
messages, err := consumer.ConsumePartition(topic, partition, startOffset)

// 获取某topic某partition某offset的消费消息；当消息已消费，此处报错。
messages, err := sarama.Consumer.ConsumePartition(topic, partition, offset)

// 通过 topicName和PartitionID 获取偏移量
nextOffset, _, err := offsetClient.GetPartionOffset(topicName,PartitionID)

// 重置offset
partitionManager, err := offsetManager.ManagePartition(topic,partition)
partitionManager.ResetOffset(offset, metadata)
```

示例：

```go
func main() {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0
	config.Consumer.Return.Errors = true

	brokers := []string{"192.168.80.240:30090", "192.168.80.241:30091", "192.168.80.242:30092"}

	// 客户端
	client, err := sarama.NewClient(brokers, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	consumer, err := sarama.NewConsumerFromClient(client)
	if err != nil {
		log.Fatal(err)
	}

	var wg sync.WaitGroup

	partitionList, err := consumer.Partitions("nginx-log")
	if err != nil {
		log.Fatal(err)
	}

	for _, partition := range partitionList {
		partitionConsumer, err := consumer.ConsumePartition("nginx-log", partition, sarama.OffsetNewest)
		if err != nil {
			log.Fatal(err)
		}

		wg.Add(1)
		go func(pc sarama.PartitionConsumer) {
			defer wg.Done()
			defer pc.AsyncClose()

			for msg := range pc.Messages() {
				fmt.Printf("Topic:%s, Partition:%d, Offset:%d, Key:%s, Value:%s\n", msg.Topic, msg.Partition, msg.Offset, msg.Key, msg.Value)
			}
		}(partitionConsumer)
	}

	wg.Wait()
	consumer.Close()
}
```



## 4. Consumer Group

```go
// 消费组偏移量管理
offsetManager, err := sarama.NewOffsetManagerFromClient(group, client)

// 获取消费者组列表
groupMap, err := clusterAdmin.ListConsumerGroup()

// 消费组详情
descriptions, err := clusterAdmin.DescribeConsumerGroups(groups)

// 创建消费组查询消息
saramaMsgs, err := consumerGroup.Consume(ctx, topics, &consumer)

// 实现 ConsumerGroupHandler 接口
type Consumer struct {
	ready chan bool
}

func (c *Consumer) Setup(sarama.ConsumerGroupSession) error {
	close(c.ready)
	return nil
}

func (c *Consumer) Cleanup(sarama.ConsumerGroupSession) error {
	return nil
}

func (c *Consumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for message := range claim.Messages() {
		log.Printf("Message claimed: value = %s, timestamp = %v, topic = %s", string(message.Value), message.Timestamp, message.Topic)
		session.MarkMessage(message, "")
	}
	return nil
}
```

示例：

```go
func main() {
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0
	config.Consumer.Group.Rebalance.Strategy = sarama.BalanceStrategyRoundRobin

	brokers := []string{"192.168.80.240:30090", "192.168.80.241:30091", "192.168.80.242:30092"}

	// 客户端
	client, err := sarama.NewClient(brokers, config)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	// 消费者组
	ctx, cancel := context.WithCancel(context.Background())
	topics := []string{"nginx-log"}
	consumer := &NginxLogConsumer{
		ready: make(chan bool),
	}
	consumerGroup, _ := sarama.NewConsumerGroupFromClient("group-1", client)
	defer consumerGroup.Close()

	wg := &sync.WaitGroup{}
	wg.Add(1)

	go func() {
		defer wg.Done()
		for {
			if err = consumerGroup.Consume(ctx, topics, consumer); err != nil {
				log.Fatal(err)
			}

			if ctx.Err() != nil {
				return
			}

			consumer.ready = make(chan bool)
		}
	}()

	<-consumer.ready

	sigterm := make(chan os.Signal, 1)
	signal.Notify(sigterm, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-sigterm:
		log.Println("terminating: via signal")
	case <-ctx.Done():
		log.Println("terminating: context cancelled")
	}

	cancel()
	wg.Wait()
}

type NginxLogConsumer struct {
	ready chan bool
}

func (c *NginxLogConsumer) Setup(session sarama.ConsumerGroupSession) error {
	close(c.ready)
	return nil
}

func (c *NginxLogConsumer) Cleanup(session sarama.ConsumerGroupSession) error {
	return nil
}

func (c *NginxLogConsumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for msg := range claim.Messages() {
		fmt.Printf("Topic:%s, Partition:%d, Offset:%d, Key:%s, Value:%s\n", msg.Topic, msg.Partition, msg.Offset, msg.Key, msg.Value)
		session.MarkMessage(msg, "")

		time.Sleep(time.Second)
	}
	return nil
}
```

