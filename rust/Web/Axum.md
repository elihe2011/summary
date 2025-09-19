# 1. 简介

`Axum` 利用了 hyper 库的功能来增强 Web 应用程序的速度和并发性。它还通过与 `Tokio` 库集成，将 Rust 的 `async/await` 功能推到了前台，使得开发者可以开发高性能的异步 API 和 Web 应用程序。

Rust 的一些特点：

- 使用无宏的 API 实现路由 (router) 功能
- 使用提取器 (extractor) 堆请求进行声明式的解析
- 简单和可预测的错误处理模式
- 用最少的模板生成响应
- 充分利用 tower 和 tower-http 的中间件、服务和工具的生态系统



Axum 没有自己的中间件系统，而是使用 `tower::Service`。这意味着 axum 可以无成本地获得超时、跟踪、压缩、授权等功能。它还可以让你与使用 hyper 或 tonic 编写的应用程序共享中间件。



# 2. 入门

添加依赖：

```toml
[dependencies]
axum = "0.8.4"
tokio = { version = "1.47.1", features = ["full"] }
```



主函数：

```rust
use axum::Router;
use axum::routing::get;

#[tokio::main]
async fn main() {
    // 路由
    let app = Router::new().route("/", get(|| async { "Hello, world!" }));

    // 监听
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    // 启动服务
    axum::serve(listener, app).await.unwrap();
}
```



## 2.1 路由和处理器

router 用于设置 path 指向哪些服务，并负责将传入的 HTTP 请求定向到其指定的 handler。这些 handler 实际就是应用程序逻辑存在的地方。

```rust
#[tokio::main]
async fn main() {
    // 路由
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))
        .route("/foo", get(get_foo).post(post_foo))
        .route("/foo/bar", get(get_foo_bar));

    // 监听
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    // 启动服务
    axum::serve(listener, app).await.unwrap();
}

async fn get_foo() -> String {
    "GET /foo".to_owned()
}

async fn post_foo() -> String {
    "POST /foo".to_owned()
}

async fn get_foo_bar() -> String {
    "GET /foo/bar".to_owned()
}
```



## 2.2 提取器

extractors：分离传入请求以获得处理程序所需的部分，比如解析异步函数的参数等



### 2.2.1 动态 path 和 query

```rust
use std::collections::HashMap;
use std::fmt::Display;
use axum::extract::{Path, Query};
use axum::Router;
use axum::routing::get;
use serde::Deserialize;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))

        .route("/item/{id}", get(print_path_1))
        .route("/item/{name}/{age}", get(print_path_2))
        .route("/xxx/{full_path}", get(print_path_3))

        .route("/page/{id}", get(print_query_1))
        .route("/xxx", get(print_query_2));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn print_path_1(Path(id): Path<String>) -> String {
    format!("ID: {}!", id)
}

async fn print_path_2(Path((name, age)): Path<(String, i32)>) -> String {
    format!("Name: {}, Age: {}!", name, age)
}

async fn print_path_3(Path(full_path): Path<HashMap<String, String>>) -> String {
    format!("FullPath: {:?}", full_path)
}

#[derive(Deserialize, Debug)]
struct Page {
    index: u32,
    size: u32,
}

impl Display for Page {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "index={}, size={}", self.index, self.size)
    }
}

async fn print_query_1(Path(id): Path<i32>, Query(page): Query<Page>) -> String {
    format!("ID: {}, Page: {}", id, page)
}

async fn print_query_2(query: Query<HashMap<String, String>>) -> String {
    format!("Query: {:?}", query)
}
```



验证结果：

```
/item/1 => ID: 1
/item/doris/22 => Name: doris, Age: 22
/xxx/{abc: 123, xyz: 789} => FullPath: "{abc: 123, xyz: 789}"
/page/2?index=1&size=20 => ID: 2, Page: index=1, size=20
/xxx?version=0.1&src=ins => Query: Query({"version": "0.1", "src": "ins"})
```



### 2.2.2 body

请求体参数一般有两种格式：`json` 和 `form`

```rust
use axum::routing::{get, post};
use axum::{Form, Json, Router};
use serde::Deserialize;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))

        .route("/register", post(register))
        .route("/login", post(login));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

#[derive(Deserialize, Debug)]
struct User {
    username: String,
    password: String,
    age: u8,
}

async fn register(Json(payload): Json<User>) -> String {
    format!("Register {:?}", payload)
}

#[derive(Deserialize, Debug)]
struct Login {
    username: String,
    password: String,
}

async fn login(Form(payload): Form<Login>) -> String {
    format!("Login {:?}", payload)
}
```

这里的 Form 要求的 Content-Type 必须是 `application/x-www-form-urlencoded`

Form 表单对比：

- **application/x-www-form-urlencoded**

  - **数据格式**：将所有表单数据编码为一个长字符串，键值对之间用 `&` 分隔，键和值本身进行URL编码。
  - **用途**：适用于只包含文本数据的简单表单，如登录表单、搜索表单等。

  - **优点**：:数据量小，易于解析，是浏览器默认的表单提交格式。
  - **缺点**：无法直接传输二进制文件。

- **multipart/form-data**

  - **数据格式**：将表单数据分割成多个部分，每个部分都有自己的头部和内容，不同部分之间使用一个自定义的“边界字符串”分隔。
  - **用途**：主要用于需要上传文件或发送包含二进制数据的表单，也支持文本字段。

  - **优点**：能够高效地处理文件上传和包含二进制数据的情况。
  - **缺点**：由于数据格式复杂，传输数据量会比 `x-www-form-urlencoded` 大。﻿



### 2.2.3 header

一般通过 `HeaderMap` 来获取请求头参数

```rust
use axum::http::HeaderMap;
use axum::routing::get;
use axum::Router;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))

        .route("/useragent", get(useragent))
        .route("/headers", get(headers));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn useragent(headers: HeaderMap) -> String {
    headers.get(axum::http::header::USER_AGENT)
        .and_then(|h| h.to_str().ok())
        .map(|h| h.to_string())
        .unwrap()
}

async fn headers(headers: HeaderMap) -> String {
    let mut mapping = Vec::new();
    for (k, v) in headers.iter() {
        let line = format!("{} - {}\n", k, v.to_str().unwrap());
        mapping.push(line);
    }
    mapping.join("\n")
}
```



## 2.3 响应处理

任何实现 `IntoResponse` trait 的对象，都可以被处理程序返回，它将被自动转换为响应

```json
use axum::routing::get;
use axum::{Json, Router};

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))

        .route("/text", get(text))
        .route("/json", get(json));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn text() -> &'static str {
    "Hello, world!"
}

async fn json() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "message": "Hello, world!" }))
}
```



## 2.4 错误处理

`axum` 基于 `tower::Service`，它通过关联的 `错误` 类型。如果 `Service` 产生错误，并且该错误一直到了 hyper，连接将被终止，而不会发送响应，这不可取。

因此 `axum` 会确保始终依赖 type system 生成响应。`axum` 通过要求所有服务都将 `Infallible` 作为其错误类型来实现这一点。

一般 `axum` 的 handler 绑定的方法这样定义：

```rust
use axum::http::StatusCode;

async fn handler() -> Result<String, StatusCode> {
    // ...
}
```



错误处理示例，添加依赖：

```toml
[dependencies]
...
anyhow = "1.0"
tower = { version = "0.5", features = ["full"] }
```

错误处理：

```rust
use axum::body::Body;
use axum::error_handling::HandleError;
use axum::http::StatusCode;
use axum::response::Response;
use axum::routing::get;
use axum::Router;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))

        .merge(router_fallible_service())
        .route("/foo", get(foo));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

fn router_fallible_service() -> Router {
    let some_fallible_service = tower::service_fn(|_req| async {
        thing_that_might_fail().await?;
        Ok::<_, anyhow::Error>(Response::new(Body::empty()))
    });

    Router::new().route_service(
        "/test_error",
        HandleError::new(some_fallible_service, handle_anyhow_error),
    )
}

async fn thing_that_might_fail() -> Result<(), anyhow::Error> {
    anyhow::bail!("thing_that_might_fail");
}

async fn handle_anyhow_error(e: anyhow::Error) -> (StatusCode, String) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("Something went wrong: {}", e)
    )
}

async fn foo() -> Result<String, StatusCode> {
    Ok("Hello, world!".into())
}
```



## 2.5 中间件

`axum` 没有定制中间件系统，而是与 tower 集成，tower 和 tower-http 中间件都可以与它一起使用。

`axum` 也可以将请求路由到任何 tower 服务。可以是用 `service_fn` 编写的服务，也可以是来自其它 crate 的东西。这样做能充分复用和利用不同应用的生态。

```rust 
use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::middleware::{self, Next};
use axum::response::Response;
use axum::routing::get;
use axum::Router;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))
        .route("/foo", get(foo))
        .layer(middleware::from_fn(logging_middleware));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}


async fn foo() -> Result<String, StatusCode> {
    Ok("Hello, world!".into())
}


async fn logging_middleware(req: Request<Body>, next: Next<>) -> Response {
    println!("Received a request to {}", req.uri());
    next.run(req).await
}
```



# 3. 集成日志

Tracing 库是一个用于检测 Rust 程序已收集结构化、基于事件的诊断信息的框架。它允许开发者跟踪异步操作的执行流，以更好地理解、监控和调试应用程序。

对于复杂的异步编程模型，传统的日志消息通常效率低下，且难以掌握整个执行流程。而 Tracing 扩展了日志记录样式的诊断，允许库和应用程序记录结构化事件，可以按 **区间span** 记录日志，并提供有关时间性和因果关系的附件信息，并收集关键的上下文信息，极大地提高了应用程序的可观测性。



## 3.1 依赖

```toml
tracing = { version = "0.1.41", features = ["async-await"] }
tracing-subscriber = { version = "0.3.20", features = ["env-filter", "chrono"] }
```



## 3.2 记录日志

日志设置：

```rust
// logger.rs
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;

pub fn init() {
    // try from env RUST_LOG
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(
            tracing_subscriber::fmt::layer()
                .with_file(true)
                .with_line_number(true)
                .with_thread_ids(true)
                .with_thread_names(true)
                .with_target(false)
        )
        .init();
}
```



主程序：

```rust
// main.rs
use axum::routing::get;
use axum::{Json, Router};
use axum_macros::debug_handler;
use serde_json::{json, Value};

mod logger;

#[tokio::main]
async fn main() {
    // 初始化
    logger::init();

    let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))
        .route("/test", get(test));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    tracing::info!("Listening on {}", listener.local_addr().unwrap());

    axum::serve(listener, app).await.unwrap();
}

#[debug_handler]
async fn test() -> Json<Value> {
    tracing::trace!("trace");
    tracing::debug!("debug");
    tracing::info!("info");
    tracing::warn!("warn");
    tracing::error!("error");

    Json(json!({
        "code": 0,
        "message": "success",
        "data": {
            "abc": 123,
        },
    }))
}
```



日志输出：

```
2025-09-17T07:10:49.019409Z  INFO main ThreadId(01) src\main.rs:18: Listening on 0.0.0.0:3000
2025-09-17T07:11:48.996611Z  INFO tokio-runtime-worker ThreadId(02) src\main.rs:27: info
2025-09-17T07:11:48.996853Z  WARN tokio-runtime-worker ThreadId(02) src\main.rs:28: warn
2025-09-17T07:11:48.996959Z ERROR tokio-runtime-worker ThreadId(02) src\main.rs:29: error
```



## 3.3 Spans

Span 表示具有开始、结束的时间段及其它元数据，当程序开始在上下文中执行或执行工作单元，则输入该上下文的 span，当它停止该上下文中执行时，它将退出 span。

```rust
use tracing::{span, Level};

let span = span!(Level::TRACE, "my_span");

// `enter` returns a RAII guard which, when dropped, exits the span. this
// indicates that we are in the span for the current lexical scope.
let _enter = span.enter();
// perform some work in the context of `my_span`...
```



## 3.4 Events

Event 表示在记录跟踪时发生的事件。可与非结构化日志记录代码发出的日志记录相媲美，但与典型的 log 行不同，Event 可能在 span 的上下文中发生

```rust
use tracing::{event, span, Level};

// records on event outside of any span context
event!(Level::INFO, "something happend");

let span = span!(Level::INFO, "my_span");
let _guard = span.enter();

// records an event within `my_span`
event!(Level::DEBUG, "something happened inside my_span");
```



# 4. 配置文件

在 Rust 中，配置文件解析，一般使用 config 库，它支持多种格式 (`yaml`, `json`, `toml`, `ini`等)

```toml
config = { version = "0.15.16", features = ["yaml"] }
```



## 4.1 解析配置

配置文件：

```yaml
# config.yaml
server:
  host: 127.0.0.1
  port: 8080
  log_level: info

database:
  url: "postgres://user:pass@localhost/db"
  pool_size: 5
```



解析配置-入口：

```rust
// src/config/mod.rs
mod server;
mod database;

use anyhow::{anyhow, Context};
use config::{Config, FileFormat};
use database::DatabaseConfig;
use serde::Deserialize;
use server::ServerConfig;
use std::sync::LazyLock;

#[derive(Debug, Deserialize)]
pub struct AppConfig {
    server: ServerConfig,
    database: DatabaseConfig,
}

// 全局静态对象，只初始化一次，线程安全
static CONFIG: LazyLock<AppConfig> =
    LazyLock::new(|| AppConfig::load().expect("Unable to load config"));

// 支持通过环境变量 APP__XX__XX 覆盖配置文件
impl AppConfig {
    pub fn load() -> anyhow::Result<Self> {
        Config::builder()
            .add_source(
                config::File::with_name("config")
                    .format(FileFormat::Yaml)
                    .required(true)
            )
            .add_source(
                config::Environment::with_prefix("APP")
                    .try_parsing(true)
                    .separator("__")
            )
            .build()
            .with_context(|| anyhow!("Unable to load config file"))?
            .try_deserialize()
            .with_context(|| anyhow!("Unable to deserialize config file"))
    }

    pub fn server(&self) -> &ServerConfig {
        &self.server
    }

    pub fn database(&self) -> &DatabaseConfig {
        &self.database
    }
}

pub fn get() -> &'static AppConfig {
    &CONFIG
}
```



解析配置-server：

```rust
// src/config/server.rs
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: Option<u16>,
    pub log_level: Option<String>,
}

impl ServerConfig {
    pub fn host(&self) -> String {
        self.host.clone()
    }
    pub fn port(&self) -> u16 {
        self.port.unwrap_or(3000)
    }

    pub fn log_level(&self) -> String {
        match self.log_level {
            Some(ref level) => level.clone(),
            None => "info".to_string(),
        }
    }
}
```



解析配置-database：

```rust
// src/config/database.rs
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct DatabaseConfig {
    pub url: String,
    pub pool_size: u32,
}
```



## 4.2 使用配置

```rust
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;

mod config;

#[tokio::main]
async fn main() {
    let ac = config::get();
    println!("{:#?}", ac);

    tracing_subscriber::registry()
        .with(EnvFilter::new(ac.server().log_level()))
        .init();

    let app = Router::new()
        .route("/", get(index))
        .route("/db", get(database));

    let addr = format!("{}:{}", ac.server().host(), ac.server().port());
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    tracing::info!("listening on {}", listener.local_addr().unwrap());

    axum::serve(listener, app).await.unwrap();
}

async fn index() -> Json<Value> {
    Json(json!({
        "code": 0,
        "message": "success",
        "data": {
            "id": 1,
            "name": "Alex",
        }
    }))
}

async fn database() -> String {
    let dc = &config::get().database();

    format!("{:#?}", dc)
}
```



## 4.3 读取`.env`文件

引入依赖：

```toml
[dependencies]
dotenv = "0.15"
```



解析配置：

```rust
use axum::http::StatusCode;
use axum::routing::get;
use axum::Router;
use dotenv::dotenv;
use std::env;

#[tokio::main]
async fn main() {
    // 加载.env
    dotenv().ok();

    let app = Router::new()
        .route("/", get(index));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn index() -> Result<String, StatusCode> {
    let book = env::var("BOOK").map_err(|_| StatusCode::NOT_FOUND)?;
    Ok(book)
}
```





















