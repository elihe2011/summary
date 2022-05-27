# 1. 入门

## 1.1 安装

```bash
go get -u github.com/go-redis/redis
```



## 1.2 初始化连接

```go
const (
	REDIS_IP   = "127.0.0.1"
	REDIS_PORT = "6379"
	REDIS_PWD  = ""
	REDIS_DB   = 0
)

var (
	ctx = context.Background()
	rdb *redis.Client
)

func init() {
    // 普通连接
    var rdb *redis.Client
	rdb = redis.NewClient(&redis.Options{
		Addr:     "192.168.31.60:6379",
		Password: "",
		DB:       0,
		PoolSize: 100,
	})
    
    // 哨兵模式
    var rdb *redis.Client
    rdb = redis.NewFailoverClient(&redis.FailoverOptions{
		MasterName:    "master",
		SentinelAddrs: []string{"10.40.85.1:6379", "10.40.85.3:6379"},
	})
    
    // 集群模式
    var rdb *redis.ClusterClient
    rdb = redis.NewClusterClient(&redis.ClusterOptions{
		Addrs: []string{"10.40.32.1:6379", "10.40.32.2:6379", "10.40.32.3:6379"},
	})

	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
	defer cancel()

    // 连通性测试
	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		panic(err)
	}
}
```



# 2. 操作

## 2.1 基本操作

```go
func Basic() {
	keys := rdb.Keys(ctx, "*").Val()
	fmt.Println(keys)

	size := rdb.DBSize(ctx).Val()
	fmt.Println(size)

	exist := rdb.Exists(ctx, "name", "age")
	fmt.Println(exist)

	del := rdb.Del(ctx, "abc").Val()
	fmt.Println(del)

	ttl := rdb.TTL(ctx, "age").Val()
	fmt.Println(ttl)

	expire := rdb.Expire(ctx, "age", time.Second*60).Val()
	fmt.Println(expire)

	_type := rdb.Type(ctx, "name").Val()
	fmt.Println(_type)

	key := rdb.RandomKey(ctx).Val()
	fmt.Println(key)
}
```



## 2.2 String

```go
func String() {
	var ret interface{}

	ret = rdb.Set(ctx, "name", "eli", time.Hour*24).Val()
	fmt.Println(ret)

	// set if not exist
	ret = rdb.SetNX(ctx, "name", "eli", time.Hour).Val()
	fmt.Println(ret)

	// set if exist
	ret = rdb.SetXX(ctx, "name", "eli", time.Hour*12).Val()
	fmt.Println(ret)

	ret = rdb.Get(ctx, "name")
	fmt.Println(ret)

	ret = rdb.MGet(ctx, "name", "age")
	fmt.Println(ret)

	ret = rdb.Incr(ctx, "age").Val()
	fmt.Println(ret)

	ret = rdb.Decr(ctx, "age").Val()
	fmt.Println(ret)

	ret = rdb.Append(ctx, "name", "he")
	fmt.Println(ret)

	ret = rdb.StrLen(ctx, "name")
	fmt.Println(ret)
}
```



## 2.3 Hashmap

```go
func Hashmap() {
	key := "account"
	field := "name"
	fields := map[string]interface{}{
		"city":   "beijing",
		"age":    27,
		"skills": "golang",
	}

	rdb.HSet(ctx, key, field, "jack")
	rdb.HMSet(ctx, key, fields)

	name := rdb.HGet(ctx, key, "name")
	fmt.Println(name)

	items := rdb.HKeys(ctx, key).Val()
	fmt.Println(items)

	vals := rdb.HVals(ctx, key).Val()
	fmt.Println(vals)

	exist := rdb.HExists(ctx, key, "city")
	fmt.Println(exist)

	rdb.HIncrBy(ctx, key, "age", 1)

	values := rdb.HMGet(ctx, key, "name", "age").Val()
	fmt.Println(values)

	valuesAll := rdb.HGetAll(ctx, key).Val()
	fmt.Println(valuesAll)
}
```



## 2.4 List

```go
func List() {
	key := "list"
	rdb.Del(ctx, key)

	for i := 0; i < 5; i++ {
		rdb.RPush(ctx, key, strconv.Itoa(i))
	}

	for i := 5; i < 10; i++ {
		rdb.LPush(ctx, key, strconv.Itoa(i))
	}

	length := rdb.LLen(ctx, key).Val()
	fmt.Println(length)

	value := rdb.LIndex(ctx, key, 1).Val()
	fmt.Println(value)

	rdb.LSet(ctx, key, 1, "golang")

	value = rdb.LPop(ctx, key).Val()
	fmt.Println(value)

	n := rdb.LRem(ctx, key, 0, "5").Val()
	fmt.Println(n)

	l := rdb.LRange(ctx, key, 0, -1).Val()
	fmt.Println(l)
}
```



## 2.5 Set

```go
func Set() {
	key1 := "set1"
	key2 := "set2"
	rdb.Del(ctx, key1, key2)

	rand.Seed(time.Now().UnixNano())
	for i := 0; i < 5; i++ {
		rdb.SAdd(ctx, key1, rand.Intn(10))
		rdb.SAdd(ctx, key2, rand.Intn(10))
	}

	n1 := rdb.SCard(ctx, key1).Val()
	fmt.Println(n1)

	e1 := rdb.SIsMember(ctx, key1, 3).Val()
	fmt.Println(e1)

	v1 := rdb.SRandMember(ctx, key1).Val()
	fmt.Println(v1)

	v2 := rdb.SRandMemberN(ctx, key1, 3).Val()
	fmt.Println(v2)

	v3 := rdb.SPop(ctx, key1).Val()
	fmt.Println(v3)

	n2 := rdb.SRem(ctx, key1, 2).Val()
	fmt.Println(n2)

	v4 := rdb.SMembers(ctx, key1)
	fmt.Println(v4)

	v5 := rdb.SMembers(ctx, key2)
	fmt.Println(v5)

	v6 := rdb.SInter(ctx, key1, key2).Val()
	fmt.Println(v6)

	v7 := rdb.SUnion(ctx, key1, key2).Val()
	fmt.Println(v7)

	v8 := rdb.SDiff(ctx, key1, key2).Val()
	fmt.Println(v8)

	rdb.SInterStore(ctx, "set3", key1, key2)
	rdb.SUnionStore(ctx, "set4", key1, key2)
	rdb.SDiffStore(ctx, "set5", key1, key2)
}
```



## 2.6 SortedSet

```go
func SortedSet() {
	key1, key2 := "zset1", "zset2"
	rdb.Del(ctx, key1, key2)

	rand.Seed(time.Now().UnixNano())

	for i := 0; i < 10; i++ {
		score := float64(rand.Intn(100))
		member := "golang-" + strconv.Itoa(i)
		data := &redis.Z{
			score,
			member,
		}
		rdb.ZAdd(ctx, key1, data)
	}

	for i := 0; i < 10; i++ {
		score := float64(rand.Intn(100))
		member := "golang-" + strconv.Itoa(i)
		data := &redis.Z{
			score,
			member,
		}
		rdb.ZAdd(ctx, key2, data)
	}

	n1 := rdb.ZCard(ctx, key1)
	fmt.Println(n1)

	s1 := rdb.ZScore(ctx, key1, "golang-3").Val()
	fmt.Println(s1)

	v1 := rdb.ZIncrBy(ctx, key1, 50, "golang-3").Val()
	fmt.Println(v1)

	s2 := rdb.ZRank(ctx, key1, "golang-3").Val()
	fmt.Println(s2)

	s3 := rdb.ZRevRank(ctx, key1, "golang-3").Val()
	fmt.Println(s3)

	s4 := rdb.ZRange(ctx, key1, 0, -1).Val()
	fmt.Println(s4)

	s5 := rdb.ZRevRange(ctx, key2, 0, -1).Val()
	fmt.Println(s5)

	v2 := rdb.ZRem(ctx, key2, "golang-3").Val()
	fmt.Println(v2)

	key3, key4 := "zset3", "zset4"
	kslice := []string{key1, key2}
	wslice := []float64{1.00, 1.00}
	z := &redis.ZStore{
		kslice,
		wslice,
		"SUM",
	}

	r1 := rdb.ZInterStore(ctx, key3, z).Val()
	fmt.Println(r1)

	r2 := rdb.ZUnionStore(ctx, key4, z).Val()
	fmt.Println(r2)
}
```



## 2.7 订阅和发布

```go
func Subscription() {
	channels := []string{"news", "it", "sports", "shopping"}
	sub := rdb.PSubscribe(ctx, channels...)
	_, err := sub.Receive(ctx)
	if err != nil {
		fmt.Println(err)
	}

	ch := sub.Channel()
	for msg := range ch {
		fmt.Printf("%v: %v\n", msg.Channel, msg.Payload)
	}
}

func Publish() {
	var msg string
	channels := []string{"news", "it", "sports", "shopping"}
	rand.Seed(time.Now().UnixNano())
	for {
		fmt.Printf("please input some message: ")
		fmt.Scanln(&msg)

		if msg == "quit" {
			break
		}

		channel := channels[rand.Intn(4)]

		result := rdb.Publish(ctx, channel, msg).Val()
		if result == 1 {
			fmt.Printf("send info to [%v] success\n", channel)
		}
	}
}
```



## 2.8 操作技巧

```go
func commonExample() {
	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
	defer cancel()

	// 获取 keys
	keys, err := rdb.Keys(ctx, "*").Result()
	if err != nil {
		panic(err)
	}
	for _, key := range keys {
		fmt.Println(key)
	}

	// 自定义命令
	res, err := rdb.Do(ctx, "set", "key1", "val1").Result()
	if err != nil {
		panic(err)
	}
	fmt.Println(res)

	// 删除 keys, 适合有非常多个key时
	iter := rdb.Scan(ctx, 0, "key*", 0).Iterator()
	for iter.Next(ctx) {
		err = rdb.Del(ctx, iter.Val()).Err()
		if err != nil {
			fmt.Println(err)
		}
	}
	if err = iter.Err(); err != nil {
		panic(err)
	}
}
```



## 2.9 Pipeline

pipeline: 客户端缓冲一堆命令并一次性将它们发往服务器，可节约每个命令的网络往返时间(RTT).z

```go
func pilelineExample() {
	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
	defer cancel()

	// pipeline
	pipe := rdb.Pipeline()
	incr := pipe.Incr(ctx, "counter1")
	incr = pipe.Incr(ctx, "counter1")
	pipe.Expire(ctx, "counter", time.Second*60)
	_, err := pipe.Exec(ctx)
	fmt.Println(incr.Val(), err)

	// pipelined
	var cmd *redis.IntCmd
	_, err = rdb.Pipelined(ctx, func(pipe redis.Pipeliner) error {
		cmd = pipe.Incr(ctx, "counter2")
		pipe.Expire(ctx, "counter2", time.Second*60)
		_, err := pipe.Exec(ctx)
		return err
	})
	fmt.Println(cmd.Val(), err)
}
```



## 2.10 事务

`MULTI/EXEC`

```go
func transactionExample() {
	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
	defer cancel()

	rdb.Set(ctx, "key1", "10", time.Hour)
	rdb.Set(ctx, "key2", "5", time.Hour)

	// TxPipeline
	tx := rdb.TxPipeline()
	val1, _ := tx.IncrBy(ctx, "key1", -2).Result()
	val2, _ := tx.IncrBy(ctx, "key2", 2).Result()
	_, err := tx.Exec(ctx)
	fmt.Println(val1, val2, err)
}
```

`WATCH`: 监控某个键。在执行`EXEC`命令的这段时间里，如果有其他用户抢先对被监控的键进行了替换、更新、删除等操作，那么当用户尝试执行`EXEC`的时候，事务将失败并返回一个错误，用户可以根据这个错误选择重试事务或者放弃事务。

```go
func transactionWatch() {
	var (
		maxRetries   = 100
		routineCount = 1000
	)

	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
	defer cancel()

	// 使用 GET&SET 以事务方式更新
	increment := func(key string) error {
		// 事务函数
		txf := func(tx *redis.Tx) error {
			val, err := tx.Get(ctx, key).Int()
			if err != nil && err != redis.Nil {
				return err
			}

			// 实际业务代码，乐观锁本地操作
			val++

			// 操作仅在 watch 的 key 未发生变化时提交
			_, err = tx.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
				pipe.Set(ctx, key, val, 0)
				return nil
			})

			return err
		}

		// 重试
		for i := 0; i < maxRetries; i++ {
			err := rdb.Watch(ctx, txf, key)
			if err == nil {
				return nil
			}

			// 乐观锁丢失，重试
			if err == redis.TxFailedErr {
				continue
			}

			return err
		}

		return errors.New("increment reached maximum number of retries")
	}

	// 模拟并发修改
	var wg sync.WaitGroup
	wg.Add(routineCount)
	for i := 0; i < routineCount; i++ {
		go func() {
			defer wg.Done()
			if err := increment("counter1"); err != nil {
				fmt.Println("increment error:", err)
			}
		}()
	}

	wg.Wait()

	val, err := rdb.Get(context.TODO(), "counter1").Int()
	fmt.Println(val, err)
}
```











