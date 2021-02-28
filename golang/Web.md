# 1. Web 服务器平滑升级

升级过程中：

1. 正在处理的请求怎么办?
   - 等待处理完成后再退出
   - Golang 1.8+ 支持
   - 即优雅的关闭
   - 另外一直方式，可使用sync.WaitGroup
2. 新进来的请求怎么办?
   - Fork一个子进程，继承父进程的监听socket
   - 子进程启动成功后，接收新的连接
   - 父进程停止接收新的连接，等已有的请求处理完毕，退出
   - 优雅的重启成功

子进程如何继承父进程的文件句柄？

- 通过`os.Cmd`对象中的ExtraFiles参数进程传递
- 文件句柄继承实例分析

web server 优雅重启？

- **使用go1.8+的Shutdown方法进行优雅关闭**
- **使用socket继承实现，子进程接管父进程监听的socket**

信号处理：

- 通过kill命令给正常运行的程序发送信号
- 不处理的话，程序会panic处理





# 11. Cookie & Session

## 11.1 Cookie

Cookie机制：

- 浏览器发送请求的时候，自动带上cookie
- 服务器可设置cookie
- 只针对单个域名，不能跨域

Cookie与登录鉴权：

- 用户登录成功，设置一个cookie：username=jack
- 用户请求时，浏览器自动把cookie: username=jack
- 服务器收到请求后，解析cookie中的username，判断用户是否已登录
- 如果用户登录，鉴权成功；没有登录则重定向到注册页

Cookie的缺陷：

- 容易被伪造
- 猜到的用户名，只要用户名带到请求，就被攻破

改进方案：

- 将username生成一个唯一的 uuid
- 用户请求时，将这个uuid发到服务器
- 服务端通过查询这个uuid，反查是哪个用户

## 11.2 Session

Session机制：

- 在服务端生成的id以及保存id对应用户信息的机制，叫做session机制
- Session和Cookie共同构建了账号鉴权体系
- Cookie保存在客户端，session保存在服务端

- 服务端登录成功后，就分配一个无法伪造的sessionid，存储在用户的机器上，以后每次请求的时候，都带上这个sessionid，就可以达到鉴权的目的

## 11.3 Golang中的Cookie

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

sessionid

// 读取cookie
cookie := http.Request.Cookie(key string)
cookies := http.Request.Cookies()


```



