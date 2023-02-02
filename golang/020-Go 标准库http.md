# 1. 客户端

```go
// net/http
func Get(url string) (resp *Response, err error)
func Post(url, contentType string, body io.Reader) (resp *Response, err error)
func PostForm(url string, data url.Values) (resp *Response, err error)
func NewRequest(method, url string, body io.Reader) (*Request, error)

// net/http/httputil
func DumpResponse(resp *http.Response, body bool) ([]byte, error)
```



## 1.1 简单示例

```go
func main() {
	// 1. http请求
	req, err := http.NewRequest(http.MethodGet, "http://www.baidu.com", nil)
	req.Header.Add("User-Agent",
		"Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1")

	// 2. 检测是否重定向
	client := http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			fmt.Println("Redirect:", req)
			return nil
		},
	}

	// 3. 发起请求
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	// 4. 响应处理
	content, err := httputil.DumpResponse(resp, true)
	if err != nil {
		panic(err)
	}

	fmt.Printf("%s", content)
}
```



## 1.2 客户端封装

```go
type HttpClient struct {
	OpId    int
	OpName  string
	Method  string
	Url     string
	Body    []byte
	Query   map[string]string
	Timeout time.Duration
}

func (c *HttpClient) Do() ([]byte, error) {
	var (
		req *http.Request
		err error
	)

	client := http.Client{Timeout: c.Timeout * time.Second}

	// Body参数
	if c.Body != nil {
		req, err = http.NewRequest(c.Method, c.Url, bytes.NewBuffer(c.Body))
	} else {
		req, err = http.NewRequest(c.Method, c.Url, nil)
	}

	if err != nil {
		return nil, err
	}

	// 查询参数
	if c.Query != nil {
		q := req.URL.Query()
		for k, v := range c.Query {
			q.Add(k, v)
		}

		// assign encoded query string to http request
		req.URL.RawQuery = q.Encode()
	}

	// 生成 token
	tokenStr, err := generateToken(c.OpId, c.OpName)
	if err != nil {
		return nil, err
	}

	// 请求头
	req.Header.Add("Accept", `application/json`)
	req.Header.Add("Token", tokenStr)

	zap.L().Debug("http", zap.Any("req-header", req.Header))

	// 发送请求
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("connecting to %s refused", req.Host)
	}

	zap.L().Debug("http", zap.Any("resp-header", resp.Header))

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("error: %s", resp.Status)
	}

	defer resp.Body.Close()
	return ioutil.ReadAll(resp.Body)
}
```



# 2. 服务端

```go
// 服务端
http.ListenAndServe()
http.HandleFunc(endpoint, handler)
func Handler(w http.ResponseWriter, r *http.Request) {} // 请求处理函数
func HTTPInterceptor(h http.HandlerFunc) http.HandlerFunc {} // 中间件

// http 请求路由，多路复用器Multiplexor，它把收到的请求与一组预先定义的URL路由路径做对比，然后匹配合适的路径关联到处理器Handler
mux := http.NewServeMux()  

// http包自带的常用处理器
http.FileServer()
http.NoFoundHandler()
http.RedirectHandler()

// 处理函数
ServeHTTP(http.ResponseWriter, *http.Request)

// 默认请求路由
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Println(r.Header.Get("User-Agent"))
		w.Write([]byte("Hello World!"))
	})

	http.ListenAndServe(":8080", nil)
}

// 自定义请求路由
func main() {
	mux := http.NewServeMux()

	mux.Handle("/", http.RedirectHandler("http://baidu.com", 307))
	http.ListenAndServe(":8080", mux)
}
```



## 2.1 handler函数

```go
func SignupHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		data, err := ioutil.ReadFile("./static/view/signup.html")
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		w.Write(data)
	} else {
		r.ParseForm()  // 必须的
		username := r.Form.Get("username")
		password := r.Form.Get("password")

		if len(username) < 3 || len(password) < 5 {
			w.Write([]byte("Invalid parameter"))
			return
		}

		enc_pwd := util.Sha1([]byte(password + pwd_salt))
		ret := db.UserSignup(username, enc_pwd)
		if ret {
			w.Write([]byte("SUCCESS"))
		} else {
			w.Write([]byte("FAILED"))
		}
	}
}
```



## 2.2 中间件

```go
func HTTPInterceptor(h http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			r.ParseForm()
			username := r.Form.Get("username")
			token := r.Form.Get("token")

			if len(username) < 3 || !IsTokenValid(token) {
				w.WriteHeader(http.StatusForbidden)
				return
			}

			h(w, r)
		})
}
```



## 2.3 启动服务

```go
func main() {
	// 静态文件
	path, _ := os.Getwd()
	path = filepath.Join(path, "static")
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir(path))))

	// 路由和中间件
	http.HandleFunc("/user/signup", handler.SignupHandler)
	http.HandleFunc("/user/info", handler.HTTPInterceptor(handler.UserInfoHandler))

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
```



## 2.4 性能分析

- `import _ "net/http/pprof`
- 访问`/debug/pprof/`
- 使用`go tool pprof`分析性能


```go
import (
	"log"
	"net/http"
	_ "net/http/pprof"
	"os"
	...
)
```

查看性能：

http://localhost:8080/debug/pprof/

go tool pprof http://localhost:8080/debug/pprof/profile



# 3. 反向代理

```go
func main() {
	proxy, err := NewProxy("http://127.0.0.1:8080")
	if err != nil {
		log.Fatal(err)
	}

	// handle all requests
	http.HandleFunc("/", ProxyRequestHandler(proxy))
	log.Fatal(http.ListenAndServe(":8081", nil))
}

func NewProxy(targetHost string) (*httputil.ReverseProxy, error) {
	target, err := url.Parse(targetHost)
	if err != nil {
		return nil, err
	}

	proxy := httputil.NewSingleHostReverseProxy(target)

	// modify request
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Header.Set("X-Proxy", "Simple-Reverse-Proxy")
	}

	// modify response
	proxy.ModifyResponse = func(resp *http.Response) error {
		resp.Header.Set("X-Proxy", "Magic")

		if resp.StatusCode >= 400 {
			return fmt.Errorf("backend server error: %s", resp.Status)
		}
		return nil
	}

	// error handler
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		w.Write([]byte(err.Error()))
		w.WriteHeader(http.StatusOK)
	}

	return proxy, nil
}

func ProxyRequestHandler(proxy *httputil.ReverseProxy) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	}
}
```



# 4. 平滑升级

## 4.1 要求

**1. 正在处理的请求怎么办?**

- **等待处理完成后再退出**
- Golang 1.8+ 支持
- 即优雅的关闭
- 另外一种方式，可使用sync.WaitGroup



**2. 新进来的请求怎么办?**

- Fork一个子进程，**继承父进程的监听socket**
- 子进程启动成功后，接收新的连接
- 父进程停止接收新的连接，等已有的请求处理完毕，退出
- 优雅的重启成功



## 4.2 进程句柄继承

子进程如何继承父进程的文件句柄？

- 通过`os.Cmd`对象中的ExtraFiles参数进程传递
- 文件句柄继承实例分析

web server 优雅重启？

- **使用go1.8+的Shutdown方法进行优雅关闭**
- **使用socket继承实现，子进程接管父进程监听的socket**

信号处理：

- 通过kill命令给正常运行的程序发送信号
- 不处理的话，程序会panic处理



## 4.3 实现

```go
// net/http, 优雅关闭服务
server.Shutdown(ctx)

// os/exec, socket继承
args := []string{"-graceful"}
cmd := exec.Command(os.Args[0], args...)
cmd.Stdout = os.Stdout
cmd.Stderr = os.Stderr
cmd.ExtraFiles = []*os.File{f}  // put socket FD at the first entry
cmd.Start()
```

示例：

```go
var (
	server *http.Server
	listener net.Listener
	graceful = flag.Bool("graceful", false, "listen on fd open 3 (internal use only)")
)

func handler(w http.ResponseWriter, r *http.Request) {
	time.Sleep(20 * time.Second)
	w.Write([]byte("hello world!"))
}

func main() {
	flag.Parse()

	http.HandleFunc("/hello", handler)
	server = &http.Server{Addr: ":3001"}

	var err error
	if *graceful {
		log.Print("main: Listening to existing file descriptor 3.")
		// cmd.ExtraFiles: If non-nil, entry i becomes file descriptor 3+i.
		// when we put socket FD at the first entry, it will always be 3(0+3)
		f := os.NewFile(3, "")
		listener, err = net.FileListener(f)
	} else {
		log.Print("main: Listening on a new file descriptor.")
		listener, err = net.Listen("tcp", server.Addr)
	}

	if err != nil {
		log.Fatalf("listener error: %v", err)
	}

	go func() {
		// server.Shutdown() stop Server() immediately, thus server.Serve()
		err = server.Serve(listener)
		log.Printf("server.Server err: %v\n", err)
	}()

	signalHandler()
	log.Println("signal end")
}

func signalHandler() {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM, syscall.SIGUSR2)
	for {
		sig := <- ch
		log.Printf("signal: %v", sig)

		// timeout context for shutdown
		ctx, _ := context.WithTimeout(context.Background(), 20*time.Second)
		switch sig {
		case syscall.SIGINT, syscall.SIGTERM:
			// stop
			log.Printf("stop")
			signal.Stop(ch)
			server.Shutdown(ctx)
			log.Printf("graceful shutdown")
			return
		case syscall.SIGUSR2:
			// reload
			log.Printf("reload")
			err := reload()
			if err != nil {
				log.Fatalf("graceful restart error: %v\n", err)
			}
			server.Shutdown(ctx)
			log.Printf("graceful reload")
			return
		}
	}
}

func reload() error {
	tl, ok := listener.(*net.TCPListener)
	if !ok {
		return errors.New("listener is not tcp listener")
	}

	f, err := tl.File()
	if err != nil {
		return err
	}

	args := []string{"-graceful"}
	cmd := exec.Command(os.Args[0], args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// put socket FD at the first entry
	cmd.ExtraFiles = []*os.File{f}
	return cmd.Start()
}
```



# 5. Cookie & Session

## 5.1 Cookie

Cookie机制：

- 浏览器发送请求的时候，自动带上cookie
- 服务器可设置cookie
- 只针对单个域名，**不能跨域**

Cookie与登录鉴权：

- 用户登录成功，设置一个 `cookie：username=jack`
- 用户请求时，浏览器自动把 `cookie: username=jack` 发回服务器
- 服务器收到请求后，解析cookie中的 username，判断用户是否已登录
- 如果用户登录，鉴权成功；没有登录则重定向到注册页

Cookie的缺陷：

- 容易被伪造
- 猜到的用户名，只要用户名带到请求，就被攻破

改进方案：

- 将username生成一个唯一的 uuid
- 用户请求时，将这个uuid发到服务器
- 服务端通过查询这个uuid，反查是哪个用户



## 5.2 Session

Session机制：

- 在服务端生成的id以及保存id对应用户信息的机制，叫做session机制
- Session和Cookie共同构建了账号鉴权体系
- Cookie保存在客户端，session保存在服务端
- 服务端登录成功后，就分配一个无法伪造的sessionid，存储在用户的机器上，以后每次请求的时候，都带上这个sessionid，就可以达到鉴权的目的



## 5.3 使用Cookie

```go
// 设置cookie
sessionId := userSession.Id()
cookie := &http.Cookie{
	Name:     CookieSessionId,
	Value:    sessionId,
	MaxAge:   CookieMaxAge,		
    HttpOnly: true,
	Path:     "/",
}
http.SetCookie(w, &cookie)

// 读取cookie
cookie := http.Request.Cookie("key")
cookies := http.Request.Cookies()
```



