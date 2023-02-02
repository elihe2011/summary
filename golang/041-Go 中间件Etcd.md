---
layout: post
title: Go Etcd
date: 2020-01-03 14:26:16
comments: true
photos: 
tags: 
categories: Golang
---



# 1. etcd 介绍

概念：高可用的分布式key-value存储，可用于配置共享和服务发现

类似项目：zookeeper 和 consul

接口：提供restful的http接口，使用简单

实现算法：基于raft算法的强一致性、高可用的服务存储目录

 应用场景:

- 服务注册与发现
- 配置中心
- 分布式锁
- master选举



# 2. etcd 安装 (docker)

```bash
$ docker pull gcr.io/etcd-development/etcd:v3.4.13 

$ rm -rf /tmp/etcd-data.tmp && mkdir -p /tmp/etcd-data.tmp

$ docker run \
  -p 2379:2379 \
  -p 2380:2380 \
  --mount type=bind,source=/tmp/etcd-data.tmp,destination=/etcd-data \
  --name etcd-gcr-v3.4.13 \
  --detach gcr.io/etcd-development/etcd:v3.4.13 \
  /usr/local/bin/etcd \
  --name s1 \
  --data-dir /etcd-data \
  --listen-client-urls http://0.0.0.0:2379 \
  --advertise-client-urls http://0.0.0.0:2379 \
  --listen-peer-urls http://0.0.0.0:2380 \
  --initial-advertise-peer-urls http://0.0.0.0:2380 \
  --initial-cluster s1=http://0.0.0.0:2380 \
  --initial-cluster-token tkn \
  --initial-cluster-state new \
  --log-level info \
  --logger zap \
  --log-outputs stderr
  
$ docker exec -it etcd-gcr-v3.4.13 /bin/sh
# etcdctl version
etcdctl version: 3.4.13
API version: 3.4
# etcdctl endpoint health
127.0.0.1:2379 is healthy: successfully committed proposal: took = 29.242978ms
# etcdctl put name jack
OK
# etcdctl get name
name
jack
```



# 3. etcd 使用



## 3.1 连接 etcd

```go
// 客户端配置
config := clientv3.Config {
  Endpoints: []string{"localhost:2379"},
  DialTimeout: 5 * time.Second,
}

// 建立连接
cli, err := clientv3.New(config)
```



## 3.2 新增或修改数据

```go
func put(cli *clientv3.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	putResp, err := cli.Put(ctx, "/logagent/conf/", "sample_value")
	cancel()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(putResp.Header.Revision)
	if putResp.PrevKv != nil {
		fmt.Println("prev Value:", putResp.PrevKv.Value)
		fmt.Println("CreateRevision:", putResp.PrevKv.CreateRevision)
		fmt.Println("ModRevision:", putResp.PrevKv.ModRevision)
		fmt.Println("Version:", putResp.PrevKv.Version)
	}
}
```



## 3.3 获取数据

```go
func get(cli *clientv3.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	getResp, err := cli.Get(ctx, "/logagent/conf/")
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	for _, ev := range getResp.Kvs {
		fmt.Printf("Get %s: %s\n", ev.Key, ev.Value)
	}
}
```



## 3.4 删除数据

```go
func del(cli *clientv3.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	delResp, err := cli.Delete(ctx, "/logagent/conf/")
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	if len(delResp.PrevKvs) > 0 {
		for _, ev := range delResp.PrevKvs {
			fmt.Printf("Delete %s: %s\n", ev.Key, ev.Value)
		}
	}

	fmt.Println(delResp.Deleted)
}
```



## 3.5 设置租期

```go
func lease(cli *clientv3.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	leaseGrantResp, err := cli.Grant(ctx, 10)
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	leaseId := leaseGrantResp.ID

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	_, err = cli.Put(ctx, "/logagent/ttl/", "10s", clientv3.WithLease(leaseId))
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	for {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		getResp, err := cli.Get(ctx, "/logagent/ttl/")
		cancel()
		if err != nil {
			log.Fatal(err)
		}

		if getResp.Count == 0 {
			fmt.Println("ttl expire")
			break
		}

		for _, ev := range getResp.Kvs {
			fmt.Printf("Get %s: %s\n", ev.Key, ev.Value)
		}

		time.Sleep(2 * time.Second)
	}
}
```



## 3.6 延迟租期

```go
func extentLease(cli *clientv3.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	leaseGrantResp, err := cli.Grant(ctx, 10)
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	leaseId := leaseGrantResp.ID

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	_, err = cli.Put(ctx, "/logagent/ttl/", "10s", clientv3.WithLease(leaseId))
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	time.Sleep(5 * time.Second)

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	leaseKeepAliveResp, err := cli.KeepAlive(ctx, leaseId)
	if err != nil {
		log.Fatal(err)
	}

	go func() {
		for {
			select {
			case keepResp := <-leaseKeepAliveResp:
				if keepResp == nil {
					fmt.Println("Lease expire")
					return
				} else {
					fmt.Println("Receive lease extent resp")
				}
			}
		}
	}()

	ctx, cancel = context.WithTimeout(context.Background(), time.Second)
	getResp, err := cli.Get(ctx, "/logagent/ttl/")
	cancel()
	if err != nil {
		log.Fatal(err)
	}

	for _, ev := range getResp.Kvs {
		fmt.Printf("Get %s: %s\n", ev.Key, ev.Value)
	}
}
```



## 3.7 watch 功能

```go
func watch(cli *clientv3.Client) {
	kv := clientv3.NewKV(cli)

	// 模拟KV变化
	go func() {
		for {
			_, _ = kv.Put(context.TODO(), "/language", "go")
			_, _ = kv.Delete(context.TODO(), "language")
			time.Sleep(time.Second)
		}
	}()

	getResp, err := kv.Get(context.TODO(), "language")
	if err != nil {
		log.Fatal(err)
	}

	for _, ev := range getResp.Kvs {
		fmt.Printf("Get %s: %s\n", ev.Key, ev.Value)
	}

	watchStartVersion := getResp.Header.Revision + 1
	fmt.Printf("Start watching from version: %d\n", watchStartVersion)

	watcher := clientv3.NewWatcher(cli)

	ctx, cancel := context.WithCancel(context.TODO())
	time.AfterFunc(5*time.Second, func() {
		cancel()
	})

	watchRespChan := watcher.Watch(ctx, "language", clientv3.WithRev(watchStartVersion))
	for watchResp := range watchRespChan {
		for _, event := range watchResp.Events {
			switch event.Type {
			case mvccpb.PUT:
				fmt.Printf("Modify: %s, %v, %v\n",
					event.Kv.Value, event.Kv.CreateRevision, event.Kv.ModRevision)

			case mvccpb.DELETE:
				fmt.Printf("Delete: %v\n", event.Kv.ModRevision)
			}
		}
	}
}
```



```go
func main() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   []string{"localhost:2379"},
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	for {
		rch := cli.Watch(context.Background(), "/logagent/conf/")

		for wresp := range rch {
			for _, ev := range wresp.Events {
				fmt.Printf("%s %q : %q\n", ev.Type, ev.Kv.Key, ev.Kv.Value)
			}
		}
	}
}
```

