# 1. 概述

**基本功能**：

- 多种协议代理：tcp, http, websocket, grpc

- 多种负载均衡策略：轮询、加权轮询、一致性hash
- 下游服务发现：主动探测、自动服务发现
- 横向扩容：增加机器就能解决高并发



**高可用、高并发需求**：

- 限流：请求 QPS 限制
- 熔断：错误率到达阈值熔断服务
- 降级：确保核心业务可用
- 权限认证：拦截没有权限的用户



# 2. 网络代理

## 2.1 转发和代理

### 2.1.1 网络转发

由路由器对报文进行转发，中间可能会修改报文

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/network-forward.png) 



### 2.1.2 网络代理

用户不直接连接服务器，而是通过代理服务器转发请求到目标服务器，目标服务器响应后再通过代理回传给用户

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/network-proxy.png) 



## 2.2 代理类型

### 2.2.1 正向代理

是一种客户端代理技术，帮助客户端访问无法直接访问的服务资源，可隐藏用户的真实IP，比如浏览器的web代理、VPN等

```go
type Proxy struct{}

func main() {
	log.Println("serve on :8080")
	http.Handle("/", &Proxy{})
	http.ListenAndServe(":8080", nil)
}

func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Printf("received request, method: %s, host: %s, remote: %s", r.Method, r.Host, r.RemoteAddr)

	// 1. 请求重写
	fr := new(http.Request)
	*fr = *r // 浅拷贝
	if clientIP, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		if prior, ok := r.Header["X-Forwarded-For"]; ok {
			clientIP = strings.Join(prior, ",") + "," + clientIP
		}
		fr.Header.Set("X-Forwarded-For", clientIP)
	}

	// 2. 请求下游
	transport := http.DefaultTransport
	resp, err := transport.RoundTrip(fr)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		return
	}

	// 3. 将下游响应返回
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Set(key, value)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
	resp.Body.Close()
}
```



### 2.2.2 反向代理

是一种服务端代理技术，实现服务器负载均衡、缓存、提供安全校验等，可隐藏服务器真实IP，比如 LVS、nginx等

示例：

```go
// server.go
func main() {
	rs1 := &RealServer{"127.0.0.1:3000"}
	rs1.Run()

	rs2 := &RealServer{"127.0.0.1:4000"}
	rs2.Run()

	sigterm := make(chan os.Signal)
	signal.Notify(sigterm, syscall.SIGINT, syscall.SIGTERM)
	<-sigterm
}

type RealServer struct {
	Addr string
}

func (s *RealServer) Run() {
	log.Printf("start http server: %s", s.Addr)

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.HelloHandler)
	mux.HandleFunc("/error", s.ErrorHandler)
	mux.HandleFunc("/timeout", s.TimeoutHandler)

	server := &http.Server{
		Addr:         s.Addr,
		Handler:      mux,
		WriteTimeout: time.Second * 3,
	}

	go func() {
		log.Fatal(server.ListenAndServe())
	}()
}

func (s *RealServer) HelloHandler(w http.ResponseWriter, r *http.Request) {
	uPath := fmt.Sprintf("http://%s%s\n", s.Addr, r.URL.Path)
	realIP := fmt.Sprintf("RemoteAddr=%s,X-Forwarded-For=%v,X-Real-Ip=%v\n", r.RemoteAddr, r.Header.Get("X-Forwarded-For"), r.Header.Get("X-Real-Ip"))
	header := fmt.Sprintf("headers =%v\n", r.Header)
	io.WriteString(w, uPath)
	io.WriteString(w, realIP)
	io.WriteString(w, header)
}

func (s *RealServer) ErrorHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusInternalServerError)
	w.Write([]byte("error handler"))
}

func (s *RealServer) TimeoutHandler(w http.ResponseWriter, r *http.Request) {
	time.Sleep(6 * time.Second)
	w.Write([]byte("timeout handler"))
}

// proxy.go
func main() {
	log.Println("start server on :8080")
	http.HandleFunc("/", handler) // 无法测试子级path
	http.ListenAndServe(":8080", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
	// 1. 解析代理地址
	u, _ := url.Parse(proxyAddr)

	r.URL.Scheme = u.Scheme
	r.URL.Host = u.Host
	r.URL.Path = u.Path

	// 2. 请求下游
	transport := http.DefaultTransport
	resp, err := transport.RoundTrip(r)
	if err != nil {
		log.Printf("catch error: %v", err)
		w.WriteHeader(http.StatusBadGateway)
		return
	}

	// 3. 返回下游响应
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Set(key, value)
		}
	}
	defer resp.Body.Close()
	bufio.NewReader(resp.Body).WriteTo(w)
}
```



**基于ReverseProxy实现**：

```go
// reverse_proxy.go
func main() {
	rs1 := "http://127.0.0.1:3000"
	url1, _ := url.Parse(rs1)

	proxy := httputil.NewSingleHostReverseProxy(url1)

	log.Println("start server on :8080")
	http.ListenAndServe(":8080", proxy)
}
```



**ReverseProxy更改Header头内容**:

- "X-Forwarded-For": 标记客户端地址每个方向服务器代理的IP
- "X-Real-IP": 实际请求的标记
- "Connection": 标记连接是关闭、长连接等状态
- "TE": 标记传输类型是什么
- "Trailer": 允许发送方在消息后面添加的一些源信息

