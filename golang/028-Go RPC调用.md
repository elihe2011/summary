# 1. RPC

- 客户端(client): 服务调用的发起方
- 客户端存根(client Stub): 
  - 运行在客户端机器上
  - 存储调用服务器地址
  - 将客户端请求数据信息打包
  - 通过网络发给服务端存根程序
  - 接收服务端响应的数据包，解析后给客户端
- 服务端(server): 服务提供者
- 服务端存根(server Stub):
  - 存在与服务端机器上
  - 接收客户端Stub程序发送来请求消息数据包
  - 调用服务端的程序方法
  - 将结果打包成数据包发给客户端Stub程序

![reflect_1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rpc/rpc_flow.png)

# 2. Go 语言实现 RPC

- Golang 提供RPC标准包，支持开发 RPC 服务端和客户端，采用 gob 编码。
- 支持三种请求方式：HTTP、TCP 和 JSONRPC
- Golang RPC 函数必须特定的格式写法才能被远程调用，格式如下：

```go
func (t *T) MethodName(argType T1, replyType *T2) error
```

T1 和 T2 必须能被 encoding/gob 包编码和解码



# 3. RPC HTTP 调用 (异步调用)

## 3.1 服务端

```go
type Arguments struct {
	A int
	B int
}

type DemoRpc struct {}

func (d *DemoRpc) Add(req Arguments, resp *int) error {
	*resp = req.A + req.B
	return nil
}

func (d *DemoRpc) Minus(req Arguments, resp *int) error {
	*resp = req.A - req.B
	return nil
}

func (d *DemoRpc) Div(req Arguments, resp *int) error {
	// simulate time-consuming operations
	for i := 0; i < 5; i++ {
		log.Printf("Round %d, sleeping...\n", i)
		time.Sleep(time.Second)
	}

	if req.B == 0 {
		return errors.New("divided by zero")
	}

	*resp = req.A / req.B

	log.Printf("Div done.")
	return nil
}

func main() {
	//rpc.Register(new(DemoRpc))
	rpc.RegisterName("DemoRpc", new(DemoRpc)) // same as above

	rpc.HandleHTTP()

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal(err.Error())
	}
}
```



## 3.2 客户端

```go
type Arguments struct {
	A int
	B int
}

func main() {
	client, err := rpc.DialHTTP("tcp", ":8080")
	if err != nil {
		log.Fatal(err.Error())
	}

	args := Arguments{5, 7}
	var resp int

	err = client.Call("DemoRpc.Add", args, &resp)
	if err != nil {
		log.Fatal(err.Error())
	}
	log.Printf("DemoRpc Add(%d, %d): %v\n", args.A, args.B, resp)

	err = client.Call("DemoRpc.Minus", args, &resp)
	if err != nil {
		log.Fatal(err.Error())
	}
	log.Printf("DemoRpc Minus(%d, %d): %v\n", args.A, args.B, resp)

	args = Arguments{5, 0}
/*	err = client.Call("DemoRpc.Div", args, &resp)
	if err != nil {
		log.Fatal(err.Error())
	}
	log.Printf("DemoRpc Div(%d, %d): %v\n", args.A, args.B, resp)*/

	// async
	call := client.Go("DemoRpc.Div", args, &resp, nil)
	for {
		select {
		case <-call.Done:
			if call.Error != nil {
				log.Fatal(call.Error.Error())
			}
			log.Printf("DemoRpc Div(%d, %d): %v\n", args.A, args.B, resp)
			return
		default:
			log.Println("waiting...")
			time.Sleep(time.Second)
		}
	}
}
```



# 4. JSONRPC 

## 4.1 服务端

```go
type JsonParams struct {
	X int
	Y int
}

type JsonRpc struct{}

func (*JsonRpc) Add(req JsonParams, resp *int) error {
	*resp = req.X + req.Y
	return nil
}

func main() {
	rpc.RegisterName("JsonRpc", new(JsonRpc))

	ln, err := net.Listen("tcp", ":8081")
	if err != nil {
		log.Fatal(err.Error())
	}

	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Println(err.Error())
			continue
		}

		log.Printf("%v connected\n", conn.RemoteAddr().String())

		go jsonrpc.ServeConn(conn)
	}
}
```



## 4.2 客户端 （Golang)

```go
type JsonParams struct {
	X int
	Y int
}

func main() {
	client, err := jsonrpc.Dial("tcp", ":8081")
	if err != nil {
		log.Fatal(err.Error())
	}

	req := JsonParams{2, 8}
	var resp int

	err = client.Call("JsonRpc.Add", req, &resp)
	if err != nil {
		log.Fatal(err.Error())
	}

	log.Printf("JsonRpc.Add(%d, %d): %d\n", req.X, req.Y, resp)
}
```



## 4.3 客户端 (Python)

```python
def main():
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.connect(('localhost', 8081))

    payload = {
        "method": "JsonRpc.Add",
        "params": [{'X': 1, 'Y': 7}],
        "jsonrpc": "1.0",
        "id": 0,
    }

    client.send(json.dumps(payload).encode('utf-8'))

    data = client.recv(1024)
    msg = json.loads(data.decode('utf-8'))
    print(msg.get('result'))
```



## 4.4 客户端 （Telnet)

```bash
$ telnet localhost 8081

{"method": "JsonRpc.Div", "params": [{"X":5,"Y":3}], "id": 1}
{"id":1,"result":null,"error":"rpc: can't find method JsonRpc.Div"}

{"method": "JsonRpc.Add", "params": [{"X":5,"Y":3}], "id": 1}
{"id":1,"result":8,"error":null}
```

