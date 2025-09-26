# 1. 准备

## 1.1 依赖

```toml
[dependencies]
hyper = { version = "1", features = ["full"] }
tokio = { version = "1", features = ["full"] }
http-body-util = "0.1"
hyper-util = { version = "0.1", features = ["full"] }
```



## 1.2 Runtime

hyper 1.0 移除了默认的 `tokio` 运行时，改用 `hyper::rt` 运行时特征。如果要继续使用 `tokio`，`hyper-util` crate 提供了 `tokio` 的 `hyper-rt` 实现。



 ### 1.2.1 构建自己的 `tokio` 的 `hyper::rt` 实现

定义执行器：

```rust
// Future executor that utilises `tokio` threads
#[non_exhaustive]
#[derive(Default, Debug, Clone)]
pub struct TokioExecutor {}
```



实现 `hyper::rt` 特性：

```rust
use hyper::rt::Executor;

impl<Fut> Executor<Fut> for TokioExecutor
where
    Fut: Future + Send + 'static,
    Fut::Output: Send + 'static,
{
    fn execute(&self, fut: Fut) {
        tokio::spawn(fut);
    }
}
```



实现执行器：

```rust
use hyper_util::server::conn::auto;

impl TokioExecutor {
    pub fn new() -> Self {
        Self {}
    }
}

auto::Builder::new(TokioExecutor::new());
```



### 1.2.2 使用 `hyper-util` crate

```rust
use hyper::rt::Executor;
use hyper_util::rt::TokioExecutor;
use hyper_util::server::conn::auto;

auto::Builder::new(TokioExecutor::new());
```



# 2. 服务端

## 2.1 简单服务器

```rust
use http_body_util::Full;
use hyper::body::Bytes;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::net::SocketAddr;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

    let listener = TcpListener::bind(&addr).await?;
    println!("Listening on: {}", addr);

    loop {
        let (stream, _) = listener.accept().await?;

        // 将 tokio::io trait 转换成 hyper::rt IO trait
        let io = TokioIo::new(stream);

        tokio::task::spawn(async move {
            if let Err(err) = http1::Builder::new()
                .serve_connection(io, service_fn(hello))
                .await
            {
                eprintln!("http1 error: {:?}", err);
            }
        });
    }
}

// 定义服务
async fn hello(_: Request<hyper::body::Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello world!"))))
}
```



## 2.2 Echo 服务器

```rust
use std::net::SocketAddr;
use http_body_util::combinators::BoxBody;
use http_body_util::{BodyExt, Empty, Full};
use hyper::{Method, Request, Response, StatusCode};
use hyper::body::{Body, Bytes, Frame};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr = SocketAddr::from(([127,0,0,1], 3000));
    let listener = TcpListener::bind(addr).await?;
    println!("Listening on: {}", addr);

    loop {
        let (stream, addr) = listener.accept().await?;
        println!("Accepted connection from: {}", addr);

        let io = TokioIo::new(stream);

        tokio::task::spawn(async move {
            if let Err(e) = http1::Builder::new()
                .serve_connection(io, service_fn(echo))
                .await
            {
                eprintln!("Error: {}", e);
            }
        });
    }
}

async fn echo(
    req: Request<hyper::body::Incoming>,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    match (req.method(), req.uri().path()) {
        (&Method::GET, "/") => Ok(Response::new(full(
            "Try POSTing data to /echo",
        ))),

        // Echo
        (&Method::POST, "/echo") => Ok(Response::new(req.into_body().boxed())),

        // Echo Uppercase
        (&Method::POST, "/echo/uppercase") => {
            // 通过数据帧解析请求体
            let frame_stream = req.into_body().map_frame(|frame| {
                let frame = if let Ok(data) = frame.into_data() {
                    data.iter()
                        .map(|byte| byte.to_ascii_uppercase())
                        .collect::<Bytes>()
                } else {
                    Bytes::new()
                };

                Frame::data(frame)
            });

            Ok(Response::new(frame_stream.boxed()))
        },

        (&Method::POST, "/echo/reversed") => {
            let upper = req.body().size_hint().upper().unwrap_or(u64::MAX);
            if upper > 1024 * 64 {
                let mut resp = Response::new(full("Body too big!"));
                *resp.status_mut() = StatusCode::PAYLOAD_TOO_LARGE;
                return Ok(resp);
            }

            // 将整个消息体读入缓冲中
            let whole_body = req.collect().await?.to_bytes();
            let reversed_body = whole_body.iter()
                .rev()
                .cloned()
                .collect::<Vec<u8>>();

            Ok(Response::new(full(reversed_body)))
        }

        // Return 404 Not found
        _ => {
            let mut not_found = Response::new(empty());
            *not_found.status_mut() = StatusCode::NOT_FOUND;
            Ok(not_found)
        },
    }
}

fn full<T: Into<Bytes>>(chunk: T) -> BoxBody<Bytes, hyper::Error> {
    Full::new(chunk.into())
        .map_err(|never | match never {  })
        .boxed()
}

fn empty() -> BoxBody<Bytes, hyper::Error> {
    Empty::<Bytes>::new()
        .map_err(|never| match never {})
        .boxed()
}
```



## 2.3 中间件

### 2.3.1 通过 hyper `Service` trait 实现

定义中间件：

```rust
// logger.rs
use hyper::body::Incoming;
use hyper::Request;
use hyper::service::Service;

#[derive(Debug, Clone)]
pub struct Logger<S> {
    inner: S,
}

impl<S> Logger<S> {
    pub fn new(inner: S) -> Self {
        Self { inner }
    }
}

type Req = Request<Incoming>;

impl<S> Service<Req> for Logger<S>
where
    S: Service<Req>,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = S::Future;

    fn call(&self, req: Req) -> Self::Future {
        println!("processing request: {} {}", req.method(), req.uri().path());
        self.inner.call(req)
    }
}
```

使用中间件：

```rust
use std::convert::Infallible;
use std::net::SocketAddr;
use http_body_util::Full;
use hyper::body::{Bytes, Incoming};
use hyper::{Request, Response};
use hyper::server::conn::http1;
use hyper_util::rt::TokioIo;
use tokio::net::TcpListener;

mod logger;

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        let io = TokioIo::new(stream);
        tokio::task::spawn(async move {
            // 引入service
            let svc = hyper::service::service_fn(hello);

            // 使用中间件
            let svc = tower::ServiceBuilder::new().layer_fn(logger::Logger::new).service(svc);
            if let Err(e) = http1::Builder::new()
                .serve_connection(io, svc)
                .await
            {
                eprintln!("http1 error: {}", e);
            }
        });
    }
}

async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello world!"))))
}
```



### 2.3.2 通过hyper `TowerToHyperService` trait 实现

通过 `hyper_util::service::TowerToHyperService` trait 适配器将 tower Service 转换成 hyper Service.

定义中间件：

```rust
// tower_logger.rs
use std::task::{Context, Poll};
use hyper::body::Incoming;
use hyper::Request;
use tower::Service;

#[derive(Debug, Clone)]
pub struct Logger<S> {
    inner: S,
}

impl<S> Logger<S> {
    pub fn new(inner: S) -> Self {
        Logger { inner }
    }
}

type Req = Request<Incoming>;

impl<S> Service<Req> for Logger<S>
where
    S: Service<Req> + Clone,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = S::Future;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Req) -> Self::Future {
        println!("processing request: {} {}", req.method(), req.uri().path());
        self.inner.call(req)
    }
}
```



使用中间件：

```rust
use std::convert::Infallible;
use std::net::SocketAddr;
use http_body_util::Full;
use hyper::body::{Bytes, Incoming};
use hyper::{Request, Response};
use hyper::server::conn::http1;
use hyper_util::rt::TokioIo;
use hyper_util::service::TowerToHyperService;
use tokio::net::TcpListener;

// mod logger;
mod tower_logger;

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        let io = TokioIo::new(stream);
        tokio::task::spawn(async move {
            // tower service
            let svc = tower::service_fn(hello);

            // 添加中间件
            let svc = tower::ServiceBuilder::new().layer_fn(tower_logger::Logger::new).service(svc);

            // 将 tower service 转化成 hyper service
            let svc = TowerToHyperService::new(svc);

            if let Err(e) = http1::Builder::new()
                .serve_connection(io, svc)
                .await
            {
                eprintln!("http1 error: {}", e);
            }
        });
    }
}

async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    Ok(Response::new(Full::new(Bytes::from("Hello world!"))))
}
```



## 2.4 优雅地关闭服务

### 2.4.1 探测关闭信号

通过 `CTRL+C` 退出

```rust
async fn shutdown_signal() {
    // Wait for the CTRL+C signal
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install CTRL+C signal handler");
}
```



### 2.4.2 改造服务

```rust
use http_body_util::Full;
use hyper::body::{Bytes, Incoming};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::net::SocketAddr;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();
    println!("Listening on: {}", addr);

    let http = http1::Builder::new();
    let graceful = hyper_util::server::graceful::GracefulShutdown::new();
    let mut signal = std::pin::pin!(shutdown_signal());

    loop {
        tokio::select! {
            Ok((stream, _)) = listener.accept() => {
                let io = TokioIo::new(stream);
                let conn = http.serve_connection(io, service_fn(hello));

                let fut = graceful.watch(conn);
                tokio::task::spawn(async move {
                    if let Err(e) = fut.await {
                        eprintln!("http connection error: {}", e);
                    }
                });
            },

            _ = &mut signal => {
                drop(listener);
                eprintln!("gracefully shutdown signal received");
                break;
            }
        }
    }

    tokio::select! {
        _ = graceful.shutdown() => {
            eprintln!("all connections gracefully closed");
        },
        _ = tokio::time::sleep(std::time::Duration::from_secs(10)) => {
            eprintln!("timed out wait for all connections to close");
        },
    }
}

async fn hello(_: Request<Incoming>) -> Result<Response<Full<Bytes>>, Infallible> {
    println!("waiting for 5 seconds");
    tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    Ok(Response::new(Full::from("Hello world!")))
}
```









































