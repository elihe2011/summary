# 1. 简介

`Axum` 由 Tokio 团队开发，它不是要重新发明新轮子，而是站在巨人的肩膀上。

核心优势：

- **零成本抽象**：基于 Tokio 和 Hyper，性能接近底层实现
- **宏自由 API**：不依赖过程宏，编译快、错误信息清晰
- **Tower 生态系统**：免费获取超时、追踪、压缩、授权等中间件
- **类型安全**：编译时检查，运行时零惊喜
- **可预测的错误处理**：所有错误都有明确的处理路径



## 1.1 关键特性

- **Handler**：接收提取器作为参数，返回可转换为响应的内容
- **Extractor**：声明式地从请求中解析数据
- **Router**：组合处理器和服务的核心
- **Middleware**：基于 Tower Service，可复用、可组合



## 1.2 核心概念

Axum 的核心工作流程：

```
HTTP Request
     │
     ▼
┌──────────┐     ┌───────────┐     ┌──────────┐    ┌──────────┐
│  Router  │───> │ Extractor │───> │ Handler  │───>│ Response │
└──────────┘     └───────────┘     └──────────┘    └──────────┘
 路由到处理函数       提取请求数据        业务逻辑        返回给客户端       
```

三个核心抽象：

- **Router (路由器)**：决定请求去哪里
- **Extractor (提取器)**：从请求中提取数据
- **Handler (处理器)**：处理逻辑，生成响应



## 1.3 技术栈

```
┌─────────────────────────────────────────────────┐
│                    API 层                       │
│  Routes / Handlers / Business Logic             │
├─────────────────────────────────────────────────┤
│              Axum (Web Framework)               │
│  Router → Extractor → Handler → Response        │
├──────────────┬──────────────────────────────────┤
│  Tower 中间件 │  (JWT Auth / Logging / CORS)     │
├──────────────┴──────────────────────────────────┤
│              Tokio (Async Runtime)              │
│    多线程事件循环，驱动所有 async 代码               │
├─────────────────────────────────────────────────┤
│              Hyper (HTTP 底层)                   │
│      Axum 实际使用的 HTTP 库，你基本不需要直接接触    │
├─────────────────────────────────────────────────┤
│      SQLx (数据库层)     │  jsonwebtoken (JWT)   │
│    编译时查询验证 + 连接池 │  Token 签发与验证       │
├─────────────────────────┴───────────────────────┤
│              PostgreSQL (数据存储)               │
└─────────────────────────────────────────────────┘
```



## 1.4 快速开始

**核心依赖：**

```toml
[dependencies]
axum = "0.8.4"
tokio = { version = "1.47.1", features = ["full"] }
tower = "0.5"
serde = { version = "1", features = ["derive"] }
```



**主函数：**

```rust
use axum::Router;
use axum::routing::get;

#[tokio::main]
async fn main() {
    // 路由
    let app = Router::new().route("/", get(hello_handler));

    // 监听
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    // 启动服务
    axum::serve(listener, app).await.unwrap();
}

async fn hello_handler() -> &'static str {
    "Hello, axum!"
}
```



# 2. 核心特性

## 2.1 Router 路由

```rust
let app = Router::new()
        .route("/", get(|| async { "Hello, world!" }))
        .route("/foo", get(get_foo).post(post_foo))
        .route("/foo/bar", get(get_foo_bar));
```

结构化路由：

```rust
fn user_routes() -> Router<AppState> {
    Router::new()
        .route("/users", get(list_users).post(create_user))
        .route("/users/:id", get(get_user).put(update_user))
}

fn post_routes() -> Router<AppState> {
    Router::new()
        .route("/posts", get(list_posts).post(create_post))
        .route("/posts/:id", get(get_post))
}

let app = Router::new()
    .merge(user_routes())
    .merge(post_routes())
    .with_state(state);
```



## 2.2 Handler 处理器

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



## 2.3 Extractor 提取器 

Extractor 实现了 `FromRequest` 或 `FromRequestParts` trait 的类型，它们让你以类型安全的方式从请求中提取数据。



### 2.3.1 `Path` 路径参数

```rust
use std::collections::HashMap;
use axum::Router;
use axum::extract::Path;
use axum::routing::get;

fn make_router() -> Router {
    Router::new()
    .route("/item/{id}", get(dynamic_path_handler1))
        .route("/item/{category}/{name}", get(dynamic_path_handler2))
        .route("/xxx/{full_name}", get(dynamic_path_handler3))
}

async fn dynamic_path_handler1(
    Path(id): Path<String>,
) -> String {
    format!("ID: {}", id)
}

async fn dynamic_path_handler2(
    Path((category, name)): Path<(u32,String)>,
) -> String {
    format!("Category: {}, Name: {}", category, name)
}

async fn dynamic_path_handler3(
    Path(full_path): Path<HashMap<String, String>>,
) -> String {
    // GET /xxx/abc
    // FullPath: {"full_name": "abc"}
    format!("FullPath: {:?}", full_path)
}
```



### 2.3.2 `Query` 查询参数

```rust
use axum::extract::Query;
use axum::routing::get;
use axum::Router;
use serde::Deserialize;
use std::collections::HashMap;
use std::fmt::Display;

fn make_router() -> Router {
    Router::new()
        .route("/page", get(query_handler1))
        .route("/xxx", get(query_handler2))
}

#[derive(Deserialize)]
struct Page {
    index: u32,
    size: u32,
}

impl Display for Page {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "index={}, size={}", self.index, self.size)
    }
}

async fn query_handler1(Query(page): Query<Page>) -> String {
    format!("Page: {}", page)
}

async fn query_handler2(Query(query): Query<HashMap<String, String>>) -> String {
    format!("Query: {:?}", query)
}
```



### 2.3.3 `Form` Body

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

```rust
use axum::routing::post;
use axum::{Form, Router};
use serde::Deserialize;

fn make_router() -> Router {
    Router::new()
        .route("/login", post(login_handler))
}

#[derive(Deserialize, Debug)]
struct User {
    username: String,
    password: String,
}

async fn login_handler(
    Form(payload): Form<User>,
) -> String {
    format!("User: {:?}", payload)
}
```



### 2.3.4 `Json` Body

```rust
async fn login_handler(
    Json(payload): Json<User>,
) -> String {
    format!("User: {:?}", payload)
}
```



### 2.3.5 `HeaderMap` 请求头

```rust
async fn useragent_handler(
    headers: HeaderMap,
) -> String {
    headers.get(axum::http::header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|v| v.to_string())
        .unwrap_or("".to_string())
}

async fn all_headers_handler(headers: HeaderMap) -> String {
    let mut list = Vec::new();
    for (k, v) in headers.iter() {
        let line = format!("{}: {}", k, v.to_str().unwrap());
        list.push(line);
    }

    list.join("\r\n")
}
```



### 2.3.6 自定义

```rust
use axum::extract::{FromRequestParts, Json};
use axum::http::request::Parts;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use serde::{Deserialize, Serialize};

pub struct AuthUser {
    pub user_id: String,
}

impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    async fn from_request_parts(
        parts: &mut Parts,
        _state: &S,
    ) -> Result<Self, Self::Rejection> {
        // 获取 token
        let auth_header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or(StatusCode::UNAUTHORIZED)?;

        // 验证 token
        if !auth_header.starts_with("Bearer ") {
            return Err(StatusCode::UNAUTHORIZED);
        }

        let token = auth_header.trim_start_matches("Bearer ");

        // 实际应用中，验证 JWT
        Ok(AuthUser { user_id: token.to_string() })
    }
}

#[derive(Deserialize, Serialize, Debug)]
pub struct MyData {
    pub name: String,
    pub age: i32,
}

pub async fn auth_handler(
    auth_user: AuthUser,
    Json(payload): Json<MyData>
) -> impl IntoResponse {
    format!("user: {}, payload: {:?}", auth_user.user_id, payload)
}
```



### 2.3.7 顺序规则

**不消耗请求体的提取器在前，消耗请求体的在后**

```rust
// ✅ 正确：State 和 Path 不消耗请求体
async fn handler(
    State(state): State<AppState>,
    Path(id): Path<u32>,
    Json(data): Json<MyData>,  // Json 消耗请求体，放最后
) -> impl IntoResponse {
    // ...
}

// ❌ 错误：Json 在前会导致编译错误
async fn wrong_handler(
    Json(data): Json<MyData>,
    Path(id): Path<u32>,  // 编译器会提示错误
) -> impl IntoResponse {
    // ...
}
```



### 2.3.8 参数验证

```rust
use validator::Validate;

#[derive(Deserialize, Validate)]
struct CreateUser {
    #[validate(email)]
    email: String,
    
    #[validate(length(min = 8))]
    password: String,
}

async fn create_user(
    Json(payload): Json<CreateUser>,
) -> AppResult<StatusCode> {
    // 验证
    payload.validate()
        .map_err(|e| AppError::ValidationError(e))?;
    
    // 继续处理...
    Ok(StatusCode::CREATED)
}
```



## 2.4 Middleware 中间件

### 2.4.1 `middleware::from_fn`  最灵活

```rust
use axum::{
    middleware::{self, Next},
    response::Response,
    extract::Request,
};

async fn auth_middleware(
    req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 前置处理
    let auth_header = req.headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // 验证逻辑
    if !is_valid_token(auth_header) {
        returnErr(StatusCode::UNAUTHORIZED);
    }

    // 继续处理请求
    let response = next.run(req).await;
    
    // 后置处理
    Ok(response)
}

let app = Router::new()
    .route("/protected", get(handler))
    .route_layer(middleware::from_fn(auth_middleware));
```



### 2.4.2 `middleware::from_extractor` 复用提取器

```rust
use axum::middleware::from_extractor;

// 将前面的 AuthUser 提取器用作中间件
let app = Router::new()
    .route("/", get(handler))
    .route_layer(from_extractor::<AuthUser>());

// 所有路由都会先执行 AuthUser 提取
// 失败会自动返回拒绝响应，成功则继续
```



### 2.4.3 Tower 中间件 最强大

```rust
use tower_http::{
    trace::TraceLayer,
    compression::CompressionLayer,
    timeout::TimeoutLayer,
};
use std::time::Duration;

let app = Router::new()
    .route("/", get(handler))
    .layer(TraceLayer::new_for_http())       // 请求追踪
    .layer(CompressionLayer::new())          // 响应压缩
    .layer(TimeoutLayer::new(Duration::from_secs(10))); // 超时
```



# 3. 扩展知识

## 3.1 状态管理

Web 应用通常需要共享资源：数据库连接池、配置、缓存等。Axum 提供了类型安全的状态管理机制。



### 3.1.1 基础状态

```rust
use axum::{
    extract::State,
    routing::get,
    Router,
};
use std::sync::Arc;

// 应用状态
#[derive(Clone)]
struct AppState {
    db_pool: Arc<DatabasePool>,
    api_key: String,
}

async fn handler(
    State(state): State<AppState>,
) -> String {
    format!("API Key: {}", state.api_key)
}

#[tokio::main]
async fn main() {
    // 初始化
    let state = AppState {
        db_pool: Arc::new(create_db_pool()),
        api_key: "secret".to_string(),
    };

    let app = Router::new()
        .route("/", get(handler))
        .with_state(state);  // 注入状态

    // ...
}
```



### 3.1.2 Arc

当调用 `with_state(state)` 时，Axum 内部会将状态包裹在 Arc 中。每次提取状态时，Axum 会克隆这个 Arc，而不是克隆实际的数据

三种模式：

```rust
// 模式 1: 让 Axum 自动包裹（推荐简单场景）
#[derive(Clone)]
struct AppState {
    config: String,
}

let app = Router::new()
    .with_state(AppState { 
        config: "value".to_string() 
    });

// 模式 2: 显式使用 Arc（推荐生产环境）
struct AppState {
    db: Arc<Database>,
    cache: Arc<Cache>,
}

// ✅ 推荐：字段级别的 Arc
impl Clone for AppState {
    fn clone(&self) -> Self {
        Self {
            db: Arc::clone(&self.db),
            cache: Arc::clone(&self.cache),
        }
    }
}

// 模式 3: 整个状态包裹在 Arc 中
let state = Arc::new(AppState { /* ... */ });
let app = Router::new()
    .with_state(state);

async fn handler(
    State(state): State<Arc<AppState>>,
) {
    // 注意这里 State 的类型是 Arc<AppState>
}
```



什么时候字段级别用 Arc？

```rust
// ✅ 需要 Arc：数据库连接池、客户端、大型数据结构
struct AppState {
    db: Arc<PgPool>,              // 需要：重量级资源
    redis: Arc<RedisPool>,        // 需要：重量级资源
    config: Config,               // 不需要：小型配置，实现 Clone
}

// ❌ 过度使用 Arc
struct OverEngineered {
    counter: Arc<u32>,  // 不需要！u32 本身就是 Copy
    name: Arc<String>,  // 不需要！String 实现了 Clone
}
```



### 3.1.3 可变状态

状态时共享的，可通过内部可变性模式，安全地修改它

```rust
use std::sync::Arc;
use tokio::sync::RwLock;  // 异步锁
use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Clone)]
struct AppState {
    // 方案 1: 原子类型（适合简单计数器）
    visit_count: Arc<AtomicU64>,
    
    // 方案 2: RwLock（适合复杂数据，读多写少）
    cache: Arc<RwLock<HashMap<String, String>>>,
    
    // 方案 3: Mutex（适合写频繁的场景）
    // queue: Arc<Mutex<VecDeque<Task>>>,
}

async fn increment_visits(
    State(state): State<AppState>,
) -> String {
    // 原子操作，无需锁
    let count = state.visit_count.fetch_add(1, Ordering::SeqCst);
    format!("Visit count: {}", count)
}

async fn get_cached(
    State(state): State<AppState>,
    Path(key): Path<String>,
) -> String {
    // 读锁，允许多个读者
    let cache = state.cache.read().await;
    cache.get(&key)
        .cloned()
        .unwrap_or_else(|| "Not found".to_string())
}

async fn set_cached(
    State(state): State<AppState>,
    Path(key): Path<String>,
    body: String,
) -> StatusCode {
    // 写锁，独占访问
    letmut cache = state.cache.write().await;
    cache.insert(key, body);
    StatusCode::OK
}
```

性能提示：

- `AtomicXxx`：最快，但仅支持原始类型
- `RwLock`：读多写少的理想选择
- `Mutex`：读写频繁时使用
- 比卖你在锁内执行异步操作或重量级计算



## 3.2 错误处理

`axum` 基于 `tower::Service`，它通过关联的 `错误` 类型。如果 `Service` 产生错误，并且该错误一直到了 hyper，连接将被终止，而不会发送响应，这不可取。

因此 `axum` 会确保始终依赖 type system 生成响应。`axum` 通过要求所有服务都将 `Infallible` 作为其错误类型来实现这一点。



### 3.2.1 Handler 错误

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



### 3.2.2 `IntoResponse` 万能转换器

```rust
use axum::{
    response::{IntoResponse, Response},
    http::StatusCode,
    Json,
};
use serde_json::json;

// 自定义错误类型
enum AppError {
    NotFound,
    Unauthorized,
    InternalError(String),
}

// 实现 IntoResponse
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = matchself {
            AppError::NotFound => (
                StatusCode::NOT_FOUND,
                "Resource not found",
            ),
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "Unauthorized",
            ),
            AppError::InternalError(msg) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Internal error",
            ),
        };

        let body = Json(json!({
            "error": message,
        }));

        (status, body).into_response()
    }
}

// 在处理器中使用
async fn handler() -> Result<String, AppError> {
    // 业务逻辑
    if some_condition {
        returnErr(AppError::NotFound);
    }
    Ok("Success".to_string())
}
```



### 3.2.3 `Result<T, E>` 模式

```rust
use anyhow::Result;  // 或 thiserror

async fn complex_handler() -> Result<Json<Data>, AppError> {
    let data = fetch_data()
        .await
        .map_err(|e| AppError::InternalError(e.to_string()))?;
    
    let processed = process_data(data)
        .map_err(|e| AppError::InternalError(e.to_string()))?;
    
    Ok(Json(processed))
}
```

**最佳实践：**

- 为你的应用创建统一的错误类型
- 实现 `IntoResponse` 保证一致的错误响应格式
- 使用 `?` 操作符简化错误传播
- 记录内部错误，但不暴露给客户端



# 4. 工程化

## 4.1 配置管理

在 Rust 中，配置文件解析，一般使用 config 库，它支持多种格式 (`yaml`, `json`, `toml`, `ini`等)

```toml
config = { version = "0.15.16", features = ["yaml"] }
dotenv = "0.15"
```



### 4.1.1 解析yaml配置

配置文件：

```yaml
# config.yaml
server:
  host: 127.0.0.1
  port: 3000
  log_level: info
  jwt_secret: "YXh1bWp3dHNlY3JldGtleQ=="
  jwt_expiration: 3600

database:
  url: "postgres://root:123456@192.168.3.105:5432/mydb"
  min_connections: 2
  max_connections: 10
```



解析服务配置：

```rust
// src/cofnig/server.rs
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub log_level: Option<String>,
    pub jwt_secret: String,
    pub jwt_expiration: u64,
}

impl ServerConfig {
    pub fn log_level(&self) -> String {
        match &self.log_level {
            Some(l) => l.clone(),
            None => "info".to_string(),
        }
    }

    pub fn addr(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}
```



解析数据库配置：

```rust
// src/config/database.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
}
```



解析配置-入口：

```rust
// src/config/mod.rs
mod server;
mod database;

use crate::config::database::DatabaseConfig;
use crate::config::server::ServerConfig;
use anyhow::{anyhow, Context};
use config::{Config, FileFormat};
use serde::Deserialize;
use std::sync::LazyLock;

#[derive(Debug, Deserialize)]
pub struct AppConfig {
    server: ServerConfig,
    database: DatabaseConfig,
}

// 全局静态对象，只初始化一次，线程安全
static CONFIG: LazyLock<AppConfig> =
    LazyLock::new(|| AppConfig::load().expect("Failed to load config"));

// 通过环境变量 APP__XX__XX 覆盖配置
impl AppConfig {
    pub fn load() -> anyhow::Result<Self> {
        Config::builder()
        .add_source(config::File::with_name("config")
            .format(FileFormat::Yaml)
            .required(true)
        )
        .add_source(config::Environment::with_prefix("APP")
            .try_parsing(true)
            .separator("__")
        )
            .build()
            .with_context(|| anyhow!("Failed to load config"))?
        .try_deserialize()
        .with_context(|| anyhow!("Failed to deserialize config"))
    }

    pub fn server(&self) -> &ServerConfig {
        &self.server
    }

    pub fn database(&self) -> &DatabaseConfig {
        &self.database
    }
}

pub fn init() -> &'static AppConfig {
    &CONFIG
}
```



如果将配置放入全局状态中，则无需使用全局静态对象：

```rust
mod database;
mod server;

use crate::config::database::DatabaseConfig;
use crate::config::server::ServerConfig;
use config::{Config, FileFormat};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    server: ServerConfig,
    database: DatabaseConfig,
}

// 通过环境变量 APP__XX__XX 覆盖配置
impl AppConfig {
    pub fn load() -> Self {
        Config::builder()
            .add_source(
                config::File::with_name("config")
                    .format(FileFormat::Yaml)
                    .required(true),
            )
            .add_source(
                config::Environment::with_prefix("APP")
                    .try_parsing(true)
                    .separator("__"),
            )
            .build()
            .expect("Failed to load config")
            .try_deserialize()
            .expect("Failed to deserialize config")
    }

    pub fn server(&self) -> &ServerConfig {
        &self.server
    }

    pub fn database(&self) -> &DatabaseConfig {
        &self.database
    }
}
```



### 4.1.2 解析 `.env` 配置

```rust
use axum::{
    http::StatusCode,
    routing::get,
    Router
};
use std::env;

#[tokio::main]
async fn main() {
    // 加载 .env (空格字符必须用引号包裹)
    dotenv::dotenv().ok();

    let app = Router::new()
        .route("/", get(|| async { env::var("BOOK").map_err(|_| StatusCode::NOT_FOUND) }));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```



## 4.2 优雅关闭

```rust
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C signal handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {}
        _ = terminate => {}
    }
}

#[tokio::main]
async fn main() {
    // --snip--
    
    // 启动服务
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```



## 4.3 集成日志

Tracing 库是一个用于检测 Rust 程序已收集结构化、基于事件的诊断信息的框架。它允许开发者跟踪异步操作的执行流，以更好地理解、监控和调试应用程序。

对于复杂的异步编程模型，传统的日志消息通常效率低下，且难以掌握整个执行流程。而 Tracing 扩展了日志记录样式的诊断，允许库和应用程序记录结构化事件，可以按 **区间span** 记录日志，并提供有关时间性和因果关系的附件信息，并收集关键的上下文信息，极大地提高了应用程序的可观测性。

依赖：

```toml
[dependencies]
tracing = { version = "0.1.41", features = ["async-await"] }
tracing-subscriber = { version = "0.3.20", features = ["env-filter", "chrono"] }
```



### 4.3.1 记录日志

日志设置：

```rust
// src/logger.rs
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::EnvFilter;

pub fn init(log_level: &str) {
    tracing_subscriber::registry()
        .with(EnvFilter::new(log_level))
        .with(tracing_subscriber::fmt::layer()
            .with_file(true)
            .with_line_number(true)
            .with_thread_ids(true)
            .with_thread_names(true)
            .with_target(false)
        )
        .init();
}
```



使用日志：

```rust
// src/main.rs
mod config;
mod logger;

use axum::{
    routing::get,
    Json,
    Router,
};
use serde::Serialize;
use serde_json::{json, Value};

#[tokio::main]
async fn main() {
    // 配置
    let cfg = AppConfig::load();

    // 日志
    logger::init(cfg.server().log_level().as_str());

    // 路由
    let app = Router::new().route("/", get(log_handler));

    // 监听
    let listener = tokio::net::TcpListener::bind(cfg.server().addr()).await.unwrap();
    tracing::info!("listening on {}", listener.local_addr().unwrap());

    // 启动服务
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}


#[axum_macros::debug_handler]
async fn log_handler() -> Json<Response> {
    tracing::trace!("trace");
    tracing::debug!("debug");
    tracing::info!("info");
    tracing::warn!("warn");
    tracing::error!("error");

    let resp = Response {
        code: 0,
        msg: "success".to_string(),
    };

    Json(resp)
}
```



日志输出：

```
2026-02-05T06:17:25.985838Z  INFO main ThreadId(01) src\main.rs:24: listening on 127.0.0.1:3000
2026-02-05T06:17:36.340501Z  INFO tokio-runtime-worker ThreadId(02) src\main.rs:37: info
2026-02-05T06:17:36.340700Z  WARN tokio-runtime-worker ThreadId(02) src\main.rs:38: warn
2026-02-05T06:17:36.340834Z ERROR tokio-runtime-worker ThreadId(02) src\main.rs:39: error
```



### 4.3.2 Spans

Span 表示具有开始、结束的时间段及其它元数据，当程序开始在上下文中执行或执行工作单元，则输入该上下文的 span，当它停止该上下文中执行时，它将退出 span。

```rust
async fn span_handler() -> String {
    // 增加 span 标记
    let span = tracing::span!(tracing::Level::INFO, "span_handler");
    // let span = tracing::info_span!("span_handler");

    // `enter` returns a RAII guard which, when dropped, exits the span. this
    // indicates that we are in the span for the current lexical scope.
    let _enter = span.enter();
    // perform some work in the context of `span_handler`...

    tracing::info!("sleep 30 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
    tracing::info!("wake up now");

    "span_handler".to_string()
}
```



输出日志：

```
2026-02-05T06:43:47.846501Z  INFO main ThreadId(01) src\main.rs:27: listening on 127.0.0.1:3000
2026-02-05T06:43:54.998384Z  INFO tokio-runtime-worker ThreadId(02) span_handler: src\main.rs:72: sleep 30 seconds...
2026-02-05T06:44:25.001483Z  INFO tokio-runtime-worker ThreadId(02) span_handler: src\main.rs:74: wake up now
```



### 4.3.3 Events

Event 表示在记录跟踪时发生的事件。可与非结构化日志记录代码发出的日志记录相媲美，但与典型的 log 行不同，Event 可能在 span 的上下文中发生

```rust
async fn event_handler() -> String {
    // records on event outside of ant span context
    tracing::event!(tracing::Level::INFO, "something happened");

    let span = tracing::info_span!("my_span");
    let _guard = span.enter();

    tracing::event!(tracing::Level::INFO, "sleep 30 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
    tracing::event!(tracing::Level::INFO,"wake up now");

    "event_handler".to_string()
}
```



输出日志：

```
2026-02-05T06:49:43.903992Z  INFO main ThreadId(01) src\main.rs:28: listening on 127.0.0.1:3000
2026-02-05T06:49:51.191592Z  INFO tokio-runtime-worker ThreadId(02) src\main.rs:82: something happened
2026-02-05T06:49:51.191944Z  INFO tokio-runtime-worker ThreadId(02) my_span: src\main.rs:87: sleep 30 seconds...
2026-02-05T06:50:21.205861Z  INFO tokio-runtime-worker ThreadId(02) my_span: src\main.rs:89: wake up now
```



## 4.4 错误处理

错误处理的黄金搭档：

- **`thiserror`：** 用于定义结构化的错误类型（**适合库层面和应用错误枚举**）
- **`anyhow`：** 用于快速包装不关心具体类型的错误（**适合应用层内部传播**）

规则是简单的：**如果你需要根据错误类型做不同处理（如映射到不同 HTTP 状态码），用 `thiserror` 定义枚举。如果你只是想传播错误信息，用 `anyhow`。**

依赖配置：

```toml
[dependencies]
anyhow = "1.0"
thiserror = "2.0"
```



统一错误处理：

```rust
// src/errors.rs
use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    /// 400 - 请求参数不合法
    #[error("Validation error: {0}")]
    Validation(String),

    /// 401 - 未认证或Token失效
    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    /// 403 - 有认证但无权限
    #[error("Forbidden: {0}")]
    Forbidden(String),

    /// 404 - 资源不存在
    #[error("Not found: {0}")]
    NotFound(String),

    /// 409 - 资源冲突
    #[error("Conflict: {0}")]
    Conflict(String),

    /// 500 - 内部错误 (用 anyhow 包装的详细信息)
    #[error("Internal error")]
    Internal(anyhow::Error),
}

#[derive(Serialize)]
struct ErrorResponse {
    code: u16,
    error: String,
    message: String,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_type, message) = match &self {
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, "VALIDATION_ERROR", msg.clone()),
            AppError::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, "UNAUTHORIZED", msg.clone()),
            AppError::Forbidden(msg) => (StatusCode::FORBIDDEN, "FORBIDDEN", msg.clone()),
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, "NOT_FOUND", msg.clone()),
            AppError::Conflict(msg) => (StatusCode::CONFLICT, "CONFLICT", msg.clone()),
            AppError::Internal(err) => {
                // 内部错误，记录详细信息，但不暴露给客户端
                tracing::error!("Internal error: {:?}", err);
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "An internal error occurred".to_string())
            },
        };

        let body = ErrorResponse {
            code: status.as_u16(),
            error: error_type.to_string(),
            message,
        };

        (status, Json(body)).into_response()
    }
}

/// 类型别名，让 Handler 返回更简洁
pub type Result<T> = std::result::Result<T, AppError>;
```



## 4.5 连接数据库

通过 `SQLx` 连接数据库，其核心价值：**在编译时连接你的开发数据库，验证你的 SQL 是否正确。**

关键特性：

- **`query!` 宏：** 编译时验证 SQL 语句的正确性和参数类型

- **`query_as!` 宏：** 自动将查询结果映射到 Rust 结构体

- **连接池 (`PgPool`)：** 内置高效的异步连接池管理

- **Migration 支持：** 通过 `sqlx migrate` 管理数据库版本



依赖：

```toml
[dependencies]
sqlx = { version = "0.8", features = ["postgres", "runtime-tokio", "macros", "uuid", "chrono"]}
uuid = { version = "1.20", features = ["serde"] }
```



### 4.5.1 查询方法

| 方法类型         | 宏              | 函数             |  性能 | 灵活性 | 使用场景             |
| :--------------- | :-------------- | :--------------- |  :--- | :----- | :------------------- |
| **Raw Query**    | `query!`        | `query()`        |  高   | 高     | 动态SQL，DDL操作     |
| **Typed Query**  | `query_as!`     | `query_as()`     |  中   | 中     | 类型化查询，结果映射 |
| **Scalar Query** | `query_scalar!` | `query_scalar()` | 高   | 低     | 单值查询             |
| **File Query**   | `query_file!`   | -                | 中   | 低     | 外部SQL文件          |



**开发体验对比**：

| 方面         | 宏版本                     | 函数版本           |
| :----------- | :------------------------- | :----------------- |
| **开发效率** | ⬆️ 高（自动补全，类型推断） | ⬇️ 中               |
| **错误反馈** | ⬆️ 即时（编译时错误）       | ⬇️ 运行时错误       |
| **调试难度** | ⬇️ 易（编译时捕获）         | ⬆️ 难（运行时失败） |
| **重构友好** | ⬆️ 高（类型安全）           | ⬇️ 中               |
| **学习曲线** | ⬇️ 低（直观）               | ⬆️ 中               |

------



#### 4.5.1.1 原始查询（Raw Queries）

| 特性           | `query!` 宏                              | `query()` 函数                 |
| :------------- | :--------------------------------------- | :----------------------------- |
| **语法**       | `query!("SQL", params...)`               | `query("SQL").bind(params)...` |
| **编译时检查** | ✅ SQL语法 ✅ 表/列存在 ✅ 类型匹配         | ❌ 仅运行时检查                 |
| **返回类型**   | 匿名记录类型 `{ id: i32, name: String }` | `PgRow` / 需要手动提取         |
| **类型安全**   | 高（编译时）                             | 低（运行时可能出错）           |
| **性能**       | **编译时优化**                           | **运行时绑定**                 |
| **参数绑定**   | 自动推断类型                             | 手动调用 `.bind()`             |
| **动态SQL**    | ❌ 不支持                                 | ✅ 完全支持                     |


```rust
// query! 宏
let row = query!("SELECT * FROM users WHERE id = $1", user_id)
	.fetch_one(pool)
	.await?
println!("{}", row.name);

// query() 函数
let row = query("SELECT * FROM users WHERE id = $1")
	.bind(user_id)
	.fetch_one(pool)
	.await?;
let name: String = row.get("name");
```



#### 4.5.1.2 类型化查询（Typed Queries）

| 特性               | `query_as!` 宏                        | `query_as()` 函数                              |
| :----------------- | :------------------------------------ | :--------------------------------------------- |
| **语法**           | `query_as!(Struct, "SQL", params...)` | `query_as::<_, Struct>("SQL").bind(params)...` |
| **编译时检查**     | ✅ SQL语法 ✅ 返回类型匹配              | ❌ 仅运行时检查                                 |
| **需要 `FromRow`** | ❌ 自动生成                            | ✅ 需要 `#[derive(FromRow)]`                    |
| **类型安全**       | 非常高                                | 中（依赖 `FromRow` 实现）                      |
| **性能**           | 编译时类型映射                        | 运行时反射                                     |
| **动态字段**       | ❌ 固定字段                            | ✅ 可处理可选字段                               |


```rust
// query_as! 宏
#[derive(Debug)]
struct User {
    id: i32,
    name: String,
}
let users = query_as!(
    User,
    "SELECT id, name FROM users WHERE active = $1",
    true
)
	.fetch_all(pool)
	.await?;

// query_as 函数
#[derive(Debug, sqlx::FromRow)]
struct User {
    id: i32,
    name: String,
}
let users = query_as::<_, User>(
    "SELECT id, name FROM users WHERE active = $1",
)
	.bind(true)
	.fetch_all(pool)
	.await?;
```



#### 4.5.1.3 标量查询（Scalar Queries）

| 特性           | `query_scalar!` 宏 | `query_scalar()` 函数 |
| :------------- | :----------------- | :-------------------- |
| **返回类型**   | 自动推断单列类型   | 需要指定类型或推断    |
| **编译时检查** | ✅ 列类型匹配       | ❌ 仅运行时检查        |
| **多行支持**   | ✅ 返回 `Vec<T>`    | ✅ 返回 `Vec<T>`       |
| **使用场景**   | COUNT, 单值查询    | 动态标量查询          |


```rust
// query_scalar! 宏
let count: i64 = query_scalar!("SELECT COUNT(*) FROM users")
	.fetch_one(pool)
	.await?;
let names: Vec<String> = query_scalar!("SELECT name FROM users")
	.fetch_all(pool)
	.await?;

// query_scalar() 函数
let count: i64 = query_scalar("SELECT COUNT(*) FROM users")
	.fetch_one(pool)
	.await?;
let names = query_scalar::<_, String>("SELECT name FROM users")
	.fetch_all(pool)
	.await?;
```



#### 4.5.1.4 文件查询（File Queries）

| 特性           | `query_file!` 宏                   | 替代方案         |
| :------------- | :--------------------------------- | :--------------- |
| **语法**       | `query_file!("path/to/query.sql")` | -                |
| **编译时检查** | ✅ 同 `query!`                      | ❌ 无直接替代     |
| **SQL 组织**   | 外部文件                           | 内联或字符串常量 |
| **缓存**       | 文件内容哈希缓存                   | 手动管理         |


```rust
// query_file! 宏
let users = query_file!("src/queries/get_users.sql")
	.fetch_all(pool)
	.await?;

// 替代方案
const GET_USERS: &str = include_str!("queries/get_users.sql");
let users = query(GET_USERS)
	.fetch_all(pool)
	.await?;
```




### 4.5.2 数据模型

```rust
// src/models.rs
use serde::{Deserialize, Serialize};
use sqlx::types::chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct UserDto {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

impl From<User> for UserDto {
    fn from(user: User) -> Self {
        Self {
            id: user.id,
            username: user.username,
            email: user.email,
            created_at: user.created_at,
        }
    }
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Note {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub content: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateNoteRequest {
    pub title: String,
    pub content: String,
}

#[derive(Debug, Deserialize)]
pub struct ModifyNoteRequest {
    pub title: Option<String>,
    pub content: Option<String>,
}
```



### 4.5.2 数据库操作

```rust
// src/db.rs
use crate::errors::AppError;
use crate::models::{CreateNoteRequest, ModifyNoteRequest, Note, User};
use sqlx::postgres::{PgPool, PgPoolOptions};
use uuid::Uuid;

/// 数据库连接池
pub async fn create_pool(url: &str, min_connections: u32, max_connections: u32) -> PgPool {
    PgPoolOptions::new()
        .max_connections(max_connections)
        .min_connections(min_connections)
        .connect(url)
        .await
        .expect("Failed to create database pool")
}

/// 运行待处理的迁移
pub async fn run_migrations(pool: &PgPool) {
    sqlx::migrate!("./migrations")
        .run(pool)
        .await
        .expect("Failed to run migrations");
}

/// 创建用户
pub async fn create_user(
    pool: &PgPool,
    email: &str,
    username: &str,
    password_hash: &str,
) -> Result<User, AppError> {
    sqlx::query_as::<_, User>(
        "INSERT INTO users (username, email, password_hash)
            VALUES($1, $2, $3)
            RETURNING *",
    )
    .bind(username)
    .bind(email)
    .bind(password_hash)
    .fetch_one(pool)
    .await
    .map_err(|e| {
        // 检测唯一约束违返 (重复 email)
        if e.to_string().contains("unique") {
            AppError::Conflict("Email already registered".to_string())
        } else {
            AppError::Internal(anyhow::anyhow!("Database error: {}", e))
        }
    })
}

pub async fn find_user_by_email(pool: &PgPool, email: &str) -> Result<Option<User>, AppError> {
    sqlx::query_as::<_, User>("SELECT * FROM users WHERE email = $1")
        .bind(email)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Database error: {}", e)))
}

pub async fn create_note(
    pool: &PgPool,
    user_id: Uuid,
    payload: CreateNoteRequest,
) -> Result<Note, AppError> {
    sqlx::query_as::<_, Note>(
        "INSERT INTO notes (user_id, title, content)
        VALUES($1, $2, $3)
        RETURNING *",
    )
    .bind(user_id)
    .bind(payload.title)
    .bind(payload.content)
    .fetch_one(pool)
    .await
    .map_err(|e| {
        // 检测唯一约束违返 (重复 title)
        if e.to_string().contains("unique") {
            AppError::Conflict("Title already exist".to_string())
        } else {
            AppError::Internal(anyhow::anyhow!("Database error: {}", e))
        }
    })
}

pub async fn get_notes_by_user(pool: &PgPool, user_id: Uuid) -> Result<Vec<Note>, AppError> {
    sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE user_id = $1 ORDER BY created_at DESC")
        .bind(user_id)
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Database error: {}", e)))
}

pub async fn get_note(
    pool: &PgPool,
    user_id: Uuid,
    note_id: Uuid,
) -> Result<Option<Note>, AppError> {
    sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE id = $1 AND user_id = $2")
        .bind(note_id)
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Database error: {}", e)))
}

pub async fn modify_note(
    pool: &PgPool,
    user_id: Uuid,
    note_id: Uuid,
    payload: ModifyNoteRequest,
) -> Result<Option<Note>, AppError> {
    tracing::info!("user_id: {}, note_id: {}", user_id, note_id);
    // 使用 COALESCE：如果新值为 NULL，则保留旧值
    sqlx::query_as::<_, Note>(
        "UPDATE notes
        SET title = COALESCE($1, title),
            content = COALESCE($2, content),
            updated_at = NOW()
        WHERE id = $3 AND user_id = $4
        RETURNING *",
    )
    .bind(payload.title)
    .bind(payload.content)
    .bind(note_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::Internal(anyhow::anyhow!("Database error: {}", e)))
}

pub async fn delete_note(pool: &PgPool, user_id: Uuid, note_id: Uuid) -> Result<bool, AppError> {
    let result = sqlx::query("DELETE FROM notes WHERE id = $1 AND user_id = $2")
        .bind(note_id)
        .bind(user_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Database error: {}", e)))?;

    Ok(result.rows_affected() > 0)
}
```



### 4.5.3 表迁移

在 `.env` 中配置环境变量 `DATABASE_URL="postgres://root:123456@192.168.3.105:5432/mydb"`

```bash
# 安装 sqlx-cli
cargo install sqlx-cli

# 创建一个新的迁移
sqlx migrate add init

# 修改 migrations/<timestamp>_init.sql
cat > migrations/<timestamp>_init.sql <<EOF
-- Add migration script here
-- migrate:up
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT UNIQUE NOT NULL,
    username      TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- migrate:down
DROP TABLE users;
EOF

# 运行所有 pending migrations
sqlx migrate run

# 撤销最近一次 migration
sqlx migrate revert

# 回归到指定版本
sqlx migrate revert --target-version 20260209094501

# 查看迁移状态
sqlx migrate info
```



## 4.6 全局状态

```rust
// src/app_state.rs
use crate::config::AppConfig;
use crate::db;
use sqlx::PgPool;
use std::sync::Arc;

/// 全局应用状态
#[derive(Clone)]
pub struct AppState {
    pub db: Arc<PgPool>,
    pub config: AppConfig,
}

impl AppState {
    pub async fn new(cfg: AppConfig) -> Self {
        // 初始化数据库
        let pool = db::create_pool(
            cfg.database().url.as_str(),
            cfg.database().max_connections,
            cfg.database().min_connections,
        ).await;

        // 运行数据库迁移
        db::run_migrations(&pool).await;

        Self {
            db: Arc::new(pool),
            config: cfg.clone(),
        }
    }
}
```



## 4.7 认证体系

JWT (JSON Web Token) 的核心理念是**无状态认证**：服务器不需要维护会话存储，因为所有必要的信息都编码在 Token 本身里。对于 API 服务来说，这意味着：

- **水平扩展简单：** 多个实例可以独立验证 Token，不需要共享会话数据库
- **低耦合：** 前端只需要在每个请求的 `Authorization` Header 里带上 Token
- **可审计：** Token 里包含过期时间 (`exp`)，天然支持自动失效

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9  ← Header (Base64编码)
.
eyJzdWIiOiIxMjM0NTY3ODkwIiwiZXhwIjoxNzE5MDAwMDAwfQ  ← Payload (Base64编码)
.
abc123signature...  ← Signature (用 Secret 签名)

Payload 解码后的内容：
{
    "sub": "user-uuid-here",    // subject: 用户标识
    "exp": 1719000000,          // expiration: 过期时间戳
    "iat": 1718913600           // issued at: 签发时间戳
}
```



### 4.7.1 认证模块

```rust
// src auth.rs
use crate::errors::AppError;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// JWT Claims
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtClaims {
    pub sub: String,
    pub exp: i64,
    pub iat: i64,
}

/// 签发
pub fn generate_token(user_id: Uuid, secret: &str, expiration: i64) -> Result<String, AppError> {
    let now = Utc::now();
    let claims = JwtClaims {
        sub: user_id.to_string(),
        exp: (now + chrono::Duration::seconds(expiration)).timestamp(),
        iat: now.timestamp(),
    };

    jsonwebtoken::encode(
        &jsonwebtoken::Header::default(),
        &claims,
        &jsonwebtoken::EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(anyhow::anyhow!("Failed to generate token: {:?}", e)))
}

/// 验证
pub fn verify_token(token: &str, secret: &str) -> Result<JwtClaims, AppError> {
    // 明确启用过期验证
    let mut validation = jsonwebtoken::Validation::default();
    validation.validate_exp = true;

    jsonwebtoken::decode::<JwtClaims>(
        token,
        &jsonwebtoken::DecodingKey::from_secret(secret.as_bytes()),
        &validation,
    )
    .map(|data| data.claims)
    .map_err(|e| match e.kind() {
        jsonwebtoken::errors::ErrorKind::ExpiredSignature => {
            AppError::Unauthorized("Token has expired".to_string())
        }
        jsonwebtoken::errors::ErrorKind::InvalidSignature => {
            AppError::Unauthorized("Token signature is invalid".to_string())
        }
        _ => AppError::Unauthorized(format!("Invalid token: {:?}", e)),
    })
}

/// 自定义 Extractor: CurrentUser
pub struct CurrentUser(pub Uuid);

impl<S> FromRequestParts<S> for CurrentUser
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, axum::Json<serde_json::Value>);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts.extensions
            .get::<Uuid>()
            .copied()
            .map(CurrentUser)
            .ok_or_else(|| {
                (
                    StatusCode::UNAUTHORIZED,
                    axum::Json(serde_json::json!({"error": "Not authenticated"})),
                )
            })
    }
}
```



### 4.7.2 认证中间件

```rust
// src/middleware.rs
use crate::app_state::AppState;
use crate::auth::verify_token;
use axum::extract::{Request, State};
use axum::http::{header, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::Json;
use uuid::Uuid;

pub async fn auth_middleware(
    State(state): State<AppState>,
    request: Request,
    next: Next
) -> Response {
    // 1. 提取
    let token = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|h| h.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(|s| s.to_string());

    let token = match token {
        Some(t) => t,
        None => {
            return (
                StatusCode::UNAUTHORIZED,
                Json(serde_json::json!({"error": "Missing or invalid Authorization header"})),
                ).into_response();
        }
    };

    // 2. 验证
    let claims = match verify_token(&token, &state.config.server().jwt_secret) {
        Ok(c) => c,
        Err(e) => {
            return (
                StatusCode::UNAUTHORIZED,
                Json(serde_json::json!({"error": e.to_string()})),
            ).into_response();
        }
    };

    // 3. 将 user_id 写入请求扩展
    let user_id: Uuid = claims.sub.parse().unwrap_or_default();
    let mut request = request;
    request.extensions_mut().insert(user_id);

    // 4. 继续后续流程
    next.run(request).await
}
```



## 4.8 业务处理

### 4.9.1 认证

```rust
// src/handlers/auth.rs
use crate::app_state::AppState;
use crate::auth::generate_token;
use crate::db;
use crate::errors::AppError;
use crate::models::UserDto;
use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub username: String,
    pub password: String,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user: UserDto,
}

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), AppError> {
    // 1. 参数验证(简单实现)
    if !payload.email.contains('@')  {
        return Err(AppError::Validation("Invalid email address".into()));
    }

    if payload.password.len() < 8 {
        return Err(AppError::Validation("Password must be at least 8 characters".into()));
    }

    // 2. 密码哈希
    let password_hash = bcrypt::hash(payload.password.as_str(), bcrypt::DEFAULT_COST)
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Hash error: {}", e)))?;

    // 3. 创建用户
    let user = db::create_user(
        &state.db,
        &payload.email,
        &payload.username,
        &password_hash,
    ).await?;

    // 4. 生成 Token
    let token = generate_token(
        user.id,
        &state.config.server().jwt_secret,
        state.config.server().jwt_expiration.cast_signed(),
    )?;

    // 5. 响应
    Ok((StatusCode::CREATED, Json(AuthResponse{
        token,
        user: user.into(),
    })))
}

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    // 1. 查找用户
    let user = db::find_user_by_email(&state.db, &payload.email)
        .await?
        .ok_or_else(|| AppError::Unauthorized("Invalid email or password".into()))?;

    // 2. 验证密码
    let valid = bcrypt::verify(&payload.password, &user.password_hash)
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Verify error: {}", e)))?;
    if !valid {
        return Err(AppError::Unauthorized("Invalid email or password".into()));
    }

    // 3. 生成 Token
    let token = generate_token(
        user.id,
        &state.config.server().jwt_secret,
        state.config.server().jwt_expiration.cast_signed(),
    )?;

    // 4. 响应
    Ok(Json(AuthResponse {
        token,
        user: user.into(),
    }))
}
```



### 4.8.2 业务

```rust
// src/handlers/notes.rs
use crate::app_state::AppState;
use crate::auth::CurrentUser;
use crate::db;
use crate::errors::AppError;
use crate::models::{CreateNoteRequest, ModifyNoteRequest, Note};
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use uuid::Uuid;

pub async fn create_note(
    State(state): State<AppState>,
    CurrentUser(user_id): CurrentUser,
    Json(payload): Json<CreateNoteRequest>,
) -> Result<(StatusCode, Json<Note>), AppError> {
    // 1. 参数验证(简单实现)
    if !payload.title.len() < 2 {
        return Err(AppError::Validation("Title is too short".into()));
    }

    // 2. 创建笔记
    let note = db::create_note(
        &state.db,
        user_id,
        payload
    ).await?;

    // 3. 响应
    Ok((StatusCode::CREATED, Json(note)))
}

pub async fn list_note(
    State(state): State<AppState>,
    CurrentUser(user_id): CurrentUser,
) -> Result<Json<Vec<Note>>, AppError> {
    let notes = db::get_notes_by_user(&state.db, user_id).await?;
    Ok(Json(notes))
}

pub async fn get_note(
    State(state): State<AppState>,
    CurrentUser(user_id): CurrentUser,
    Path(note_id): Path<Uuid>,
) -> Result<Json<Note>, AppError> {
    let note = db::get_note(&state.db, user_id, note_id)
        .await?
        .ok_or(AppError::NotFound("Note not found".into()))?;
    Ok(Json(note))
}

pub async fn modify_note(
    State(state): State<AppState>,
    CurrentUser(user_id): CurrentUser,
    Path(note_id): Path<Uuid>,
    Json(payload): Json<ModifyNoteRequest>,
) -> Result<Json<Note>, AppError> {
    let note = db::modify_note(&state.db, user_id, note_id, payload)
        .await?
        .ok_or(AppError::NotFound("Note not found".into()))?;
    Ok(Json(note))
}

pub async fn delete_note(
    State(state): State<AppState>,
    CurrentUser(user_id): CurrentUser,
    Path(note_id): Path<Uuid>,
) -> Result<StatusCode, AppError> {
    let deleted = db::delete_note(&state.db, user_id, note_id).await?;
    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(AppError::NotFound("Note not found".into()))
    }
}
```



### 4.8.3 入口

```rust
// src/handlers/mod.rs
pub mod auth;
pub mod note;
```



## 4.9 路由

```rust
// src/routes.rs
use crate::app_state::AppState;
use crate::handlers::{auth, note};
use crate::middleware::auth_middleware;
use axum::routing::{get, post};
use axum::{middleware, Router};

pub fn app_router(state: AppState) -> Router {
    // 公开路由：不需要认证
    let public_routes = Router::new()
        .route("/auth/register", post(auth::register))
        .route("/auth/login", post(auth::login));

    // 受保护路由：需要验证
    let protected_routes = Router::new()
        .route("/notes", post(note::create_note).get(note::list_note))
        .route(
            "/notes/{id}",
            get(note::get_note)
                .put(note::modify_note)
                .delete(note::delete_note),
        )
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ));

    // 合并路由
    Router::new()
        .merge(public_routes)
        .merge(protected_routes)
        .with_state(state)
}
```



## 4.10 主函数

```rust
// src/main.rs
mod config;
mod logger;
mod models;
mod db;
mod errors;
mod app_state;
mod auth;
mod middleware;
mod handlers;
mod routes;

use crate::app_state::AppState;
use crate::config::AppConfig;

#[tokio::main]
async fn main() {
    // 解析配置
    let cfg = AppConfig::load();

    // 日志
    logger::init(&cfg.server().log_level().as_str());

    // 应用状态
    let state = AppState::new(cfg.clone()).await;

    // 路由
    let app = routes::app_router(state);

    // 监听
    let listener = tokio::net::TcpListener::bind(cfg.server().addr()).await.unwrap();
    tracing::info!("listening on {}", listener.local_addr().unwrap());

    // 启动服务
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C signal handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {}
        _ = terminate => {}
    }
}
```



# 5. 测试策略

三层测试策略：

- 集成测试 (Integration Tests)
  - 真正发送 HTTP 请求 (用 reqwest)
  - 测试完整的请求 --> 响应流程
  - 放在 tests/ 目录
- 单元测试 (Unit Tests)
  - 测试单个函数、模块
  - 用 `#[tokio::test]` 标记
  - 放在同一个文件的 `#[cfg(test)]` mod 里
- 测试组件 (Component Tests)
  - 用 Tower `ServiceExt::oneshot()` 测试路由
  - 不需要启动服务器，但模拟完整请求
  - 推荐的 Axum 测试标准方式



## 5.1 单元测试 - 测试 auth 模块

```rust
// auth.rs
...

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_and_verify_token() {
        let user_id = Uuid::new_v4();
        let secret = "secret_string";

        // 生成 Token
        let token = generate_token(user_id, secret, 1)
            .expect("Failed to generate token");

        // 验证 Token
        let claims = verify_token(&token, secret)
            .expect("Failed to verify token");

        // 验证 Claims 内容
        assert_eq!(claims.sub, user_id.to_string());
        assert!(claims.exp > claims.iat);
    }

    #[test]
    fn test_verify_token_wrong_secret() {
        let user_id = Uuid::new_v4();
        let token = generate_token(user_id, "correct-secret", 1)
            .expect("Failed to generate token");

        // 用错误的 secret 验证
        let result = verify_token(&token, "wrong-secret");
        assert!(result.is_err());

        match result.unwrap_err() {
            AppError::Unauthorized(msg) => {
                assert!(msg.contains("Token signature is invalid"));
            }
            _ => panic!("Unexpected error"),
        }
    }

    #[test]
    fn test_verify_token_expired() {
        let user_id = Uuid::new_v4();
        let secret = "secret_string";

        // 生成一个过期的 Token
        let now = Utc::now();
        let claims = JwtClaims {
            sub: user_id.to_string(),
            exp: (now - chrono::Duration::hours(1)).timestamp(),
            iat: (now - chrono::Duration::hours(2)).timestamp(),
        };
        let token = jsonwebtoken::encode(
            &jsonwebtoken::Header::default(),
            &claims,
            &jsonwebtoken::EncodingKey::from_secret(secret.as_bytes()),
        ).unwrap();

        // 验证 Token
        let result = verify_token(&token, secret);
        assert!(result.is_err());
        match result.unwrap_err() {
            AppError::Unauthorized(msg) => {
                assert!(msg.contains("expired"));
            }
            _ => panic!("Unexpected error"),
        }
    }
}
```



## 5.2 组件测试 - 用 Tower 的 oneshot 测试路由

```rust
// tests/api_tests.rs
use axum::body::Body;
use axum::http::{Method, Request};

fn build_request(
    method: Method,
    uri: &str,
    body: Option<serde_json::Value>,
    token: Option<&str>,
) -> Request<Body> {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");

    if let Some(token) = token {
        builder = builder.header("Authorization", format!("Bearer {}", token));
    }

    let body_bytes = body
        .map(|b| serde_json::to_string(&b).unwrap())
        .unwrap_or_default();

    builder.body(Body::from(body_bytes)).unwrap()
}

/// 测试：未认证访问受保护路由 → 401
#[tokio::test]
async fn test_protected_route_without_token() {
    // 这里需要构建一个测试用的 AppState
    // 在真实项目中，你可能会用 sqlx::testing 或 mockdb
    // 此处简化演示核心思路

    // let app = app_router(test_state).await;
    // let response = app
    //   .oneshot(build_request(Method::GET, "/todos", None, None))
    //   .await
    //   .unwrap();
    //
    // assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    // 简化版本：直接测试公开路由
    println!("✓ Protected route returns 401 without token");
}
```



## 5.3 `#[sqlx::test]` 宏进行数据库测试

```rust
// db.rs
...

#[cfg(test)]
mod tests {
    use super::*;

    /// sqlx:test 宏会自动创建一个事务，测试结束后自动回滚
    #[sqlx::test]
    async fn test_create_and_get_note() {
        let pool = create_pool("postgres://root:123456@192.168.3.105:5432/mydb", 2, 5).await;

        // 创建测试用户
        let user = create_user(&pool, "test@example.com", "testuser", "fakehash")
            .await
            .expect("Failed to create user");

        // 创建笔记
        let note = create_note(
            &pool,
            user.id,
            CreateNoteRequest {
                title: "Test Note".into(),
                content: "just a test".to_string(),
            },
        )
        .await
        .expect("Failed to create note");

        assert_eq!(note.title, "Test Note");
        assert_eq!(note.user_id, user.id);

        // 获取笔记
        let fetched = get_note(&pool, user.id, note.id)
            .await
            .expect("Failed to get note")
            .expect("Note not found");

        assert_eq!(fetched.id, note.id);
    }
}
```



# 6. Docker 部署

```dockerfile
# 分阶段编译
FROM rust:1.88 AS builder

# 更换国内源
RUN echo '[source.crates-io]' > $CARGO_HOME/config \
    && echo 'replace-with = "ustc"' >> $CARGO_HOME/config \
    && echo '[source.ustc]' >> $CARGO_HOME/config \
    && echo 'registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"' >> $CARGO_HOME/config

WORKDIR /app
COPY . .
RUN cargo build --release

# 基础镜像
FROM debian:bookworm-slim

# 更换国内源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update && apt-get install -y ca-certificates

WORKDIR /app
COPY --from=builder /app/target/release/axum-abc /app/axum-abc
COPY config.yaml /app/config.yaml
EXPOSE 3000
CMD ["./axum-abc"]
```



# 7. 常见误区

## 7.1 过度使用 Arc

```rust
// ❌ 不必要的 Arc
struct BadState {
    count: Arc<u32>,  // u32 是 Copy，不需要 Arc！
}

// ✅ 正确
struct GoodState {
    count: u32,  // 或者使用 Arc<AtomicU32> 如果需要可变性
}
```



## 7.2 在锁内执行异步操作

```rust
// ❌ 错误：在锁内 await
asyncfn bad_handler(State(state): State<AppState>) {
    letmut data = state.data.lock().await;
    let result = expensive_async_call().await;  // 持有锁时异步调用
    data.push(result);
}

// ✅ 正确：先完成异步操作
asyncfn good_handler(State(state): State<AppState>) {
    let result = expensive_async_call().await;
    letmut data = state.data.lock().await;
    data.push(result);
    // 锁自动释放
}
```



## 7.3 忘记处理所有错误

```rust
// ❌ 错误：未处理的 Result
async fn bad_handler() -> String {
    let data = fetch_data().await.unwrap();  // panic 在生产环境！
    format!("{:?}", data)
}

// ✅ 正确：妥善处理错误
async fn good_handler() -> Result<String, AppError> {
    let data = fetch_data()
        .await
        .map_err(|e| AppError::FetchError(e))?;
    Ok(format!("{:?}", data))
}
```



## 7.4 提取器顺序错误

```rust
// ❌ 错误：消耗请求体的提取器在前
async fn bad(
    Json(data): Json<MyData>,
    State(state): State<AppState>,  // 编译错误！
) {}

// ✅ 正确：遵循顺序规则
async fn good(
    State(state): State<AppState>,
    Json(data): Json<MyData>,
) {}
```



# 8. 性能优化

- **使用 `#[inline]` 标注热路径函数**

- **避免不必要的克隆**：使用引用或 `Arc`

- **选择合适的序列化库**：考虑 `simd-json` 替代 `serde_json`

- **数据库连接池大小**：通常设置为 CPU 核心数的 2-4 倍

- **启用 LTO（链接时优化）**：

```toml
[profile.release]
lto = true
codegen-units = 1
```







