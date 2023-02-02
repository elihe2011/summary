# 1. 简介

## 1.1 gRPC

gRPC 是一个高性能、开源和通用的RPC框架，面向移动和 HTTP/2 设计

特点：

- 强大的 IDL，使用 Protocol Buffers 作为数据交换格式
- 跨语言、跨平台
- 支持HTTP2，双向传输、多路复用、认证等

```sh
go get google.golang.org/grpc
```



grpc下常用包：

- metadata: 提供方法对 grpc 元数据结构MD 进行获取和处理
- credentials: 封装了客户端对服务端进行身份验证所需的所有状态，并做出各种断言
- codes: grpc 标准错误码



## 1.2 Protocol Buffers v3

下载并解压bin目录下的 `proto.exe` 到 `$GOPATH/bin`

https://github.com/protocolbuffers/protobuf/releases/download/v3.19.4/protoc-3.19.4-win64.zip



## 1.3 Plugins

**go语言插件**：根据`.proto`文件生成一个后缀为`.pb.go`的文件，包含所有`.proto`文件中定义的类型及其序列化方法。

```sh
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
```

**grpc插件**：

```bash
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
```

该插件会生成一个后缀为`_grpc.pb.go`的文件，其中包含：

- 一种接口类型(或存根) ，供客户端调用的服务方法。
- 服务器要实现的接口类型。



## 1.4 版本检查

```bash
> protoc --version
libprotoc 3.19.4

> protoc-gen-go --version
protoc-gen-go v1.28.1

> protoc-gen-go-grpc --version
protoc-gen-go-grpc 1.2.0
```



# 2. 入门示例

## 2.1 工程

新建工程后，执行：

```bash
go mod init gitee.com/elihe/grpc

mkdir -p {proto,server,client}
```



## 2.2 IDL

在 proto 目录下创建 idl 文件 `hello.proto`

```protobuf
syntax = "proto3";

package proto;

// 指定生成的go文件目录
option go_package = "../pb;pb";

message HelloRequest {
  string name = 1;
}

message HelloResponse {
  string reply = 1;
}

service Greeter {
  rpc SayHello(HelloRequest) returns (HelloResponse) {};
}
```

生成源码文件 `hello.pb.go` 和 `hello_grpc.pb.go`

```bash
protoc --go_out=. hello.proto
protoc --go-grpc_out=. hello.proto

# 可合并命令行
protoc --go_out=. --go-grpc_out=. hello.proto
```

**不建议使用**：`github`版本的`protoc-gen-go`，它不会生成`xxx_grpc.pb.go`，只会生成`xxx.pb.go`一个文件

```bash
protoc --go_out=plugins=grpc:. hello.proto
```



## 2.3 服务端

```go
type server struct {
	pb.UnimplementedGreeterServer
}

func (s *server) SayHello(ctx context.Context, r *pb.HelloRequest) (*pb.HelloResponse, error) {
	return &pb.HelloResponse{Reply: "Hello " + r.GetName()}, nil
}

func main() {
	s := grpc.NewServer()

	// 注册服务
	pb.RegisterGreeterServer(s, &server{})

	ln, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("grpc server listening on :9002")
	s.Serve(ln)
}
```

运行服务端：

```bash
go run main.go
```



## 2.4 客户端

```go
func main() {
	conn, err := grpc.Dial(":9002", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

    // 客户端
	client := pb.NewGreeterClient(conn)
    
	sayHello(client)
}

func sayHello(c pb.GreeterClient) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
    defer cancel()
    
	resp, err := c.SayHello(ctx, &pb.HelloRequest{Name: "eli"})
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("got reply: %q\n", resp.GetReply())
}
```

运行客户端：

```bash
go run main.go
```



# 3. 流式RPC

上述示例，客户端发起了一个RPC请求到服务端，服务端进行业务处理并返回响应给客户端，它是 gRPC 最基本的一种工作方式(Unary RPC)。除此之外，依托于HTTP2，gRPC还支持流式RPC(Streaming RPC)

gRPC 的流式，有三种类型：

- Server-side Streaming
- Client-side Streaming
- Bidirectional Streaming

适合用 Streaming RPC 的场景：

- 大规模数据包
- 实时场景



## 3.1 服务端流式RPC

- 单向流
- Server 为 Stream，多次向客户端发送数据
- Client 为普通 RPC 请求



**Step 1**: 定义服务

```protobuf
// 服务端返回流式数据
rpc LotsOfReplies(HelloRequest) returns (stream HelloResponse) {};
```



**Step 2**: 服务端实现

```go
func (s *server) LotsOfReplies(r *pb.HelloRequest, stream pb.Greeter_LotsOfRepliesServer) error {
	greetings := []string{
		"您好",
		"Hello",
		"Bonjour",
		"Hola",
		"أهلا",
	}

	for _, word := range greetings {
		resp := &pb.HelloResponse{Reply: word + " " + r.GetName()}

		err := stream.Send(resp)
		if err != nil {
			return err
		}
	}

	return nil
}
```

其中：`stream.Send()` 方法，实现调用了 `SendMsg` 方法，其作用如下

- 消息体（对象）序列化
- 压缩序列化后的消息体
- 对正在传输的消息体增加5个字节的header
- 判断消息体总长度是否大于预设的maxSendMessageSize (默认math.MaxInt32)，超过则报错
- 写入给流的数据集

```go
func (x *greeterLotsOfRepliesServer) Send(m *HelloResponse) error {
	return x.ServerStream.SendMsg(m)
}
```



**Step 3**: 客户端实现

```go
func lotsOfReplies(c pb.GreeterClient) {
	ctx, cancel := context.WithTimeout(context.TODO(), time.Second)
	defer cancel()

	stream, err := c.LotsOfReplies(ctx, &pb.HelloRequest{Name: "rania"})
	if err != nil {
		log.Fatal(err)
	}

    // 接收流式数据
	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			break
		}

		if err != nil {
			log.Fatal(err)
		}

		log.Printf("got reply: %q\n", resp.GetReply())
	}
}
```

其中，`stream.Recv()` 方法，实现调用`RecvMsg()`方法，其作用如下：

- 阻塞等待
- 流结束 (Close)时，返回 io.EOF
- 可能的错误
  - io.EOF
  - io.ErrUnexpectedEOF
  - transport.ConnectionError
  - google.golang.org/grpc/codes

```go
func (x *greeterLotsOfRepliesClient) Recv() (*HelloResponse, error) {
	m := new(HelloResponse)
	if err := x.ClientStream.RecvMsg(m); err != nil {
		return nil, err
	}
	return m, nil
}
```



## 3.2 客户端流式RPC

- 单向流
- 客户端多次RPC请求服务端
- 服务端发起一次响应给客户端



**Step 1**: 定义服务

```protobuf
// 客户端发送流式数据
rpc LotsOfGreetings(stream HelloRequest) returns (HelloResponse) {};
```



**Step 2**: 服务端实现

```go
func (s *server) LotsOfGreetings(stream pb.Greeter_LotsOfGreetingsServer) error {
	reply := "hello "
	for {
		req, err := stream.Recv()

		if err == io.EOF {
			// 接收完毕，统一响应
			return stream.SendAndClose(&pb.HelloResponse{Reply: reply})
		}

		if err != nil {
			return err
		}

		reply += req.GetName() + ", "
	}
}
```



**Step 3**: 客户端实现

```go
func lotsOfGreetings(c pb.GreeterClient) {
	ctx, cancel := context.WithTimeout(context.TODO(), time.Second)
	defer cancel()

	// 客户端流式RPC
	stream, err := c.LotsOfGreetings(ctx)
	if err != nil {
		log.Fatal(err)
	}

	names := []string{"tom", "daniel", "lucy", "dianna"}
	for _, name := range names {
		// 发送流式数据
		err = stream.Send(&pb.HelloRequest{Name: name})
		if err != nil {
			log.Fatal(err)
		}
	}

	// 接收并关闭流
	resp, err := stream.CloseAndRecv()
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("got reply: %q\n", resp.GetReply())
}
```



## 3.3 双向流式RPC

**Step 1**: 定义服务

```protobuf
// 双向流式数据
rpc BidiHello(stream HelloRequest) returns (stream HelloResponse) {};
```



**Step 2**: 服务端实现

```go
func (s *server) BidiHello(stream pb.Greeter_BidiHelloServer) error {
	for {
		req, err := stream.Recv()
		if err == io.EOF {
			return nil
		}

		if err != nil {
			return err
		}

		reply := robot(req.GetName())

		err = stream.Send(&pb.HelloResponse{Reply: reply})
		if err != nil {
			return err
		}
	}
}

func robot(s string) string {
	s = strings.ReplaceAll(s, "吗", "")
	s = strings.ReplaceAll(s, "吧", "")
	s = strings.ReplaceAll(s, "你", "我")
	s = strings.ReplaceAll(s, "？", "!")
	s = strings.ReplaceAll(s, "?", "!")
	return s
}
```



**Step 3**: 客户端实现

```go
func bidiHello(c pb.GreeterClient) {
	ctx, cancel := context.WithTimeout(context.TODO(), 5*time.Minute)
	defer cancel()

	stream, err := c.BidiHello(ctx)
	if err != nil {
		log.Fatal(err)
	}

	// 退出控制
	quit := make(chan struct{})

	// 服务端响应处理
	go func() {
		for {
			resp, err := stream.Recv()
			if err == io.EOF {
				// 处理完毕
				close(quit)
				return
			}

			if err != nil {
				log.Fatal(err)
			}

			log.Printf("got reply: %q\n", resp.GetReply())
		}
	}()

	// 用户输入
	reader := bufio.NewReader(os.Stdin)
	for {
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)
		if len(input) == 0 {
			continue
		}

		// 主动退出
		if strings.ToUpper(input) == "QUIT" {
			break
		}

		err = stream.Send(&pb.HelloRequest{Name: input})
		if err != nil {
			log.Fatal(err)
		}
	}

	// 关闭发送流
	stream.CloseSend()
	<-quit
}
```



# 4. TLS 认证

在 MSYS2 客户端下，执行 openssl 命令 



## 4.1 自签公钥

客户端和服务使用同一套证书



生成证书：

```bash
mkdir certs && cd certs

# 私钥
openssl ecparam -genkey -name secp384r1 -out server.key

# 自签公钥
openssl req -new -x509 -sha256 -key server.key -out server.pem -days 3650 \
  -subj "/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/OU=T/CN=grpc.exp.io" \
  -addext "subjectAltName=DNS:grpc.exp.io"
```



服务端：

```go
func main() {
	// 读取证书文件
	creds, err := credentials.NewServerTLSFromFile("../certs/server.pem", "../certs/server.key")
	if err != nil {
		log.Fatal(err)
	}

	// 使用证书
	s := grpc.NewServer(grpc.Creds(creds))

	// 注册服务
	pb.RegisterGreeterServer(s, &server{})

	ln, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("grpc server listening on :9002")
	s.Serve(ln)
}
```



客户端：

```go
func main() {
	// 读取证书
	creds, err := credentials.NewClientTLSFromFile("../certs/server.pem", "grpc.exp.io")

	// 使用证书
	conn, err := grpc.Dial(":9002", grpc.WithTransportCredentials(creds))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	client := pb.NewGreeterClient(conn)
	sayHello(client)
}
```



## 4.2 CA证书

根证书(root certificate)是属于根证书颁发机构（CA）的公钥证书。可以通过验证CA的签名从而信任CA，任何人都可以得到CA的证书（含公钥），用以验证它所签发的证书。

CSR (Certificate Signing Request)：证书请求文件。主要作用是 CA 会利用 CSR 文件进行签名使得攻击者无法伪装或篡改原有证书。

### 4.2.1 生成证书

```bash
#-1. CA证书------------------------------------------------------------
# CA私钥
openssl genrsa -out ca.key 2048

# CA证书
openssl req -new -x509 -days 7200 -key ca.key -out ca.pem  \
  -subj "/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/OU=T"
  
#-2. 服务端证书------------------------------------------------------------
# 服务端私钥
openssl ecparam -genkey -name secp384r1 -out server.key

# 服务端CSR
openssl req -new -key server.key -out server.csr \
  -subj "/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/OU=T"

# 基于CA签发：注意指定域名
openssl x509 -req -sha256 -CA ca.pem -CAkey ca.key -CAcreateserial -days 3650 -in server.csr -out server.pem \
  -extfile <(printf "subjectAltName=DNS:grpc.exp.io")

#-3. 客户端端证书------------------------------------------------------------
# 客户端私钥
openssl ecparam -genkey -name secp384r1 -out client.key

# 客户端CSR
openssl req -new -key client.key -out client.csr  \
  -subj "/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/OU=T"

# 基于CA签发：注意指定域名
openssl x509 -req -sha256 -CA ca.pem -CAkey ca.key -CAcreateserial -days 3650 -in client.csr -out client.pem \
  -extfile <(printf "subjectAltName=DNS:grpc.exp.io")
```



### 4.2.2 认证代码

服务端：

```go
type Server struct {
	CaFile   string
	CertFile string
	KeyFile  string
}

func (s *Server) GetCredentialsByCA() (credentials.TransportCredentials, error) {
	cert, err := tls.LoadX509KeyPair(s.CertFile, s.KeyFile)
	if err != nil {
		return nil, err
	}

	ca, err := ioutil.ReadFile(s.CaFile)
	if err != nil {
		return nil, err
	}

	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM(ca) {
		return nil, errors.New("certPool.AppendCertsFromPEM error")
	}

	cred := credentials.NewTLS(&tls.Config{
		Certificates: []tls.Certificate{cert},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    certPool,
	})

	return cred, nil
}

func (s *Server) GetTLSCredentials() (credentials.TransportCredentials, error) {
	return credentials.NewServerTLSFromFile(s.CertFile, s.KeyFile)
}
```



客户端：

```go
type Client struct {
	ServerName string
	CaFile     string
	CertFile   string
	KeyFile    string
}

func (c *Client) GetCredentialsByCA() (credentials.TransportCredentials, error) {
	cert, err := tls.LoadX509KeyPair(c.CertFile, c.KeyFile)
	if err != nil {
		return nil, err
	}

	ca, err := ioutil.ReadFile(c.CaFile)
	if err != nil {
		return nil, err
	}

	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM(ca) {
		return nil, errors.New("certPool.AppendCertsFromPEM error")
	}

	cred := credentials.NewTLS(&tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   c.ServerName,
		RootCAs:      certPool,
	})

	return cred, nil
}

func (c *Client) GetTLSCredentials() (credentials.TransportCredentials, error) {
	return credentials.NewClientTLSFromFile(c.CertFile, c.ServerName)
}
```



### 4.2.3 集成

服务端：

```go
func main() {
	// 证书配置
	tlsServer := gtls.Server{
		CaFile:   "../certs/ca.pem",
		CertFile: "../certs/server.pem",
		KeyFile:  "../certs/server.key",
	}

	// 获取证书
	creds, err := tlsServer.GetCredentialsByCA()
	if err != nil {
		log.Fatal(err)
	}

	// 使用证书
	s := grpc.NewServer(grpc.Creds(creds))

	// 注册服务
	pb.RegisterGreeterServer(s, &server{})

	ln, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("grpc server listening on :9002")
	s.Serve(ln)
}
```



客户端：

```go
func main() {
	// 证书配置
	tlsClient := gtls.Client{
		ServerName: "grpc.exp.io",
		CaFile:     "../certs/ca.pem",
		CertFile:   "../certs/server.pem",
		KeyFile:    "../certs/server.key",
	}

	// 获取证书
	creds, err := tlsClient.GetCredentialsByCA()

	// 使用证书
	conn, err := grpc.Dial(":9002", grpc.WithTransportCredentials(creds))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	client := pb.NewGreeterClient(conn)
	sayHello(client)
}
```



### 4.2.4 总结

大致流程：

- Client 通过请求得到 Server 端的证书
- 使用 CA 认证的根证书对 Server 端证书进行可靠性、有效性等校验
- 校验 ServerName 是否有效
- 同样，在设置了 `tls.RequireAndVerifyClientCert` 模式下，Server 也会使用 CA 认证的根证书对Client的证书进行可靠性、有效性校验。



**tls 单向认证双向认证**：

- 单向认证：只有一个对象校验对端的证书合法性。通常client来校验服务器的合法性。那么client需要一个ca.crt,服务器需要server.crt,server.key。
- 双向认证：相互校验，服务器需要校验每个client,client也需要校验服务器。server 需要 server.key、server.crt、ca.crt，client 需要 client.key、client.crt、ca.crt。



# 5. 拦截器

## 5.1 类型

- 普通方法：一元拦截器 `grpc.UnaryInterceptor`
- 流方法：流拦截器 `grpc.StreamInterceptor`



## 5.2 多拦截器

gRPC本身只能设置一个拦截器，但可以采用`go-grpc-middleware`项目来解决问题

```bash
go get github.com/grpc-ecosystem/go-grpc-middleware
```



## 5.3 示例

```go
func main() {
	// 证书配置
	tlsServer := gtls.Server{
		CaFile:   "../certs/ca.pem",
		CertFile: "../certs/server.pem",
		KeyFile:  "../certs/server.key",
	}

	// 获取证书
	cred, err := tlsServer.GetCredentialsByCA()
	if err != nil {
		log.Fatal(err)
	}

	// 服务选项
	opts := []grpc.ServerOption{
		grpc.Creds(cred),
        // 使用拦截器
		grpc_middleware.WithUnaryServerChain(
			RecoveryInterceptor,
			LoggingInterceptor,
		),
	}

	// 使用证书
	s := grpc.NewServer(opts...)

	// 注册服务
	pb.RegisterGreeterServer(s, &server{})

	ln, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatal(err)
	}

	log.Println("grpc server listening on :9002")
	s.Serve(ln)
}

func LoggingInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	log.Printf("gRPC method: %s, %v", info.FullMethod, req)
	resp, err := handler(ctx, req)
	log.Printf("gRPC method: %s, %v", info.FullMethod, resp)
	return resp, err
}

func RecoveryInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
	defer func() {
		if e := recover(); e != nil {
			debug.PrintStack()
			err = status.Errorf(codes.Internal, "Panic err: %v", e)
		}
	}()

	return handler(ctx, req)
}
```



# 6. 支持HTTP请求

## 6.1 服务端

```go
func main() {
	log.Println("grpc server listening on :9003")

	http.ListenAndServeTLS(":9003",
		"../certs/server.pem",
		"../certs/server.key",
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			log.Printf(" ProtoMajor: %d\n", r.ProtoMajor)
			log.Printf(" Content-Type: %s\n", r.Header.Get("Content-Type"))

			if r.ProtoMajor == 2 && strings.Contains(r.Header.Get("Content-Type"), "application/grpc") {
				httpServeGrpc().ServeHTTP(w, r)
			} else {
				httpServeMux().ServeHTTP(w, r)
			}
		}))
}

func httpServeGrpc() *grpc.Server {
	tlsServer := gtls.Server{
		CertFile: "../certs/server.pem",
		KeyFile:  "../certs/server.key",
	}

	cred, err := tlsServer.GetTLSCredentials()
	if err != nil {
		log.Fatalf("tlsServer.GetTLSCredentials err: %v", err)
	}

	s := grpc.NewServer(grpc.Creds(cred))

	// 注册服务
	pb.RegisterGreeterServer(s, &server{})

	return s
}

func httpServeMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("message from http server"))
	})

	return mux
}
```



## 6.2 客户端

### 6.2.1 gRPC 

```go
func main() {
	tlsClient := gtls.Client{
		ServerName: "grpc.exp.io",
		CertFile:   "../certs/server.pem",
	}

	cred, err := tlsClient.GetTLSCredentials()
	if err != nil {
		log.Fatal(err)
	}

	conn, err := grpc.Dial(":9003", grpc.WithTransportCredentials(cred))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	client := pb.NewGreeterClient(conn)
	sayHello(client)
}
```



### 6.2.2 http/1.1

```bash
curl -k --cert client.pem --key client.key https://127.0.0.1:9003

curl -k --cacert ca.pem  https://127.0.0.1:9003
```

