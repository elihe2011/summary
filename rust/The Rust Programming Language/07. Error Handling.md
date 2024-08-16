# 7. Error Handling

## 7.1 Unrecoverable Errors with `panic!`

There are two ways to cause a panic in practice:

- by taking an action that causes our code to panic (such as accessing an array past the end)
- by explicitly calling the `panic!` macro

By default, these panics will print a failure message, unwind, clean up the stack, and quit.

**Unwinding the Stack or Aborting in Response to a Panic**

By default, when a panic occurs the program starts *unwinding*, which means Rust walks back up the stack and cleans up the data from each function it encounters. However, walking back and cleaning up is a lot of work. Rust, therefore, allows you to choose the alternative of immediately aborting, which ends the program without cleaning up.

If in your project you need to make the resultant binary as small as possible, you can switch from unwinding to aborting upon a panic by adding `panic = 'abort'` to the appropriate `[profile]` sections in your `Cargo.toml` file.

```toml
[profile.release]
panic = 'abort'
```

Filename: `src/main.rs`

```rust
fn main() {
    panic!("crash and burn");
}
```

To run the program:

```bash
$ cargo run
   Compiling b19-painc-abort v0.1.0 (D:\Workspace\gitee.com\elihe\learn-rust\06-error\b19-painc-abort)
    Finished dev [unoptimized + debuginfo] target(s) in 0.67s
     Running `target\debug\b19-painc-abort.exe`
thread 'main' panicked at 'crash and burn', src\main.rs:2:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
error: process didn't exit successfully: `target\debug\b19-painc-abort.exe` (exit code: 101) 
```



Another example, to attempt to access an index in a vector beyond the range of valid indexes:

```rust
fn main() {
    let v = vec![1, 2, 3];

    println!("{}", v[99]);
}
```

To run it:

```bash
$ cargo run
   Compiling b19-painc-abort v0.1.0 (D:\Workspace\gitee.com\elihe\learn-rust\06-error\b19-painc-abort)
    Finished dev [unoptimized + debuginfo] target(s) in 0.33s
     Running `target\debug\b19-painc-abort.exe`
thread 'main' panicked at 'index out of bounds: the len is 3 but the index is 99', src\main.rs:4:20
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
error: process didn't exit successfully: `target\debug\b19-painc-abort.exe` (exit code: 101)
```

To try getting a backtrace by setting the `RUST_BACKTRACE` environment variable to any value except 0:

```bash
$ RUST_BACKTRACE=1 cargo run
    Finished dev [unoptimized + debuginfo] target(s) in 0.01s
     Running `target\debug\b19-painc-abort.exe`
thread 'main' panicked at 'index out of bounds: the len is 3 but the index is 99', src\main.rs:4:20
stack backtrace:
   0: std::panicking::begin_panic_handler
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\std\src\panicking.rs:593
   1: core::panicking::panic_fmt
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\core\src\panicking.rs:67
   2: core::panicking::panic_bounds_check
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\core\src\panicking.rs:162
   3: core::slice::index::impl$2::index<i32>
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26\library\core\src\slice\index.rs:258
   4: alloc::vec::impl$13::index<i32,usize,alloc::alloc::Global>
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26\library\alloc\src\vec\mod.rs:2690
   5: b19_painc_abort::main
             at .\src\main.rs:4
   6: core::ops::function::FnOnce::call_once<void (*)(),tuple$<> >
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26\library\core\src\ops\function.rs:250
note: Some details are omitted, run with `RUST_BACKTRACE=full` for a verbose backtrace.
error: process didn't exit successfully: `target\debug\b19-painc-abort.exe` (exit code: 101)
```

Debug symbols are enabled by default when using `cargo build` or `cargo run` without the `--release` flag, as we have here:

```rust
$ RUST_BACKTRACE=1 cargo run --release
    Finished release [optimized] target(s) in 0.01s
     Running `target\release\b19-painc-abort.exe`
thread 'main' panicked at 'index out of bounds: the len is 3 but the index is 99', src\main.rs:4:20
stack backtrace:
   0: std::panicking::begin_panic_handler
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\std\src\panicking.rs:593
   1: core::panicking::panic_fmt
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\core\src\panicking.rs:67
   2: core::panicking::panic_bounds_check
             at /rustc/eb26296b556cef10fb713a38f3d16b9886080f26/library\core\src\panicking.rs:162
   3: __ImageBase
note: Some details are omitted, run with `RUST_BACKTRACE=full` for a verbose backtrace.
error: process didn't exit successfully: `target\release\b19-painc-abort.exe` (exit code: 0xc0000409, STATUS_STACK_BUFFER_OVERRUN)
```



## 7.2 Recoverable Errors with Result

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

To try to open a file:

```rust
use std::fs::File;
use std::io::Read;

fn main() {
    let greeting_file_result = File::open("a.txt");

    let mut greeting_file = match greeting_file_result {
        Ok(file) => file,
        Err(error) => panic!("failed to open file: {error}"),
    };

    let mut content = String::new();
    let result = greeting_file.read_to_string(&mut content);
    match result {
        Ok(n) => println!("read {n} bytes, content: {content}"),
        Err(e) => println!("failed to read file: {e}"),
    }
}
```



### 7.2.1 Matching on Different Errors

```rust
use std::fs::File;
use std::io::ErrorKind;

fn main() {
    let greeting_file_result = File::open("hello.txt");

    match greeting_file_result {
        Ok(file) => file,
        Err(error) => match error.kind() {
            ErrorKind::NotFound => match File::create("hello.txt") {
                Ok(fc) => fc,
                Err(e) => panic!("Prombles creating the file: {e:?}"),
            },
            other_error => {
                panic!("Probles opening the file: {other_error:?}");
            },
        },
    };
}
```

**Alternatives to Using match with Result<T, E>**

```rust
use std::fs::File;
use std::io::ErrorKind;

fn main() {
    let greeting_file = File::open("hello.txt").unwrap_or_else(|error| {
        if  error.kind() == ErrorKind::NotFound {
            File::create("hello.txt").unwrap_or_else(|error| {
                panic!("Problem creating the file: {error:?}");
            })
        } else {
            panic!("Problem opening the file: {error:?}")
        }
    });
}
```



### 7.2.2 Shortcuts for Panic on Error: unwrap and expect

The `unwrap` method is a shortcut method implemented just like the `match` expression. If the `Result` value is the `Ok` variant, `unwrap` will return the value inside the `Ok`. If the `Result` is the `Err` variant, `unwrap` will call the `panic!` macro.

```rust
use std::fs::File;

fn main() {
    let greet_file = File::open("hello.txt").unwrap();
}
```



The `expect` method lets us also choose the `panic!` error message. Using `expect` instead of `unwrap` and providing good error messages can convey your intent and make tracking down the source of a panic easier.

```rust
use std::fs::File;

fn main() {
    let greeting_file = File::open("hello.txt")
    	.expect("hello.txt should be included in this project");
}
```



### 7.2.3 Propagating Errors

When a function's implementation calls something that might fail, instead of handling the error within the function itself you can return the error to the calling code so that it can decide what to do.

```rust
use std::fs::File;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    let username_file_result = File::open("hello.txt");

    let mut username_file = match username_file_result {
        Ok(file) => file,
        Err(e) => return Err(e),
    };

    let mut username = String::new();

    match username_file.read_to_string(&mut username) {
        Ok(_) => Ok(username),
        Err(e) => Err(e),
    }
}
```



#### 7.2.3.1 A shortcut for Propagating Errors: the `?` Operator

The `?` placed after a `Result` value is defined to work in almost the same way as the `match` expressions we defined t handle the `Result` values.

```rust
use std::fs::File;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    let mut username_file = File::open("hello.txt")?;

    let mut username = String::new();

    username_file.read_to_string(&mut username)?;

    Ok(username)
}
```



The `?` operator eliminates a lot of boilerplate and makes this function's implementation simpler. We could even shorten this code further by chaining method calls immediately after the `?`:

```rust
use std::fs::File;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    let mut username = String::new();
    
    File::open("hello.txt")?.read_to_string(&mut username)?;

    Ok(username)
}
```



To make this even shorter using `fs::read_to_string`

```rust
use std::fs;
use std::io::{self, Read};

fn read_username_from_file() -> Result<String, io::Error> {
    fs::read_to_string("hello.txt")
}
```



#### 7.2.3.2 Where The `?` Operator Can Be Used

The `?` operator can only be used in functions whose return type is compatible with the value the `?` is used on. This is because the `?` operator is defined to perform an early return of a value out of the function.

```rust
fn last_char_of_first_line(text: &str) -> Option<char> {
    text.lines().next()?.chars().last()
}
```



By default, the main functions we've used return `()`. The main function is special because it's the entry point and exit point of an executable program.

Luckily, main can also return a `Result<(), E>`

```rust 
use std::error::Error;
use std::fs::File;

fn main() -> Result<(), Box<dyn Error>> {
    let greeting_fiel = File::open("hello.txt")?;
    
    Ok(())
}
```



The `Box<dyn Error>` type is a trait object, it means "any kind of error". Using `?` on a `Result` value in a main function with the error type `Box<dyn Error>` is allowed because it allows any `Err` value to be returned early.



## 7.3 To `panic!` Not to `panic!`

### 7.3.1 Cases in Which You Have More Information Than the Compiler

```rust
use std::net::IpAddr;

fn main() {
    let loopback: IpAddr = "127.0.0.1"
    	.parse()
    	.expect("Hardcored IP address should be valid");
}
```



### 7.3.2 Creating Custom Types for Validation

```rust
pub struct Guess {
    value: i32,
}

impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 || value > 100 {
            panic!("Guess value must be between 1 and 100, got {value}.");
        }
        
        Guess { value }
    }
    
    pub fn value(&self) -> i32 {
        self.value
    }
}
```













