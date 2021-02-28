# 1. Etcd

Etcd: 高可用分布式key-value存储，可用于配置共享额服务发现

类似项目：zookeeper、consul

实现算法：基于raft算法的强一致性，高可用的服务存储目录

应用场景：

- 服务发现和服务注册
- 配置中心
- 分布式锁
- master选举

安装客户端：

```bash
go get go.etcd.io/etcd/client/v3
```



# 2. MVVC

数据库领域，高并发下数据冲突的两种解决方案：

- 想办法避免冲突。使用**悲观锁**来确保同一时刻只有一个人能对数据进行更改，常见的实现：

  - 读写锁 (Read/Write Locks)

  - 两阶段锁 (Two-Phase Locking)

- 允许冲突，但发生冲突时，有能力解决。即**乐观锁**, 乐观的认为冲突不会发生，除非检测到确实产生了冲突，常见的实现：
  - 逻辑时钟 (Logical Clock)
  - MVCC：Multi-version Concurrent Control

MVCC 中的版本一般选择使用时间戳或者事务ID来标识。在处理一个写请求时，MVCC不是简单的有新值覆盖旧值，而是为这一项添加一个新版本数据。在读取一个数据项时，要先确定读取的版本，然后根据版本找到对应的数据。MVCC中的读操作永远不会被阻塞。



# 3. 实例

```go
var endpoints = []string{"localhost:2379"}

func connect() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   endpoints,
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatalf("connect to etcd server error: %v", err)
	}
	defer cli.Close()

	log.Println("connect to etcd succeeded.")
}

func put() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   endpoints,
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatalf("connect to etcd server error: %v", err)
	}
	defer cli.Close()
	log.Println("connect to etcd succeeded.")

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	_, err = cli.Put(ctx, "/logagent/conf", "sample_value")
	cancel()
	if err != nil {
		log.Fatalf("put error: %v", err)
	}
	log.Println("put succeeded.")

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	resp, err := cli.Get(ctx, "/logagent/conf")
	cancel()
	if err != nil {
		log.Fatalf("get error: %v", err)
	}
	log.Println("get succeeded.")
	for _, v := range resp.Kvs {
		fmt.Printf("get %s: %s\n", v.Key, v.Value)
	}
}

func watch() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   endpoints,
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatalf("connect to etcd server error: %v", err)
	}
	defer cli.Close()
	log.Println("connect to etcd succeeded.")

	// 开多个线程去修改配置
	for i := 0; i < 10; i++ {
		go func(i int) {
			str := fmt.Sprintf("change-%d", i)
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			_, err = cli.Put(ctx, "/logagent/conf/", str)
			cancel()
			if err != nil {
				log.Fatalf("put error: %v", err)
			}
		}(i)
	}

	for {
		rch := cli.Watch(context.Background(), "/logagent/conf/")
		for resp := range rch {
			for _, ev := range resp.Events {
				log.Printf("watch: %s %q: %q\n", ev.Type, ev.Kv.Key, ev.Kv.Value)
			}
		}
	}
}
```

