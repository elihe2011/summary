# 1. 简介

## 1.1 核心术语

- Engine: 实现 ServeHTTP 接口的 Handler
- MethodTree： 根据http请求方法分别维护的路由树
- RouterGroup：路由表分组，方便中间件统一处理
- Context：上下文，在 Handler 之间传递参数



## 1.2 HttpRouter

gin 使用路由框架 httprouter，它使用动态压缩前缀树 (compact prefix trie) 或称基数树 (radix tree) ，具有共同前缀的节点拥有相同的父节点，内存开销极小，没有反射。

```go
// router.go
type Router struct {
    trees map[string]*node       // 每种请求方法，单独管理一棵树
    RedirectTrailingSlash bool   // 自动处理URL尾部的 “/”
    RedirectFixedPath bool       // 路径矫正，如../和//
    HandleMethodNotAllowed bool
	HandleOPTIONS bool           // 开启OPTIONS自动匹配, 手动匹配优先级更高
	NotFound http.Handler
	MethodNotAllowed http.Handler
	PanicHandler func(http.ResponseWriter, *http.Request, interface{})
}

// tree.go
type node struct {
	path      string
	indices   string   // 分支的首字母：indices = eu，下面的 s [earch, upport]
	wildChild bool     // 是否为参数节点，参数节点用:name表示
	nType     nodeType // static：没有handler，root: 第一个插入的节点，catchAll: 有*匹配的节点，param: 参数节点如:post
	priority  uint32   // 子节点越多，或说绑定handle方法越多的节点，priority优先级越高
	children  []*node
	handle    Handle
}
```



路由的保存：

```
Priority   Path             Handle
9          \                *<1>
3          ├s               nil
2          |├earch\         *<2>
1          |└upport\        *<3>
2          ├blog\           *<4>
1          |    └:post      nil
1          |         └\     *<5>
2          ├about-us\       *<6>
1          |        └team\  *<7>
1          └contact\        *<8>

GET("/search/", h1)
GET("/support/", h2)
GET("/blog/:post/", h3)
GET("/about-us/", h4)
GET("/about-us/team/", h5)
GET("/contact/", h6)
```



r.Handle：`r.Get`, `r.Post`等方法的具体实现

```go
func (r *Router) Handle(method, path string, handle Handle) {
	if path[0] != '/' {
		panic("path must begin with '/' in path '" + path + "'")
	}

	if r.trees == nil {
		r.trees = make(map[string]*node)
	}

    // 按方法创建路由树
	root := r.trees[method]
	if root == nil {
		root = new(node)
		r.trees[method] = root
	}

	root.addRoute(path, handle)
}
```



# 2. 使用

## 2.1 安装

```sh
go get -u github.com/gin-gonic/gin
```



## 2.2 入门

```go
func (c *Context) JSON(code int, obj interface{})
type H map[string]interface{}
```

```go
func main() {
    // 路由
    r := gin.Default()

    r.GET("/", func(c *gin.Context) {
        c.JSON(200, gin.H {
            "id": 1,
            "content": "hello world!",
        })
    })

    r.Run(":8080")
}
```



## 2.3 请求参数

### 2.3.1 路由参数

```go
func (c *Context) Param(key string) string
```

```go
func main() {
	r := gin.Default()

	r.GET("/user/:name", func(c *gin.Context) {
		name := c.Param("name")
		c.String(http.StatusOK, "hello %s", name)
	})

    // 将匹配 /user/john/ 和 /user/john/send
    // 如果没有其他路由匹配 /user/john，它将重定向到 /user/john/
	r.GET("/user/:name/*action", func(c *gin.Context) {
		name := c.Param("name")
		action := c.Param("action")

		msg := name + " is doing " + action
		c.String(http.StatusOK, msg)
	})

	r.Run()
}
```



### 2.3.2 Query参数

```go
func (c *Context) Query(key string) string 
func (c *Context) GetQuery(key string) (string, bool) 
func (c *Context) DefaultQuery(key, defaultValue string) string
```

```go
func main() {
	r := gin.Default()

	r.GET("/user", func(c *gin.Context) {
        filters := c.Query("filters")
		pageIndex := c.DefaultQuery("page_index", "1")
		pageSize := c.DefaultQuery("page_size", "10")

		c.JSON(http.StatusOK, gin.H{"filters": filters, "page_index": pageIndex, "page_size": pageSize})
    })

	r.Run()
}
```



### 2.3.3 Form参数

```go
func (c *Context) PostForm(key string) string
func (c *Context) DefaultPostForm(key, defaultValue string) string
```

```go
func main() {
	r := gin.Default()

	r.POST("/login", func(c *gin.Context) {
		username := c.PostForm("username")
		password := c.DefaultPostForm("password", "123456")

		c.JSON(http.StatusOK, gin.H{
			"username": username,
			"password": password,
		})

	})

	r.Run()
}

// curl -d 'username=tom&password=abc123' -X POST http://127.0.0.1:8080/login
```



### 2.3.4 参数相关方法

| 查询参数      | Form表单         | 说明                                    |
| :------------ | :--------------- | :-------------------------------------- |
| Query         | PostForm         | 获取key对应的值，不存在为空字符串       |
| GetQuery      | GetPostForm      | 多返回一个key是否存在的结果             |
| QueryArray    | PostFormArray    | 获取key对应的数组，不存在返回一个空数组 |
| GetQueryArray | GetPostFormArray | 多返回一个key是否存在的结果             |
| QueryMap      | PostFormMap      | 获取key对应的map，不存在返回空map       |
| GetQueryMap   | GetPostFormMap   | 多返回一个key是否存在的结果             |
| DefaultQuery  | DefaultPostForm  | key不存在的话，可以指定返回的默认值     |



## 2.4 文件操作

调整文件上传表单大小：

```go
// 给表单限制上传大小，默认 32MiB
r.MaxMultipartMemory = 128 << 20  // 128MB
```



### 2.4.1 单文件上传

```go
func upload(c *gin.Context) {
    // 限制文件大小
	err := c.Request.ParseMultipartForm(4 << 20) // 4Mb
	if err != nil {
		c.String(http.StatusBadRequest, "file is too large")
		return
	}
	
	// header, err := c.FormFile("file")
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.String(http.StatusBadRequest, err.Error())
		return
	}
	defer file.Close()

	fmt.Printf("filename: %s, size: %d", header.Filename, header.Size)
	err = saveFile(header.Filename, file)
	if err != nil {
		c.String(http.StatusBadRequest, err.Error())
		return
	}

	c.String(http.StatusOK, "uploaded!")
}

func saveFile(name string, input multipart.File) (err error) {
	var output *os.File
	output, err = os.OpenFile(name, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return
	}
	defer output.Close()

	_, err = io.Copy(output, input)
	return
}

curl -X POST http://192.168.80.1:8080/upload \
  -F "file=@/home/ubuntu/ryu-socket_20210527.tar" \
  -H "Content-Type: multipart/form-data"
```



### 2.4.2 多文件上传

```go
func uploadFiles(c *gin.Context) {
	form, err := c.MultipartForm()
	if err != nil {
		c.String(http.StatusBadRequest, err.Error())
		return
	}

	files := form.File["upload[]"]
	fmt.Printf("file numbers: %d\n", len(files))

	for i, _ := range files {
		file, err := files[i].Open()
		if err != nil {
			c.String(http.StatusBadRequest, err.Error())
			return
		}

		fmt.Printf("filename: %s, size: %d\n", files[i].Filename, files[i].Size)

		err = saveFile(files[i].Filename, file)
		if err != nil {
			c.String(http.StatusBadRequest, err.Error())
			return
		}
	}

	c.String(http.StatusOK, "uploaded")
}

curl -X POST http://192.168.80.1:8080/uploadFiles \
  -F "upload[]=@/home/ubuntu/clean_ryu_imgs.sh" \
  -F "upload[]=@/home/ubuntu/.profile" \
  -F "upload[]=@/home/ubuntu/vegeta_12.8.4_linux_amd64.tar.gz" \
  -H "Content-Type: multipart/form-data"
```



### 2.4.3 文件下载

```go
func download(c *gin.Context) {
	txt := c.Query("content")
	content := "hello, 我是文件, " + txt

	c.Writer.WriteHeader(http.StatusOK)
	c.Header("Content-Disposition", "attachment; filename=hello.txt")
	c.Header("Content-Type", "application/text/plain")
	c.Header("Accept-Length", fmt.Sprintf("%d", len(content)))
	c.Writer.Write([]byte(content))
}

curl http://192.168.80.1:8080/download?content=abc
```



# 4. 高级功能

## 4.1 路由分组

```go
func main() {
	r := gin.Default()

	v1 := r.Group("/v1")
	{
		v1.POST("/login", LoginHandler)
	}

	v2 := r.Group("/v2")
	{
		v2.POST("/login", LoginV2Handler)
    }
}
```



## 4.2 中间件

```go
func (group *RouterGroup) Use(middleware ...HandlerFunc) IRoutes
```

```go
func main() {
    // 不使用默认中间件： Logger 和 Recovery 
	r := gin.New()

	// 全局中间件
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// 路由中间件
	r.GET("/location", LocationLogger(), LocationHandler)

	// 分组中间件
	auth := r.Group("/auth")
	auth.Use(AuthRequired())
	{
		auth.POST("/user", UserHandler)
	}

	r.Run()
}
```



### 4.2.1 自定义中间件

```go
func main() {
	r := gin.New()
	r.Use(Logger())

	r.GET("/test", func(c *gin.Context) {
		time.Sleep(time.Second * 5)
		c.JSON(http.StatusOK, gin.H{
			"msg": c.MustGet("foo"),
		})
	})

	r.Run()
}

func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// before request
		t := time.Now()

		// set a variable
		c.Set("foo", "bar")

		// DO request
		c.Next()

		// after request
		latency := time.Since(t)
		log.Println(latency)

		// access the result status
		status := c.Writer.Status()
		log.Println(status)
	}
}
```



### 4.2.2 BasicAuth中间件

```go
// simulate private data
var secrets = gin.H{
	"foo":  gin.H{"email": "foo@abc.com", "phone": "13302254321"},
	"jack": gin.H{"email": "jack@abc.com", "phone": "18952098765"},
}

func main() {
	r := gin.Default()

	authorized := r.Group("/admin", gin.BasicAuth(gin.Accounts{
		"foo":  "bar",
		"jack": "1234",
	}))

	authorized.GET("/secrets", func(c *gin.Context) {
		user := c.MustGet(gin.AuthUserKey).(string)
		if secret, ok := secrets[user]; ok {
			c.JSON(http.StatusOK, gin.H{
				"user":   user,
				"secret": secret,
			})
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{
				"user":   user,
				"secret": "NO SECRET",
			})
		}
	})

	r.Run()
}
```



## 4.3 记录日志

### 4.3.1 日志文件

```go
var (
	LogSavePath    = "logs/"
	LogSaveName    = "gin"
	LogSaveFileExt = "log"
	TimeFormat     = "20060102"
)

type Level int

var (
	F *os.File

	DefaultPrefix      = ""
	DefaultCallerDepth = 2

	logger     *log.Logger
	logPrefix  = ""
	levelFlags = []string{"DEBUG", "INFO", "WRAN", "ERROR", "FATAL"}
)

const (
	DEBUG Level = iota
	INFO
	WARNING
	ERROR
	FATAL
)

func init() {
	filePath := getLogFileFullPath()
	F = openLogFile(filePath)

	// 新建日志处理
	logger = log.New(F, DefaultPrefix, log.LstdFlags)
}

func getLogFilePath() string {
	return fmt.Sprintf("%s", LogSavePath)
}

func getLogFileFullPath() string {
	prefixPath := getLogFilePath()
	suffixPath := fmt.Sprintf("%s%s.%s", LogSaveName, time.Now().Format(TimeFormat), LogSaveFileExt)

	return fmt.Sprintf("%s%s", prefixPath, suffixPath)
}

func openLogFile(filePath string) *os.File {
	_, err := os.Stat(filePath)
	switch {
	case os.IsNotExist(err):
		makeDir()
	case os.IsPermission(err):
		log.Fatalf("Permission: %v", err)
	}

	handle, err := os.OpenFile(filePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to OpenFile: %v", err)
	}

	return handle
}

func makeDir() {
	pwd, _ := os.Getwd()
	err := os.MkdirAll(pwd+"/"+getLogFilePath(), os.ModePerm)
	if err != nil {
		panic(err)
	}
}

func Debug(v ...interface{}) {
	setPrefix(DEBUG)
	logger.Println(v)
}

func Info(v ...interface{}) {
	setPrefix(INFO)
	logger.Println(v)
}

func Warn(v ...interface{}) {
	setPrefix(WARNING)
	logger.Println(v)
}

func Error(v ...interface{}) {
	setPrefix(ERROR)
	logger.Println(v)
}

func Fatal(v ...interface{}) {
	setPrefix(FATAL)
	logger.Println(v)
}

func setPrefix(level Level) {
	_, file, line, ok := runtime.Caller(DefaultCallerDepth)
	if ok {
		logPrefix = fmt.Sprintf("[%s][%s:%d]", levelFlags[level], filepath.Base(file), line)
	} else {
		logPrefix = fmt.Sprintf("[%s]", levelFlags[level])
	}

	logger.SetPrefix(logPrefix)
}
```



### 4.3.2 日志格式

```go
func main() {
	router := gin.New()

	// LoggerWithFormatter 中间件会将日志写入 gin.DefaultWriter
	// By default gin.DefaultWriter = os.Stdout
	router.Use(gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {

		// 你的自定义格式
		return fmt.Sprintf("%s - [%s] \"%s %s %s %d %s \"%s\" %s\"\n",
			param.ClientIP,
			param.TimeStamp.Format(time.RFC1123),
			param.Method,
			param.Path,
			param.Request.Proto,
			param.StatusCode,
			param.Latency,
			param.Request.UserAgent(),
			param.ErrorMessage,
		)
	}))
	router.Use(gin.Recovery())

	router.GET("/ping", func(c *gin.Context) {
		c.String(200, "pong")
	})

	router.Run(":8080")
}
```



## 4.4 模型绑定和验证

Gin使用 go-playground/validator.v10 验证参数。

将请求主体绑定到结构体中，目前支持JSON、XML、YAML和标准表单值(foo=bar&boo=baz)的绑定。

绑定方法：

- Must bind:
  - Methods: Bind, BindJSON, BindXML, BindQuery, BindYAML
  - Behavior: 底层使用MustBindWith，如果存在绑定错误，请求将被以下指令中止 `c.AbortWithError(400, err).SetType(ErrorTypeBind)`

- Should bind:
  - Methods: ShouldBind, ShouldBindJSON, ShouldBindXML, ShouldBindQuery, ShouldBindYAML
  - Behavior: 底层使用ShouldBindWith，如果存在绑定错误，则返回错误，开发人员可正确处理请求和错误


### 4.4.1 请求参数绑定

```go
type User struct {
	Username string `form:"username" json:"username" xml:"username" binding:"required"`
	Password string `form:"password" json:"password" xml:"password" binding:"required"`
}

func main() {
	r := gin.Default()

	r.POST("/login", func(c *gin.Context) {
		var user User
		//if err := c.ShouldBind(&user); err != nil {
		if err := c.ShouldBindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"code": -1,
				"msg":  err.Error(),
			})
			return
		}

		if user.Username != "admin" || user.Password != "123" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"code": -1,
				"msg":  "unauthorized",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"code": 0,
			"msg":  "ok",
		})
	})

	r.Run()
}
```



### 4.4.2 自定义校验器

```go
package main

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin/binding"

	"gopkg.in/go-playground/validator.v10"

	"github.com/gin-gonic/gin"
)

type Booking struct {
    // v8
    // CheckIn  time.Time `form:"check_in" binding:"required,bookabledate" time_format:"2006-01-02"`
    CheckIn  time.Time `form:"check_in" binding:"required" validate:"bookabledate" time_format:"2006-01-02"`
	CheckOut time.Time `form:"check_out" binding:"required,gtfield=CheckIn" time_format:"2006-01-02"`
}

func bookableDate(fl validator.FieldLevel) bool {
	if date, ok := fl.Field().Interface().(time.Time); ok {
		today := time.Now()
		if today.Before(date) {
			return true
		}
	}
	return false
}

func main() {
	r := gin.Default()

    // v10
	validate := validator.New()
	validate.RegisterValidation("bookabledate", bookableDate)

	r.GET("/book", func(c *gin.Context) {
		var book Booking
		if err := c.ShouldBindWith(&book, binding.Query); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"code": -1,
				"msg":  err.Error(),
			})
			return
		}

        // v10: 绑定和校验分离
		err := validate.Struct(book)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"code": -1,
				"msg":  err.Error(),
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"code": 0,
			"msg":  "ok",
		})
	})

	r.Run()
}
```



### 4.4.3 绑定uri

```go
type Person struct {
	ID   string `uri:"id" binding:"required,uuid"`
	Name string `uri:"name" binding:"required"`
}

func main() {
	r := gin.Default()

	r.GET("/:name/:id", func(c *gin.Context) {
		var person Person
		if err := c.ShouldBindUri(&person); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"code": -1,
				"msg":  err.Error(),
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"code": 0,
			"msg":  "ok",
		})
	})

	r.Run()
}
```



### 4.4.4 错误翻译器

```go
// 1. 定义翻译器 translator.go
package translator

import (
	"strings"

	"github.com/gin-gonic/gin/binding"
	"github.com/go-playground/locales/zh"
	ut "github.com/go-playground/universal-translator"
	"github.com/go-playground/validator/v10"
	zhTrans "github.com/go-playground/validator/v10/translations/zh"
)

var (
	uni      *ut.UniversalTranslator
	validate *validator.Validate
	trans    ut.Translator
)

func InitTrans() {
	// 翻译器
	zh := zh.New()
	uni = ut.New(zh, zh)

	trans, _ = uni.GetTranslator("zh")

	// 获取gin的校验器
	validate = binding.Validator.Engine().(*validator.Validate)

	// 注册翻译器
	zhTrans.RegisterDefaultTranslations(validate, trans)
}

func Translate(err error) string {
	var result []string

	errors := err.(validator.ValidationErrors)

	for _, err := range errors {
		result = append(result, err.Translate(trans))
	}

	return strings.Join(result, "; ")
}


// 2. 初始化
translator.InitTrans()


// 3. 使用实例
type addUserRequest struct {
	Username string `json:"username" binding:"required,min=3,max=20"`
	Password string `json:"password" binding:"required,min=6,max=8"`
	Email    string `json:"email" binding:"omitempty,email"`
}

func AddUserHandler(c *gin.Context) (interface{}, error) {
	var req addUserRequest

	err := c.ShouldBindJSON(&req)
	fmt.Println(err)
	if err != nil {
		return nil, e.ParameterError(translator.Translate(err))
	}

	// 新增用户
	srv := &service.AddUserService{}
	err = srv.AddUser(req.Username, req.Password, req.Email)

	return srv, err
}
```







## 4.5 响应渲染

### 4.5.1 常见格式

```go
c.JSON(http.StatusOK, gin.H{"code": 0, "msg": "ok"})
c.XML(http.StatusOK, gin.H{"code": 0, "msg": "ok"})
c.YAML(http.StatusOK, gin.H{"code": 0, "msg": "ok"})
```



### 4.5.2 ProtoBuf

```go
func main() {
	r := gin.Default()

	r.GET("/protobuf", func(c *gin.Context) {
		reps := []int64{int64(1), int64(2)}

		label := "test"
		data := &protoexample.Test{
			Label: &label,
			Reps:  reps,
		}

		c.ProtoBuf(http.StatusOK, data)
	})

	r.Run()
}
```



### 4.5.3 SecureJSON

SecureJSON可以防止json劫持，如果返回的数据是数组，则会默认在返回值前加上"while(1)"

JSON劫持，其实就是恶意网站，通过`<script>`标签获取你的JSON数据，因为JSON数组默认为是可执行的JS，所以通过这种方式，可以获得你的敏感数据。

```go
func main() {
	r := gin.Default()

	// facebook
	r.SecureJsonPrefix("for(;;);")

	r.GET("/test", func(c *gin.Context) {
		nums := []int{1, 2, 3, 4, 5}

		c.SecureJSON(http.StatusOK, nums) // while(1);[1,2,3,4,5]  默认Google
	})

	r.Run()
}
```



### 4.5.4 JSONP

JSONP可以跨域传输，如果参数中存在回调参数，那么返回的参数将是回调函数的形式

```go
func main() {
	r := gin.Default()

	data := make(map[string]interface{})
	data["bar"] = "foo"

	r.GET("/test", func(c *gin.Context) {
		c.JSONP(http.StatusOK, data)
	})

	// http://localhost:8080/test?callback=sayHello
	// sayHello({"bar":"foo"});

	r.Run()
}
```

```js
<script>
    function sayHello(data) {
        alert(JSON.stringify(data))
    }
</script>

<script type="text/javascript" src="http://localhost:8080/jsonp?callback=sayHello" ></script>
```



### 4.5.5 AsciiJSON

编码中文、标签等特殊字符

```go
func main() {
	r := gin.Default()

	data := map[string]interface{}{
		"lang": "中文",
		"tag":  "<xml>",
	}

	r.GET("/test", func(c *gin.Context) {
		c.AsciiJSON(http.StatusOK, data)
	})

	// {"lang":"\u4e2d\u6587","tag":"\u003cxml\u003e"}

	r.Run()
}
```



### 4.5.6 PureJSON

JSON会将特殊的HTML字符替换为对应的unicode字符, 但PureJSON保留原有格式

```go
func main() {
	r := gin.Default()

	r.GET("/test", func(c *gin.Context) {
		c.PureJSON(http.StatusOK, gin.H{
			"html": "<h1>Hello World</h1>",
		})
	})

	// {"html":"<h1>Hello World</h1>"}

	r.Run()
}
```



### 4.5.7 jsoniter

高性能json工具

```
import jsoniter "github.com/json-iterator/go"

var json = jsoniter.ConfigCompatibleWithStandardLibrary
json.Marshal(&data)
json.Unmarshal(input, &data)
```

Gin 默认使用 `encoding/json`，可以在编译中使用标签将其修改为 [jsoniter](https://github.com/json-iterator/go)

```bash
go build -tags=jsoniter .
```



## 4.6 静态文件

```go
func main() {
	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.String(http.StatusOK, "hello world")
	})

	r.Static("/assets", "./assets")
	r.StaticFS("/disk", http.Dir(`E:\Download`))
	r.StaticFile("favicon.ico", "./assets/favicon.ico")

	r.Run(":8080")
}
```



## 4.7 代理下载文件

```go
func downloadFromUrl(c *gin.Context) {
	url := c.Query("url")
	resp, err := http.Get(url)
	if err != nil || resp.StatusCode != http.StatusOK {
		c.Status(http.StatusServiceUnavailable)
		return
	}

	arr := strings.Split(url, "/")
	filename := arr[len(arr)-1]

	reader := resp.Body
	contentLength := resp.ContentLength
	contentType := resp.Header.Get("Content-Type")

	extraHeaders := map[string]string{
		"Content-Disposition": fmt.Sprintf("attachment; filename=%s", filename),
	}

	c.DataFromReader(http.StatusOK, contentLength, contentType, reader, extraHeaders)
}
```



## 4.8 HTML渲染

```go
func main() {
	r := gin.Default()

	//r.LoadHTMLFiles("templates/index.tmpl", "templates/login.tmpl")
	r.LoadHTMLGlob("templates/*")

	r.GET("/test", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.tmpl", gin.H{
			"title": "Home Page",
		})
	})

	r.Run()
}
```

```html
<html>
    <h1>
        {{ .title }}
    </h1>
</html>
```



## 4.9 重定向

```go
func main() {
	r := gin.Default()

    // 外部重定向
	r.GET("/test1", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "https://google.com")
	})

    // 路由重定向 HandleContext
	r.GET("/test2", func(c *gin.Context) {
		c.Request.URL.Path = "/test3"
		r.HandleContext(c)
	})

	r.GET("/test3", func(c *gin.Context) {
		c.String(http.StatusOK, "hello world!")
	})

	r.Run(":8080")
}
```

### 





```go
func main() {
	r := gin.Default()

	r.GET("/test", func(c *gin.Context) {
		c.Request.URL.Path = "/test2"
		r.HandleContext(c)
	})

	r.GET("/test2", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"msg": "hello world!",
		})
	})

	r.Run()
}
```



## 4.10 支持https

```go
import (
	"log"
	"net/http"

	"golang.org/x/crypto/acme/autocert"
	"github.com/gin-gonic/autotls"
	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	r.GET("/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "pong")
	})

	m := autocert.Manager{
		Prompt:     autocert.AcceptTOS,
		HostPolicy: autocert.HostWhitelist("localhost:8080", "example1.com", "example2.com"),
		Cache:      autocert.DirCache("/var/www/.cache"),
	}

	log.Fatal(autotls.RunWithManager(r, &m))
}
```



## 4.11 使用cookie

```go
func main() {
	r := gin.Default()

	r.GET("/test", func(c *gin.Context) {
		cookie, err := c.Cookie("gin_cookie")
		if err != nil {
			cookie = "NO_SET"
			c.SetCookie("gin_cookie", "test", 3600, "/", "localhost", false, true)
		}

		c.String(http.StatusOK, "cookie=%s", cookie)
	})

	r.Run()
}
```



## 4.13 服务配置

```go
type Server struct {
	Addr           string
	Handler        http.Handler
	TLSConfig      *tls.Config
	ReadTimeout    time.Duration
	ReadHeaderTime time.Duration
	WriteTimeout   time.Duration
	IdleTimeout    time.Duration
	MaxHeaderBytes int
	ConnState      func(net.Conn, http.ConnState)
	ErrorLog       *log.Logger
}
```



```go
func main() {
    router := gin.Default()

    s := &http.Server{
        Addr:           ":8080",
        Handler:        router,
        ReadTimeout:    10 * time.Second,
        WriteTimeout:   10 * time.Second,
        MaxHeaderBytes: 1 << 20,
    }
    s.ListenAndServe()
}
```



## 4.14 使用 goroutine

在中间件或处理程序中启动 Goroutine 时，需要使用只读副本 `c.Copy()`

```go
func main() {
	r := gin.Default()
	r.GET("/sync", func(c *gin.Context) {
		start := time.Now()
		time.Sleep(5 * time.Second)
		log.Println(c.Request.URL)
		latency := time.Now().Sub(start)
		c.String(http.StatusOK, latency.String())
	})

	r.GET("/async", func(c *gin.Context) {
		start := time.Now()

		// 协程中使用，必须先复制
		cc := c.Copy()
		go func() {
			time.Sleep(5 * time.Second)
			log.Println(cc.Request.URL)
		}()

		latency := time.Now().Sub(start)
		c.String(http.StatusOK, latency.String())
	})
}
```



# 5. 运行多个服务

```go
import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/sync/errgroup"
)

var (
	g errgroup.Group
)

func router01() http.Handler {
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"msg": "welcome to server 01"})
	})
	return r
}

func router02() http.Handler {
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"msg": "welcome to server 02"})
	})
	return r
}

func main() {
	server01 := &http.Server{
		Addr:         ":8080",
		Handler:      router01(),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	server02 := &http.Server{
		Addr:         ":8081",
		Handler:      router02(),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	g.Go(func() error {
		return server01.ListenAndServe()
	})

	g.Go(func() error {
		return server02.ListenAndServe()
	})

	if err := g.Wait(); err != nil {
		log.Fatal(err)
	}
}
```



# 6. 集成JWT

```bash
go get github.com/dgrijalva/jwt-go
```

涉及方法：

- `NewWithClaims(method SigningMethod, claims Claims)`, method对应着`SigningMethodHMAC struct{}`，其包含`SigningMethodHS256`, `SigningMethodHS384`, `SigningMethodHS512`三种crypt.Hash
- `func (t *Token) SignedString(key interface{})` 内部生成签名字符串，再用于获取完整、已签名的token
- `func (p *Parser) ParseWithClaims`解析鉴权声明，方法内部主要是具体的解码和校验过程，最终返回*Token
- `func (m MapClaims) Valid()` 验证基于时间的声明exp, iat, nbf


```go
import (
	"gin-blog/pkg/setting"
	"time"

	jwt "github.com/dgrijalva/jwt-go"
)

var jwtSecret = []byte(setting.JwtSecret)

type Claims struct {
	Username string `json:"username"`
	Password string `json:"password"`
	jwt.StandardClaims
}

func GenerateToken(username, password string) (string, error) {
	nowTime := time.Now()
	expireTime := nowTime.Add(3 * time.Hour)

	claims := Claims{
		username,
		password,
		jwt.StandardClaims{
			ExpiresAt: expireTime.Unix(),
			Issuer:    "gin-blog",
		},
	}

	tokenClaims := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	token, err := tokenClaims.SignedString(jwtSecret)

	return token, err
}

func ParseToken(token string) (*Claims, error) {
	tokenClaims, err := jwt.ParseWithClaims(token, &Claims{},
		func(token *jwt.Token) (interface{}, error) {
			return jwtSecret, nil
		})

	if tokenClaims != nil {
		if claims, ok := tokenClaims.Claims.(*Claims); ok && tokenClaims.Valid {
			return claims, nil
		}
	}

	return nil, err
}
```



# 7. 重启服务器

要求：

- 不关闭现有连接 （正在运行中的程序）
- 新的进程启动并替代旧进程
- 新的进程结构新的连接
- 连接要随时响应用户的请求，当用户仍在请求旧进程时，要保持连接，新用户应请求新进程，不可出现拒绝请求的情况



## 7.1 endless

endless: Zero downtime restarts for golfing HTTP and HTTPS servers

每次更新发布、修改配置文件等，只要给该进行发送SIGTERM信号(kill )，而不需要强制结束应用

监听信号：

- `syscall.SIGHUP`: 触发fork子进程和重新启动
- `syscall.SIGUSR1/syscall.SIGTSTP`: 被监听，但不触发任何动作
- `syscall.SIGUSR2`: 触发hammerTime
- `syscall.SIGINT/syscall.SIGTERM`: 触发服务器关闭（会完成正在运行的请求）


```go
import (
	"fmt"
	"gin-blog/pkg/setting"
	"gin-blog/routers"
	"log"
	"syscall"

	"github.com/fvbock/endless"
)

func main() {
	//router := routers.InitRouter()
	//
	//server := &http.Server{
	//	Addr:           fmt.Sprintf(":%d", setting.HTTPPort),
	//	Handler:        router,
	//	ReadTimeout:    setting.ReadTimeout,
	//	WriteTimeout:   setting.WriteTimeout,
	//	MaxHeaderBytes: 1 << 20,
	//}

	endless.DefaultReadTimeOut = setting.ReadTimeout
	endless.DefaultWriteTimeOut = setting.WriteTimeout
	endless.DefaultMaxHeaderBytes = 1 << 20
	endPoint := fmt.Sprintf(":%d", setting.HTTPPort)

	server := endless.NewServer(endPoint, routers.InitRouter())
	server.BeforeBegin = func(add string) {
		log.Printf("Actual pid is %d", syscall.Getpid())
	}

	err := server.ListenAndServe()
	if err != nil {
		log.Printf("Server error: %v", err)
	}
}
```



## 7.2 Shutdown

使用 http.Server 内置的 `Shutdown()`方法优雅地关闭服务，它不会中断任何活动的连接，直到所有连接处理完毕

```go
func main() {
	router := initRouter()

	server := &http.Server{
		Addr:           fmt.Sprintf(":%d", setting.HTTPPort),
		Handler:        router,
		ReadTimeout:    setting.ReadTimeout,
		WriteTimeout:   setting.WriteTimeout,
		MaxHeaderBytes: 1 << 20,
	}

	go func() {
		if err := server.ListenAndServe(); err != nil {
			log.Printf("Listen: %v\n", err)
		}
	}()

	quit := make(chan os.Signal)
	signal.Notify(quit, os.Interrupt)
	<-quit

	log.Printf("Shutdown Server ...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatal("Server Shutdown:", err)
	}

	log.Println("Server exiting")
}
```



# 8. 文件分段上传

## 8.1 处理逻辑

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/upload-bug-file.png) 



## 8.2 后端逻辑

```go
const (
	FileInComplete = iota
	FileComplete
)

func CheckChunkHandler(c *gin.Context) {
	fileHash := c.Query("hash")
	targetFileName := c.Query("fileName")
	uploadPath := filepath.Join(FileStoragePath, fileHash)
	chunkList := make([]string, 0)

	// 文件完整性： 0-不完整 1-完整
	state := FileInComplete

	// 路径是否存在
	isExistPath := DoesDirExist(uploadPath)
	if isExistPath {
		// 获取上传目录下的文件名
		files, err := ioutil.ReadDir(uploadPath)
		if err != nil {
			log.Println(err)
			c.JSON(http.StatusBadRequest, gin.H{
				"message": err.Error(),
			})
			return
		}

		for _, f := range files {
			fileName := f.Name()

			// 已生成结果文件，不需要再次上传文件块
			if fileName == targetFileName {
				state = FileComplete
			} else {
				chunkList = append(chunkList, fileName)
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "ok",
		"state":     state,
		"chunkList": chunkList,
	})
}

func UploadChunkHandler(c *gin.Context) {
	fileHash := c.PostForm("hash")
	uploadPath := filepath.Join(FileStoragePath, fileHash)

	file, err := c.FormFile("file")
	if err != nil {
		log.Println(err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": err.Error(),
		})
		return
	}

	// 路径是否存在
	isExistPath := DoesDirExist(uploadPath)

	// 路径不存在，先创建
	if !isExistPath {
		err = os.Mkdir(uploadPath, os.ModePerm)
		if err != nil {
			log.Println(err)
			c.JSON(http.StatusBadRequest, gin.H{
				"message": err.Error(),
			})
			return
		}
	}

	// 保存文件
	err = c.SaveUploadedFile(file, filepath.Join(uploadPath, file.Filename))
	if err != nil {
		log.Println(err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": err.Error(),
		})
		return
	}

	chunkList := make([]string, 0)

	// 获取上传目录下的文件名
	files, err := ioutil.ReadDir(uploadPath)
	if err != nil {
		log.Println(err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": err.Error(),
		})
		return
	}

	for _, f := range files {
		fileName := f.Name()
		chunkList = append(chunkList, fileName)
	}

	c.JSON(http.StatusOK, gin.H{
		"chunkList": chunkList,
	})
}

func MergeChunkHandler(c *gin.Context) {
	fileHash := c.Query("hash")
	fileName := c.Query("fileName")

	uploadPath := filepath.Join(FileStoragePath, fileHash)

	// 路径是否存在
	isExistPath := DoesDirExist(uploadPath)
	if !isExistPath {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "storage directory not found",
		})
		return
	}

	// 结果文件
	filePath := filepath.Join(uploadPath, fileName)

	// 结果文件不存在则合并
	isExistFile := DoesFileExist(filePath)
	if !isExistFile {
		// 读取上传目录下的文件
		files, err := ioutil.ReadDir(uploadPath)
		if err != nil {
			log.Println(err)
			c.JSON(http.StatusBadRequest, gin.H{
				"message": err.Error(),
			})
			return
		}

		// 创建完整文件
		completeFile, err := os.Create(filePath)
		if err != nil {
			log.Println(err)
			c.JSON(http.StatusBadRequest, gin.H{
				"message": err.Error(),
			})
			return
		}
		defer completeFile.Close()

		// 最大文件名
		var maxFileName int
		for _, f := range files {
			n, err := strconv.Atoi(f.Name())
			if err != nil {
				continue
			}
			if n > maxFileName {
				maxFileName = n
			}
		}

		// 合并文件(从小到大)
		for i := 0; i <= maxFileName; i++ {
			buf, err := ioutil.ReadFile(filepath.Join(uploadPath, strconv.Itoa(i)))
			if err != nil {
				log.Println(err)
				c.JSON(http.StatusBadRequest, gin.H{
					"message": err.Error(),
				})
				return
			}

			// 写入文件
			completeFile.Write(buf)
		}
	}

	c.JSON(200, gin.H{
		"fileUrl": fmt.Sprintf("%s://%s/download/%s/%s", "http", c.Request.Host, fileHash, fileName),
	})
}
```



## 8.3 前端逻辑

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="/static/css/bootstrap.min.css" />
    <link rel="stylesheet" href="/static/css/bootstrap-theme.min.css" />
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }


        .wrap {
            width: 100px;
            height: 40px;
            background-color: red;
            text-align: center
        }

        .wrap p {

            width: 100%;
            height: 100%;
            line-height: 2;
            text-align: center;
        }

        #file {
            position: absolute;
            left: 0;
            top: 0;
            width: 100px;
            height: 40px;
            display: block;
            opacity: 0;
        }

        .progress {
            position: relative;
        }

        .progress-bar {
            transition: width .3s ease
        }

        .progress .value {
            position: absolute;
            color: #FF9800;
            left: 50%;
        }

        .container {
            width: 500px;
        }

        .row {
            border-bottom: 1px solid gray;
            padding: 10px;
        }

        .hidden {
            display: none;
        }
        .mrb20 {
            margin: 20px 0;
        }
    </style>
    <title>上传文件</title>
</head>

<body>
<div class="container">
    <div class="row">
        <div class="col-md-4 mrb20">点击按钮开始上传文件</div>
        <div class="col-md-8">
            <div class="wrap btn btn-default">
                <input type="file" id="file" />
                <p>上传文件</p>
            </div>
        </div>
    </div>
    <div class="row" id="process1" style="display: none">
        <div class="col-md-4">校验文件进度</div>
        <div class="col-md-8">
            <div class="progress">
                <div id="checkProcessStyle" class="progress-bar" style="width:0%"></div>
                <p id="checkProcessValue" class="value">0%</p>
            </div>
        </div>
    </div>
    <div class="row" id="process2" style="display: none">
        <div class="col-md-4">上传文件进度</div>
        <div class="col-md-8">
            <div class="progress">
                <div id="uploadProcessStyle" class="progress-bar" style="width:0%"></div>
                <p id="uploadProcessValue" class="value">0%</p>
            </div>
        </div>
    </div>
</div>
<script src="/static/js/jquery-1.10.2.min.js"></script>
<script src="/static/js/bootstrap.min.js"></script>
<script src="/static/js/spark-md5.min.js"></script>
<script>
    let baseUrl = 'http://127.0.0.1:3000'
    let chunkSize = 10 * 1024 * 1024  // 10M
    let fileSize = 0
    let file = null
    let hasUploaded = 0
    let chunks = 0

    $("#file").on('change', function () {
        file = this.files[0]
        fileSize = file.size;
        responseChange(file)
    })

    async function responseChange(file) {
        // 文件校验进度
        $("#process1").slideDown(200)

        // 文件hash值
        let hash = await md5File(file)

        // 校验文件的MD5
        let result = await checkFileChunk(hash, file.name)

        // 如果文件已存在, 就秒传
        if (result.state === 1) {
            alert('文件已秒传')
            return
        }

        // 上传进度
        $("#process2").slideDown(200)

        // 上传文件块
        await uploadFileChunk(hash, result.chunkList)

        // 合并文件
        mergeFileChunk(hash)
    }

    // 浏览器读取文件，获取hash校验值
    function md5File(file) {
        return new Promise((resolve, reject) => {
            let blobSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice,
                chunkSize = file.size / 100,
                chunks = 100,
                currentChunk = 0,
                spark = new SparkMD5.ArrayBuffer(),
                fileReader = new FileReader();

            fileReader.onload = function (e) {
                // console.log('read chunk nr', currentChunk + 1, 'of', chunks);
                spark.append(e.target.result); // Append array buffer
                currentChunk++;

                if (currentChunk < chunks) {
                    loadNext();
                } else {
                    console.log('finished loading');
                    let result = spark.end()
                    resolve(result)
                }
            };

            fileReader.onerror = function () {
                console.warn('oops, something went wrong.');
            };

            function loadNext() {
                let start = currentChunk * chunkSize,
                    end = ((start + chunkSize) >= file.size) ? file.size : start + chunkSize;

                fileReader.readAsArrayBuffer(blobSlice.call(file, start, end));
                $("#checkProcessStyle").css({
                    width: (currentChunk + 1) + '%'
                })
                $("#checkProcessValue").html((currentChunk + 1) + '%')
            }

            loadNext();
        })
    }

    // 校验文件是否已上传
    function checkFileChunk(hash, fileName) {
        return new Promise((resolve, reject) => {
            let url = baseUrl + '/chunk/check?hash=' + hash + '&fileName=' + fileName
            $.getJSON(url, function (data) {
                console.log(data)
                resolve(data)
            })
        })
    }

    // 异步上传文件
    async function uploadFileChunk(hash, chunkList) {
        chunks = Math.ceil(fileSize / chunkSize)
        hasUploaded = chunkList.length
        for (let i = 0; i < chunks; i++) {
            // 如果已经存在, 则不用再上传当前块
            let exist = chunkList.indexOf(i + "") > -1
            if (!exist) {
                let index = await upload(i, hash)
                console.log(index)

                hasUploaded++
                let radio = Math.floor((hasUploaded / chunks) * 100)
                $("#uploadProcessStyle").css({
                    width: radio + '%'
                })
                $("#uploadProcessValue").html(radio + '%')
            }
        }
    }

    function upload(i, hash) {
        return new Promise((resolve, reject) => {
            let start = i * chunkSize
            let end = (i + 1) * chunkSize >= file.size ? file.size : (i + 1) * chunkSize

            // 文件块
            const blob = new File([file.slice(start, end)], `${i}`)

            let formData = new FormData()
            formData.append("file", blob)
            formData.append("hash", hash)

            $.ajax({
                url: baseUrl + "/chunk/upload",
                type: "POST",
                data: formData,
                async: true,
                processData: false, // 不要对form进行处理
                contentType: false, // 自动生成正确的Content-Type
                success: function (data) {
                    console.log(data)
                    resolve(data.message)
                }
            })
        })

    }

    // 合并文件
    function mergeFileChunk(fileMd5Value) {
        let url = baseUrl + '/chunk/merge?hash=' + fileMd5Value + "&fileName=" + file.name
        $.getJSON(url, function (data) {
            console.log(data)
            alert('上传成功')
        })
    }
</script>
</body>

</html>
```



# 9. Swagger API

```bash
go get -u github.com/swaggo/swag/cmd/swag
go get -u github.com/swaggo/gin-swagger
go get -u github.com/swaggo/gin-swagger/swaggerFiles
```



## 9.1 API 接口注释

```go
// LoginHandler godoc
// @Summary 登录系统
// @Tags 用户相关接口
// @Accept  json
// @Produce  json
// @Param object body loginRequest true "请求参数"
// @Success 200 {object} router.Response
// @Failure 400 {object} e.ApiError
// @Router /api/v1/login [post]
func LoginHandler(c *gin.Context) (interface{}, error) {
	var req loginRequest

	err := c.ShouldBindJSON(&req)
	if err != nil {
		return nil, e.ParameterError(translator.Translate(err))
	}

	// 登录
	srv := &service.LoginService{}
	err = srv.Login(req.Username, req.Password)
	if err != nil {
		return nil, e.ParameterError(translator.Translate(err))
	}

	return srv, nil
}
```



## 9.2 生成配置

```bash
swag init
```



## 9.3 引入配置

```go
// main.go
func init() {
    // swagger 相关信息
	docs.SwaggerInfo.Title = "XXX 项目接口文档"
	docs.SwaggerInfo.Description = "just a test"
	docs.SwaggerInfo.Version = "1.0"
	docs.SwaggerInfo.Host = addr
	docs.SwaggerInfo.BasePath = "/"
	docs.SwaggerInfo.Schemes = []string{"http", "https"}
}
```



## 9.4 禁用Swagger

`gin-swagger`还提供了`DisablingWrapHandler`函数，方便我们通过设置某些环境变量来。例如：

```
r.GET("/swagger/*any", gs.DisablingWrapHandler(swaggerFiles.Handler, "NAME_OF_ENV_VARIABLE"))
```

此时如果将环境变量`NAME_OF_ENV_VARIABLE`设置为任意值，则`/swagger/*any`将返回404响应，就像未指定路由时一样。



# 10. 接口测试

```bash
import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
    "github.com/gin-gonic/gin"
)

func setRouter() *gin.Engine {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "pong")
	})

	return r
}

func TestPingRoute(t *testing.T) {
	router := setRouter()

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/ping", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "pong", w.Body.String())
}
```



# 11. 源码解析

```go
// 获取一个gin框架实例
gin.Default()

// 具体的Default方法
func Default() *Engine {
    // 调试模式日志输出 
	debugPrintWARNINGDefault()
	
    // 创建一个gin框架实例
    engine := New()
	
	// 注册中间件的方式一致
	engine.Use(Logger(), Recovery())
	
    return engine
}

// 创建一个gin框架实例 具体方法
func New() *Engine {
    // 调试模式日志输出 
	debugPrintWARNINGNew()
	
    // 初始化一个Engine实例
    engine := &Engine{
        // 给框架实例绑定上一个路由组
        RouterGroup: RouterGroup{
            Handlers: nil,   // engine.Use 注册的中间方法到这里
            basePath: "/",  
            root:     true,   // 是否是路由根节点
        },
        FuncMap:                template.FuncMap{},
        RedirectTrailingSlash:  true,
        RedirectFixedPath:      false,
        HandleMethodNotAllowed: false,
        ForwardedByClientIP:    true,
        AppEngine:              defaultAppEngine,
        UseRawPath:             false,
        UnescapePathValues:     true,
        MaxMultipartMemory:     defaultMultipartMemory,
        trees:                  make(methodTrees, 0, 9),   // 路由树
        delims:                 render.Delims{Left: "{{", Right: "}}"},
        secureJsonPrefix:       "while(1);",
	}
	
    // RouterGroup绑定engine自身的实例
	engine.RouterGroup.engine = engine
	
    // 绑定从实例池获取上下文的闭包方法
    engine.pool.New = func() interface{} {
        // 获取一个Context实例
        return engine.allocateContext()
    }
    // 返回框架实例
    return engine
}

// 注册日志&goroutin panic捕获中间件
engine.Use(Logger(), Recovery())

// 具体的注册中间件的方法
func (engine *Engine) Use(middleware ...HandlerFunc) IRoutes {
    engine.RouterGroup.Use(middleware...)
    engine.rebuild404Handlers()
    engine.rebuild405Handlers()
    return engine
}

///////////////////////////////////////////

// 注册GET请求路由
func (group *RouterGroup) GET(relativePath string, handlers ...HandlerFunc) IRoutes {
    // 往路由组内 注册GET请求路由
    return group.handle("GET", relativePath, handlers)
}

func (group *RouterGroup) handle(httpMethod, relativePath string, handlers HandlersChain) IRoutes {
	absolutePath := group.calculateAbsolutePath(relativePath)
	
    // 把中间件的handle和该路由的handle合并
	handlers = group.combineHandlers(handlers)
	
    // 注册一个GET集合的路由
    group.engine.addRoute(httpMethod, absolutePath, handlers)
    return group.returnObj()
}

func (engine *Engine) addRoute(method, path string, handlers HandlersChain) {
    assert1(path[0] == '/', "path must begin with '/'")
    assert1(method != "", "HTTP method can not be empty")
    assert1(len(handlers) > 0, "there must be at least one handler")

	debugPrintRoute(method, path, handlers)
	
    // 检查有没有对应method集合的路由
    root := engine.trees.get(method)
    if root == nil {
        // 没有 创建一个新的路由节点
		root = new(node)
		
        // 添加该method的路由tree到当前的路由到路由树里
        engine.trees = append(engine.trees, methodTree{method: method, root: root})
	}
	
    // 添加路由
    root.addRoute(path, handlers)
}

// 路由树节点
type node struct {
    path      string
    indices   string
    children  []*node
    handlers  HandlersChain   // 所有的handle 构成一个链
    priority  uint32
    nType     nodeType
    maxParams uint8
    wildChild bool
}

// 启动http server
func (engine *Engine) Run(addr ...string) (err error) {
    defer func() { debugPrintError(err) }()

    address := resolveAddress(addr)
	debugPrint("Listening and serving HTTP on %s\n", address)
	
    // 执行http包的ListenAndServe方法 启动路由
    err = http.ListenAndServe(address, engine)
    return
}

// engine自身就实现了Handler接口
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}

// 监听IP+端口
ln, err := net.Listen("tcp", addr)

// 接着就是Serve
srv.Serve(tcpKeepAliveListener{ln.(*net.TCPListener)})

// Accept请求
rw, e := l.Accept()

// 使用goroutine去处理一个请求，最终就执行的是engine的ServeHTTP方法
go c.serve(ctx)

// engine实现http.Handler接口ServeHTTP的具体方法
func (engine *Engine) ServeHTTP(w http.ResponseWriter, req *http.Request) {
    // 获取一个上下文实例，从实例池获取 性能高
	c := engine.pool.Get().(*Context)
	
    // 重置获取到的上下文实例的http.ResponseWriter
	c.writermem.reset(w)
	
    // 重置获取到的上下文实例*http.Request
	c.Request = req
	
    // 重置获取到的上下文实例的其他属性
    c.reset()

    // 实际处理请求的地方，传递当前的上下文
    engine.handleHTTPRequest(c)

    //归还上下文实例
    engine.pool.Put(c)
}

// 具体执行路由的方法
engine.handleHTTPRequest(c)

t := engine.trees
for i, tl := 0, len(t); i < tl; i++ {
    // 遍历路由树，查找当前请求method
    if t[i].method != httpMethod {
        continue
    }
    // 找到节点
	root := t[i].root
	
    // 寻找当前请求的路由
    handlers, params, tsr := root.getValue(path, c.Params, unescape)
    if handlers != nil {
        // 把找到的handles赋值给上下文
        c.handlers = handlers
        // 把找到的入参赋值给上下文
        c.Params = params
        // 执行handle
        c.Next()
        // 处理响应内容
        c.writermem.WriteHeaderNow()
        return
    }
    ...
}

// 方法树结构体
type methodTree struct {
    // HTTP Method
    method string
    // 当前HTTP Method的路由节点
    root   *node
}

// 方法树集合
type methodTrees []methodTree

// 执行handle
func (c *Context) Next() {
    // 上下文处理之后c.index被执为-1
    c.index++
    for s := int8(len(c.handlers)); c.index < s; c.index++ {
        // 遍历执行所有handle(其实就是中间件+路由handle)
        c.handlers[c.index](c)
    }
}

// Context的重置方法
func (c *Context) reset() {
    c.Writer = &c.writermem
    c.Params = c.Params[0:0]
    c.handlers = nil
    // 很关键 注意这里是-1哦
    c.index = -1
    c.Keys = nil
    c.Errors = c.Errors[0:0]
    c.Accepted = nil
}
```



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/gin-work-flow.png) 
