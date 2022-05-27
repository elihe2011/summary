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

