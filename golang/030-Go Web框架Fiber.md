
# 1. 入门

```bash
go get github.com/gofiber/fiber/v2
```

编写主函数：

```go
func main() {
	app := fiber.New()

	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("Hello World!")
	})

	app.Listen(":3000")
}
```



# 2. 配置

```go
func main() {
	app := fiber.New(fiber.Config{
		AppName:      "It's a go fiber web frame",
		ServerHeader: "gofiber.io", // Response.Header.Server
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
	})

	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("OK")
	})

	log.Fatalln(app.Listen(":3000"))
}
```



# 3. 路由

## 3.1 参数

```go
func main() {
	app := fiber.New()

	app.Get("/about", func(c *fiber.Ctx) error {
		return c.SendString("about")
	})

	// ?: 允许username不输入
	app.Get("/hello/:username?", func(c *fiber.Ctx) error {
		msg := fmt.Sprintf("hello %s", c.Params("username"))
		return c.SendString(msg)
	})

	// 复杂路由
	app.Get("/fights/:from-:to", func(c *fiber.Ctx) error {
		fmt.Fprintf(c, "%s-%s\n", c.Params("from"), c.Params("to"))
		return nil
	})

	// 路由注册信息
	data, _ := json.MarshalIndent(app.Stack(), "", "  ")
	fmt.Println(string(data))

	log.Fatalln(app.Listen(":3000"))
}
```



## 3.2 Add & All

Fiber 路由支持额外的方法：

- Add：所有 HTTP Method 对应的底层实现

  ```go
  // Fiber 自动添加 Head 方法
  func (app *App) Get(path string, handlers ...Handler) Router {
  	return app.Add(MethodHead, path, handlers...).Add(MethodGet, path, handlers...)
  }
  ```

- All：支持任意的 HTTP Method 请求



## 3.3 Mount & Group

**Mount**: 可以将一个 Fiber 实例挂载到另一个实例

```go
func main() {
	micro := fiber.New()
	micro.Get("/micro", func(c *fiber.Ctx) error {
		return c.SendString("micro")
	})

	app := fiber.New()
	app.Mount("/app", micro)

	log.Fatal(app.Listen(":3000"))
}
```



**Group**: 路由分组

```go
func calc(c *fiber.Ctx) error {
	start := time.Now()
	c.Next()
	elapse := time.Since(start)
	log.Printf("it takes %.2f seconds\n", elapse.Seconds())
	return nil
}

func main() {
	app := fiber.New()

	api := app.Group("/api")

	v1 := api.Group("/v1")
	v1.Get("/about", func(c *fiber.Ctx) error {
		return c.SendString("hello 1")
	})

	v2 := api.Group("/v2", calc)
	v2.Get("/about", func(c *fiber.Ctx) error {
		time.Sleep(3 * time.Second)
		return c.SendString("hello 2")
	})

	log.Fatal(app.Listen(":3000"))
}
```





# 4. 静态资源

```go
app.Static("/images", `/data/images`, fiber.Static{Browse: true})
```



# 5. 使用模板

**pug 模板**: index.pug

```jade
html
    head
        title #{.Title}
    body
        p #{.Message}
```

解析：

```go
func main() {
	// 初始化 pug 模板引擎
	engine := pug.New("./views", ".pug")

	app := fiber.New(fiber.Config{
		Views: engine,
	})

	app.Get("/", func(c *fiber.Ctx) error {
		return c.Render("index", fiber.Map{
			"Title":   "hello",
			"Message": "This is the index pug template",
		})
	})

	app.Listen(":3000")
}
```



# 6. `fiber.Ctx` 方法

## 6.1 `c.BodyParser`

```go
type User struct {
	Name string `json:"name" xml:"name" form:"name"`
	Pass string `json:"pass" xml:"pass" form:"pass"`
}

func main() {
	app := fiber.New()

	app.Post("/login", func(c *fiber.Ctx) error {
		user := new(User)

		err := c.BodyParser(user)
		if err != nil {
			return err
		}

		log.Printf("name %s, pass: %s\n", user.Name, user.Pass)
		return c.SendString("OK")
	})

	log.Fatal(app.Listen(":3000"))
}
```

测试：

```bash
curl -X POST -H "Content-Type: application/json" --data "{\"name\":\"john\",\"pass\":\"doe\"}" localhost:3000/login

curl -X POST -H "Content-Type: application/xml" --data "<login><name>john</name><pass>doe</pass></login>" localhost:3000/login

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "name=john&pass=doe" localhost:3000/login

curl -X POST -F name=john -F pass=doe http://localhost:3000/login

curl -X POST "http://localhost:3000/login?name=john&pass=doe"
```



## 6.2 `c.Query()`

```go
func main() {
	app := fiber.New()

	app.Get("/users", func(c *fiber.Ctx) error {
		pageIndex := c.Query("page_index")
		pageSize := c.Query("page_size")

		body := fmt.Sprintf("page index: %s\npage size: %s", pageIndex, pageSize)
		return c.SendString(body)
	})

	log.Fatal(app.Listen(":3000"))
}
```



# 7. 中间件

## 7.1 自定义

```go
	app.Use(func(c *fiber.Ctx) error {
		start := time.Now()
		c.Next()

		elapse := time.Since(start)
		log.Printf("it takes %.2f seconds\n", elapse.Seconds())

		return nil
	})
```



## 7.2 内置中间件

https://docs.gofiber.io/api/middleware

```go
func main() {
	app := fiber.New()

	// 使用内置中间件
	app.Use(recover.New())

	app.Get("/", func(c *fiber.Ctx) error {
		panic("I'm an error")
	})

	log.Fatal(app.Listen(":3000"))
}
```



### 7.2.1 签名

```go
func New(config ...Config) fiber.Handler
```

### 7.2.2 配置

```go
type Config struct {
	// Next defines a function to skip this middleware when returned true.
	//
	// Optional. Default: nil
	Next func(c *fiber.Ctx) bool

	// EnableStackTrace enables handling stack trace
	//
	// Optional. Default: false
	EnableStackTrace bool

	// StackTraceHandler defines a function to handle stack trace
	//
	// Optional. Default: defaultStackTraceHandler
	StackTraceHandler func(e interface{})
}

var ConfigDefault = Config{
	Next:              nil,
	EnableStackTrace:  false,
	StackTraceHandler: defaultStackTraceHandler,
}
```



## 7.3 自建中间件

```go
// 响应headers中设置如下参数
func Security(c *fiber.Ctx) error {
	c.Set("X-XSS-Protection", "1; mode=block")
	c.Set("X-Content-Type-Options", "nosniff")
	c.Set("X-Download-Options", "noopen")
	c.Set("Strict-Transport-Security", "max-age=5184000")
	c.Set("X-Frame-Options", "SAMEORIGIN")
	c.Set("X-DNS-Prefetch-Control", "off")

	return c.Next()
}

func main() {
	app := fiber.New()

	// 使用内置中间件
	app.Use(Security)

	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(map[string]string{"msg": "ok"})
	})

	log.Fatal(app.Listen(":3000"))
}
```



# 8. 单元测试

Fiber 提供专门的测试方法：

```go
// Test is used for internal debugging by passing a *http.Request.
// Timeout is optional and defaults to 1s, -1 will disable it completely.
func (app *App) Test(req *http.Request, msTimeout ...int) (resp *http.Response, err error)
```

待测试程序：

```go
func setupRouters(app *fiber.App) {
	app.Get("/hello", func(c *fiber.Ctx) error {
		return c.SendString("Hello World!")
	})
}

func main() {
	app := fiber.New()

	setupRouters(app)

	log.Fatal(app.Listen(":3000"))
}
```

测试代码：

```go
func TestHelloRoute(t *testing.T) {
	app := fiber.New()
	setupRouters(app)

	cases := []struct {
		description  string
		route        string
		expectedCode int
	}{
		{
			description:  "get HTTP status 200",
			route:        "/hello",
			expectedCode: 200,
		},
		{
			description:  "get HTTP status 404",
			route:        "/notfound",
			expectedCode: 404,
		},
	}

	for _, c := range cases {
		req := httptest.NewRequest("GET", c.route, nil)
		resp, _ := app.Test(req, 1)
		assert.Equalf(t, c.expectedCode, resp.StatusCode, c.description)
	}
}
```



