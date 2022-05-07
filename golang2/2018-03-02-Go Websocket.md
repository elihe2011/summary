---
layout: post
title:  Go Websocket
date:   2018-03-02 14:49:58
comments: true
photos: 
tags: 
  - websocket
categories: Golang
---

# 1. 安装支撑库

```sh
go get -u github.com/gorilla/websocket
```

<!-- more -->

# 2. 图灵机器人服务

```go
const (
	USERID = "123456"
	APIKEY = "11337ff965a546b1ae22576f160f1a08"
	URL    = "http://openapi.tuling123.com/openapi/api/v2"
)

type Request struct {
	ReqType    int                    `json:"reqType"`
	Perception map[string]interface{} `json:"perception"`
	UserInfo   map[string]string      `json:"userInfo"`
}

type Result struct {
	ResultType string                 `json:"resultType"`
	Values     map[string]interface{} `json:"values"`
	GroupType  int                    `json:"groupType"`
}

type Response struct {
	Intent  map[string]interface{} `json:"intent"`
	Results []Result
}

func NewRobot() *Request {
	userInfo := map[string]string{
		"apiKey": APIKEY,
		"userId": USERID,
	}

	return &Request{
		ReqType:    0,
		Perception: nil,
		UserInfo:   userInfo,
	}
}

func (r *Request) Chat(msg string) ([]interface{}, error) {
	inputText := map[string]string{
		"text": msg,
	}

	r.Perception = map[string]interface{}{
		"inputText": inputText,
	}

	jsonData, err := json.Marshal(r)
	if err != nil {
		return nil, err
	}

	return r.Post(jsonData)
}

func (r *Request) Post(data []byte) ([]interface{}, error) {
	body := bytes.NewBuffer(data)
	req, err := http.NewRequest("POST", URL, body)
	if err != nil {
		return nil, err
	}

	req.Header.Add("Accept", "application/json")
	req.Header.Add("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var respData Response
	err = json.Unmarshal(respBody, &respData)
	if err != nil {
		return nil, err
	}

	var results []interface{}
	for _, v := range respData.Results {
		for _, val := range v.Values {
			results = append(results, val)
		}
	}

	return results, nil
}
```

# 3. 服务端

```go
var addr = flag.String("addr", "", "http service address")
var model = flag.String("model", "", "--echo or --robot")

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func echo(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Fatalf("http upgrade error: %v", err)
	}
	defer conn.Close()

	defer func() {
		log.Printf("%s disconnected\n", conn.RemoteAddr())
	}()

	log.Printf("%s connected\n", conn.RemoteAddr())

	var robot = NewRobot()
	for {
		msgType, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("Read message error: %v\n", err)
			continue
		}

		log.Printf("Receive message: %s\n", message)

		if *model == "robot" {
			result, err := robot.Chat(string(message))
			if err != nil {
				log.Printf("robot.Chat error: %v\n", err)
				continue
			}

			for _, v := range result {
				if s, ok := v.(string); ok {
					err = conn.WriteMessage(msgType, []byte(s))
					if err != nil {
						log.Printf("conn.WriteMessage error: %v\n", err)
						continue
					}
				}
			}
		} else {
			err = conn.WriteMessage(msgType, message)
			if err != nil {
				log.Printf("conn.WriteMessage error: %v\n", err)
				continue
			}
		}
	}
}

func main() {
	flag.Parse()

	log.SetFlags(0)
	log.Printf("addr: %s\n", *addr)

	http.HandleFunc("/echo", echo)
	log.Fatal(http.ListenAndServe(*addr, nil))
}
```

# 4. 客户端

```go
func main() {
	defer func() {
		if err := recover(); err != nil {
			log.Printf("error: %v\n", err)
		}
	}()

	log.SetFlags(0)

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	reqUrl := url.URL{
		Scheme: "ws",
		Host:   "localhost:8080",
		Path:   "/echo",
	}
	log.Printf("Connecting to %s\n", reqUrl.String())

	conn, _, err := websocket.DefaultDialer.Dial(reqUrl.String(), nil)
	if err != nil {
		log.Fatalf("Connecting error: %v", err)
	}
	defer conn.Close()

	var input string
	receiveData := make(chan string)
	respMessage := make(chan string)

	go func() {
		for {
			fmt.Printf("Please enter message：")
			fmt.Scanf("%s\n", &input)
			if input != "" {
				receiveData <- input
			}

			fmt.Printf("Receive message: %s\n", <-respMessage)
		}
	}()

	for {
		select {
		case <-interrupt:
			log.Println("interrupt")

			err := conn.WriteMessage(websocket.CloseMessage,
				websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
			if err != nil {
				log.Printf("Write message close error: %v\n", err)
				return
			}
			close(receiveData)

		case data := <-receiveData:
			err := conn.WriteMessage(websocket.TextMessage, []byte(data))
			if err != nil {
				log.Printf("Write message error: %v\n", err)
				return
			}

			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("Read message error: %v\n", err)
			} else {
				respMessage <- string(message)
			}
		}
	}
}
```
