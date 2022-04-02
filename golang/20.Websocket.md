# 1. 服务端

```go
import (
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"log"
	"net/http"
)

func main() {
	r := gin.Default()
	r.LoadHTMLFiles("index.html")

	r.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.html", nil)
	})

	r.GET("/ws", func(c *gin.Context) {
		wsHandler(c.Writer, c.Request)
	})

	log.Fatal(r.Run(":8080"))
}

var wsUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,

	// Resolve cross-domain problems
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Fatal(err)
	}

	for {
		t, msg, err := conn.ReadMessage()
		if err != nil {
			log.Println(err)
			break
		}
		log.Printf("type: %v, message: %s", t, msg)

		reply := RandStringBytes(10)
		conn.WriteMessage(t, reply)
	}
}
```



# 2. 客户端

```html
<body>
    <h3>Websocket Go</h3>
    <pre id="output"></pre>

<script>
    const url = 'ws://127.0.0.1:8080/ws'
    const ws = new WebSocket(url)

    // 连接建立
    ws.onopen = function (event) {
        console.log('建立连接，状态：' + ws.readyState)

        // 定时向服务器发送请求
        setInterval(
            function () {
                if (ws.readyState === 1) {
                    ws.send("ping")
                }
            },
            3000
        )
    }

    // 服务器返回数据
    ws.onmessage = function (event) {
        let data = event.data
        console.log('收到数据：' + data + ', 状态：' + ws.readyState)

        // 更新页面
        $('#output').prepend("[" + (new Date()).Format("yyyy-MM-dd hh:mm:ss") + "] " + data + "\n")
    }

    // 发生错误
    ws.onerror = function (event) {
        console.log('发生错误，状态：' + ws.readyState)
    }

    // 连接关闭
    ws.onclose = function (ev) {
        console.log('连接关闭，状态：' + ws.readyState)
    }
</script>
</body>
```

