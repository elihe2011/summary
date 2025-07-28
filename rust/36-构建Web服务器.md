# 1. 单线程版

## 1.1 请求及应答

```rust
use std::io::{prelude::*, BufReader};
use std::net::{TcpListener, TcpStream};

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        
        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&mut stream);
    let http_request: Vec<_> = buf_reader
        .lines()
        .map(|result| result.unwrap())
        .take_while(|line| !line.is_empty())
        .collect();
    println!("Request: {:#?}", http_request);
    
    let status_line = "HTTP/1.1 200 OK";
    let contents = "<h1>Hello World!</h1>";
    let length = format!("Content-Length: {}", contents.len());
    
    let response = format!("{status_line}\r\n{length}\r\n\r\n\n{contents}");
    stream.write_all(response.as_bytes()).unwrap();
}
```



## 1.2 验证请求及选择性应答

```rust
fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&mut stream);
    let request_line = buf_reader.lines().next().unwrap().unwrap();
    
    let (status_line, contents) = if request_line.starts_with("GET / HTTP/1.1") {
        ("HTTP/1.1 200 OK", "<h1>Hello World!</h1>")
    } else {
        ("HTTP/1.1 404 Not Found", "<h1>Page not found</h1>")
    };

    let length = format!("Content-Length: {}", contents.len());
    let response = format!("{status_line}\r\n{length}\r\n\r\n\n{contents}");
    stream.write_all(response.as_bytes()).unwrap();
}
```



# 2. 多线程版

## 2.1 单线程模拟慢请求

```rust
fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&mut stream);
    let request_line = buf_reader.lines().next().unwrap().unwrap();
    
    let (status_line, contents) = match &request_line[..] {
        "GET / HTTP/1.1" => ("HTTP/1.1 200 OK", "<h1>Hello</h1>"),
        "GET /sleep HTTP/1.1" => {
            std::thread::sleep(std::time::Duration::from_secs(5));
            ("HTTP/1.1 200 OK", "<h1>Sleep a while</h1>")
        },
        _ => ("HTTP/1.1 404 NOT FOUND", "Page not found"),
    };
    
    let response = format!("{}\r\nContent-Length: {}\r\n\r\n{}", status_line, contents.len(), contents);
    stream.write_all(response.as_bytes()).unwrap();
}
```

**问题**：当调用 sleep 请求时，将阻塞其它请求



## 2.2 线程池改善吞吐

每个请求一个线程：

```rust
fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    
    for stream in listener.incoming() {
        let stream = stream.unwrap();
        
        std::thread::spawn(move || {
            handle_connection(stream);
        });
    }
}
```

**问题**：线程创建和销毁，比较消耗资源



使用线程池，限制线程个数：

```rust
fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    let pool = ThreadPool::new(5);

    for stream in listener.incoming() {
        let stream = stream.unwrap();

        pool.execute(move || {
            handle_connection(stream);
        });
    }
}
```



## 2.3 实现线程池

### 2.3.1 框架

```rust
// 定义线程池
pub struct ThreadPool;

// 实现线程池
impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);
        ThreadPool
    }
    
    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static,
    {
    }
}
```



线程池的 `execute` 方法参数是一个闭包，闭包作为参数时可以由三个特征进行约束：

| Trait    | 特性                 | 适用场景 |
| -------- | -------------------- | ------------ |
| `Fn`     | 只捕获不可变引用     |         |
| `FnMut`  | 捕获可变引用         |        |
| `FnOnce` | 捕获所有权（一次性） |      |

额外说明：
- 所有闭包至少实现 `FnOnce`
- 如果闭包只借用了环境中的不可变引用，它也实现 `Fn` 和 `FnMut`
- 如果闭包借用了可变引用，则实现 `FnMut` 和 `FnOnce`
- 如果闭包获取了变量的所有权（如 move 关键字），只实现 `FnOnce`

`thread::spawn` 方法：

```rust
pub fn spawn<F, T>(f: F) -> JoinHandle<T> {
    where
    	F: FnOnce() -> T,
        F: Send + 'static,
    	T: Send + 'static,
}
```

`spawn` 选择 `FnOnce` 作为 `F` 闭包的特征约束，原因是闭包作为任务只需被线程执行一次即可。



`F` 还有一个特征约束 `Send`，表示它的值可以安全地从一个线程移动到另一个线程：

```rust
pub unsafe auto trait Send {}
```

`Send` 是一个自动 trait，意味着只要类型的所有成员都是 `Send`，那么该类型自动就是 `Send`，除非手动实现或显示声明为非 `Send`



生命周期 `'static`：因为不知道线程需要多久时间来执行该任务，所有使用它



### 2.3.2 存储线程

`thread::spawn` 返回 `JoinHandle<T>`，待实现的任务无需任何返回，因此 `T` 直接使用 `()` 即可

```rust
use std::thread;

pub struct ThreadPool {
    threads: Vec<thread::JoinHandle<()>>,
}

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);

        let mut threads = Vec::with_capacity(size);
        
        for _ in 0..size {
            // create some threads and store them in the vector
        }
        
        ThreadPool { threads }
    }

    // --snip--
}
```



### 2.3.3 任务创建和执行分离

`thread::spawn` 虽然是生成线程最好的方式，但它会立即执行传入的任务。但在实际的使用场景中，创建任务和执行任务是要分离的，因此不能直接使用标准库。

考虑创建一个 `Worker` 结构体，作为 `ThreadPool` 和任务线程联系的桥梁，它的任务是获得将要执行的代码，然后再具体的线程中去执行。

```rust
pub struct ThreadPool {
    workers: Vec<Worker>,
}

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);

        let mut workers = Vec::with_capacity(size);

        for id in 0..size {
            workers.push(Worker::new(id));
        }

        ThreadPool { workers }
    }
    
    // --snip--
}

struct Worker {
    id: usize,
    thread: thread::JoinHandle<()>,
}

impl Worker {
    fn new(id: usize) -> Worker {
        // 待实现
        let thread = thread::spawn(|| {})

        Worker{id, thread}
    }
}
```



### 2.3.4 将请求发送给线程

`Worker` 中的 `thread::spawn(|| {})` 未给予实质的任务内容，它需要从线程池的队列中获取待执行的代码。可以使用消息通道(channel)作为任务队列

```rust
use std::sync::mpsc;
use std::thread;

pub struct ThreadPool {
    workers: Vec<Worker>,
    sender: mpsc::Sender<Job>,
}

struct Job {}

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);
        
        let (sender, receiver) = mpsc::channel();

        let mut workers = Vec::with_capacity(size);

        for id in 0..size {
            workers.push(Worker::new(id, receiver));
        }

        ThreadPool { workers, sender }
    }

    // --snip--
}

// --snip--
impl Worker {
    fn new(id: usize, receiver: mpsc::Receiver<Job>) -> Worker {
        let thread = thread::spawn(|| {
           receiver;
        });

        Worker { id, thread }
    }
}
```

**问题**：

```
error[E0382]: use of moved value: `receiver`                                                                                                                                                                                       
  --> .\thread-pool\src\lib.rs:20:42
   |
15 |         let (sender, receiver) = mpsc::channel();
   |                      -------- move occurs because `receiver` has type `std::sync::mpsc::Receiver<Job>`, which does not implement the `Copy` trait
...
19 |         for id in 0..size {
   |         ----------------- inside of this loop
20 |             workers.push(Worker::new(id, receiver));
   |                                          ^^^^^^^^ value moved here, in previous iteration of loop
```

`receiver` 未实现 `Copy`，它的所有权在第一次循环中，被传入到第一个 `Worker` 实例中，后续自然无法再使用。

就算 `receiver` 可以克隆，但也得保证同一时间只有一个 `receiver` 能接收消息，否则一个任务可能同时被多个 `Worker` 执行。

多线程需要安全的共享和使用 `receiver`，这里可以使用 `Arc<Mutex<T>>`这个线程安全的类型：

- `Arc` 允许多个 `Worker` 同时持有 `receiver`
- `Mutex` 可以确保一次只有一个 `Worker` 能从 `receiver` 接收消息

```rust
// --snip--

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);
        
        let (sender, receiver) = mpsc::channel();
        let receiver = Arc::new(Mutex::new(receiver));

        let mut workers = Vec::with_capacity(size);

        for id in 0..size {
            workers.push(Worker::new(id, Arc::clone(&receiver)));
        }

        ThreadPool { workers, sender }
    }

    // --snip--
}

// --snip--
impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        let thread = thread::spawn(|| {
           receiver;
        });

        Worker { id, thread }
    }
}
```



### 2.3.5 实现 execute 方法

```rust
// --snip--

type Job = Box<dyn FnOnce() + Send + 'static>;

impl ThreadPool {
    // --snip--
    
    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static
    {
        let job = Box::new(f);
        self.sender.send(job).unwrap();
    }
}
```



# 3. 优雅关闭和资源清理

## 3.1 线程池实现 Drop

当线程池被 drop 时，需要等待所有的子线程完成它们的工作，然后再退出

```rust
impl Drop for ThreadPool {
    fn drop(&mut self) {
        for worker in &mut self.workers {
            println!("Shutting down worker {}", worker.id);
            
            worker.thread.join().unwrap();
        }
    }
}
```

编译报错：

```
error[E0507]: cannot move out of `worker.thread` which is behind a mutable reference                                                                                                                                               
    -->.\thread-pool\src\lib.rs:41:13
     |
41   |             worker.thread.join().unwrap();
     |             ^^^^^^^^^^^^^ ------ `worker.thread` moved due to this method call
     |             |
     |             move occurs because `worker.thread` has type `JoinHandle<()>`, which does not implement the `Copy` trait
```

`worker.thread` 试图拿走所有权，但 `worker` 仅仅时一个可变借用。

可以使用 `Option` 类型包装，然后通过 `take` 方法拿走内部值得所有权：

```rust
struct Worker {
    id: usize,
    thread: Option<thread::JoinHandle<()>>,
}

impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        // --snip--

        Worker { 
            id,  
            thread: Some(thread), 
        }
    }
}

impl Drop for ThreadPool {
    fn drop(&mut self) {
        for worker in &mut self.workers {
            // --snip--
            
            if let Some(thread) = worker.thread.take() {
                thread.join().unwrap();
            }
        }
    }
}
```



## 3.2 停止工作线程

虽然调用了 `join`，但目标线程依然不会停止，原因在于它们在无限 `loop` 循环中等待。需要借用 `channel` 的 `drop` 机制：释放 `sender` 发送端后，`receiver` 接收端会收到报错，然后再退出即可

```rust
pub struct ThreadPool {
    workers: Vec<Worker>,
    sender: Option<mpsc::Sender<Job>>,
}

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        // --snip--

        ThreadPool { 
            workers, 
            sender: Some(sender),
        }
    }

    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static
    {
        let job = Box::new(f);
        self.sender.as_ref().unwrap().send(job).unwrap();
    }
}

impl Drop for ThreadPool {
    fn drop(&mut self) {
        drop(self.sender.take());
        
        // --snip--
    }
}
```

修改点：

- 为 `sender` 增加 `Option` 封装，这样可以用 `take` 拿走所有权，跟之前的 `thread` 一样
- 主动调用 `drop` 关闭发送端 `sender`



关闭 `sender` 后，将关闭对应的 `channel`，意味着不会再有任何消息被发送。随后，所有处于无限 `loop` 的接收端将收到一个错误，然后根据错误进一步处理：

```rust
// --snip--
impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        let thread = thread::spawn(move || loop {
            let message = receiver.lock().unwrap().recv();
            
            match message {
                Ok(job) => {
                    println!("Worker {} got a job; executing.", id);
                    job();
                }
                Err(_) => {
                    println!("Worker {} disconnected, shutting down.", id);
                    break;
                }
            }
        });

        Worker { 
            id,  
            thread: Some(thread), 
        }
    }
}
```



为验证代码是否正确，在 main 函数中修改，限制只能请求两次：

```rust
fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    let pool = ThreadPool::new(5);

    for stream in listener.incoming().take(2) {
        let stream = stream.unwrap();

        pool.execute(move || {
            handle_connection(stream);
        });
    }
    
    println!("Shutting down.");
}
```



## 3.3 完整代码

`src/lib.rs`

```rust
use std::sync::{Arc, Mutex, mpsc};
use std::thread;

pub struct ThreadPool {
    workers: Vec<Worker>,
    sender: Option<mpsc::Sender<Job>>,
}

type Job = Box<dyn FnOnce() + Send + 'static>;

impl ThreadPool {
    pub fn new(size: usize) -> ThreadPool {
        assert!(size > 0);
        
        let (sender, receiver) = mpsc::channel();
        let receiver = Arc::new(Mutex::new(receiver));

        let mut workers = Vec::with_capacity(size);

        for id in 0..size {
            workers.push(Worker::new(id, Arc::clone(&receiver)));
        }

        ThreadPool { 
            workers, 
            sender: Some(sender),
        }
    }

    pub fn execute<F>(&self, f: F)
    where
        F: FnOnce() + Send + 'static
    {
        let job = Box::new(f);
        self.sender.as_ref().unwrap().send(job).unwrap();
    }
}

impl Drop for ThreadPool {
    fn drop(&mut self) {
        drop(self.sender.take());
        
        for worker in &mut self.workers {
            println!("Shutting down worker {}", worker.id);
            
            if let Some(thread) = worker.thread.take() {
                thread.join().unwrap();
            }
        }
    }
}

struct Worker {
    id: usize,
    thread: Option<thread::JoinHandle<()>>,
}

impl Worker {
    fn new(id: usize, receiver: Arc<Mutex<mpsc::Receiver<Job>>>) -> Worker {
        let thread = thread::spawn(move || loop {
            let message = receiver.lock().unwrap().recv();
            
            match message {
                Ok(job) => {
                    println!("Worker {} got a job; executing.", id);
                    job();
                }
                Err(_) => {
                    println!("Worker {} disconnected, shutting down.", id);
                    break;
                }
            }
        });

        Worker { 
            id,  
            thread: Some(thread), 
        }
    }
}
```



`src/main.rs`

```rust
use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use thread_pool::ThreadPool;

fn main() {
    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    let pool = ThreadPool::new(5);

    for stream in listener.incoming().take(2) {
        let stream = stream.unwrap();

        pool.execute(move || {
            handle_connection(stream);
        });
    }
    
    println!("Shutting down.");
}

fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&mut stream);
    let request_line = buf_reader.lines().next().unwrap().unwrap();

    let (status_line, contents) = match &request_line[..] {
        "GET / HTTP/1.1" => ("HTTP/1.1 200 OK", "<h1>Hello</h1>"),
        "GET /sleep HTTP/1.1" => {
            std::thread::sleep(std::time::Duration::from_secs(5));
            ("HTTP/1.1 200 OK", "<h1>Sleep a while</h1>")
        },
        _ => ("HTTP/1.1 404 NOT FOUND", "Page not found"),
    };

    let response = format!("{}\r\nContent-Length: {}\r\n\r\n{}", status_line, contents.len(), contents);
    stream.write_all(response.as_bytes()).unwrap();
}
```























































