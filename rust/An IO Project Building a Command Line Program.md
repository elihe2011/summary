# 10. An I/O Project: Building a Command Line Program

## 10.1 Accepting Command Line Arguments

```bash
$ cargo new minigrep
$ cd minigrep
$ cargo run -- searchstring example-filename.txt
```



### 10.1.1 Reading the Argument Values

```rust
use std::env;

fn main() {
    // collecting the command line arguments into a vector
    let args: Vec<String> = env::args().collect();
    dbg!(args);
}
```

Note that `std::env::args` will panic if any argument contains invalid Unicode. If your program needs to accept arguments containing invalid Unicode, use `std::env::args_os` instead. That function returns an iterator that produces `OsString` values instead of `String` valeus.

To run it:

```bash
$ cargo run -- abc xyz
   Compiling minigrep v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\17-io\minigrep)
    Finished dev [unoptimized + debuginfo] target(s) in 0.92s
     Running `target\debug\minigrep.exe abc xyz`
[src\main.rs:5] args = [
    "target\\debug\\minigrep.exe",
    "abc",
    "xyz",
]
```



### 10.1.2 Saving the Argument Values in Variables

```rust
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let query = &args[1];
    let file_path = &args[2];
    
    println!("Searching for {query}");
    println!("In file: {file_path}");
}
```



## 10.2 Read a File

```rust
use std::{env, fs};

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let query = &args[1];
    let file_path = &args[2];
    
    println!("Searching for {query}");
    println!("In file: {file_path}");
    
    // read a file
    let contents = fs::read_to_string(file_path).expect("Should have been able to read the file");
    println!("With text:\n{contents}");
}
```



## 10.3 Refactoring to Improve Modularity and Error Handling

### 10.3.1 Separation of Concerns for Binary Projects

```rust
use std::{env, fs, process};
use std::error::Error;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let config = Config::build(&args).unwrap_or_else(|err| {
        println!("Problem parsing arguments: {err}");
        process::exit(1);
    });
    
    println!("Searching for {}", config.query);
    println!("In file: {}", config.file_path);
    
    if let Err(e) = run(config) {
        println!("Application error: {e}");
        process::exit(1);
    }
}

fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(config.file_path)?;
    println!("With text:\n{contents}");
    
    Ok(())
}

struct Config {
    query: String,
    file_path: String,
}

impl Config {
    fn build(args: &[String]) -> Result<Config, &'static str> {
        if args.len() < 3 {
            return Err("not enough arguments");
        }
        
        let query = args[1].clone();
        let file_path = args[2].clone();
    
        Ok(Config { query, file_path })
    } 
}
```

Key points:

- `args[1].clone()`: using clone to fix ownership problems, but its runtime cost is high, and avoid using it when the objects are very large.
- `fn build(args: &[String]) -> Result<Config, &'static str>`:  return a `Result` value that contains a `Config` instance in the successful case and describes the problem in the error case. And go to change the function name from `new` to `build` because many programmers expect `new` functions to never fail.
- `Config::build(&args).unwrap_or_else(|err| {`: pass the inner value of the `Err`
- `Result<(), Box<dyn Error>>`: the trait object `Box<dyn Error>` means the function will return a type that implements the `Error` trait, but we don't have to specify what particular type the return value will be. This gives us flexibility to return error values that may be of different types in different error cases.



### 10.3.2 Splitting Code into a Library Crate

Filename: `src/lib.rs`

```rust
use std::fs;
use std::error::Error;

pub struct Config {
    pub query: String,
    pub file_path: String,
}

impl Config {
    pub fn build(args: &[String]) -> Result<Config, &'static str> {
        if args.len() < 3 {
            return Err("not enough arguments");
        }
        
        let query = args[1].clone();
        let file_path = args[2].clone();
    
        Ok(Config { query, file_path })
    } 
}

pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(config.file_path)?;
    println!("With text:\n{contents}");
    
    Ok(())
}
```



Filename: `src/main.rs`

```rust
use std::{env, process};
use minigrep;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let config = minigrep::Config::build(&args).unwrap_or_else(|err| {
        println!("Problem parsing arguments: {err}");
        process::exit(1);
    });
    
    println!("Searching for {}", config.query);
    println!("In file: {}", config.file_path);
    
    if let Err(e) = minigrep::run(config) {
        println!("Application error: {e}");
        process::exit(1);
    }
}
```



## 10.4 Developing the Library's Functionality with Test Driven Development

Use the test-driven development (TDD) process with the following steps:

- Write a test that fails and run it to make sure it fails for the reason you expect.
- Write or modify just enough code to make the new test pass
- Refactor the code you just added or changed and make sure the tests continue to pass
- Repeat from step 1



### 10.4.1 Writing a Failing Test

Filename: `src/lib.rs`, add a `test` module

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn one_result() {
        let query = "duct";
        let contents = "\
Rust:
safe, fast, productive.
Pick three.";
    
        assert_eq!(vec!["safe, fast, productive."], search(query, contents));
    }
}
```



Filename: `src/lib.rs`, add a definition of the `search` function that always returns an empty vector.

```rust
pub fn search<'a>(query: &str, contents: &'a str) -> Vec<&'a str> {
    vec![]
}
```



### 10.4.2 Writing Code to Pass the Test

```rust
pub fn search<'a>(query: &str, contents: &'a str) -> Vec<&'a str> {
    let mut result = Vec::new();
    
    for line in contents.lines() {
        if line.contains(query) {
            result.push(line);
        }
    }
    
    result
}
```



### 10.4.3 Using the search Function in the `run` Function

Filename: `src/lib.rs`

```rust
pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(config.file_path)?;
    //println!("With text:\n{contents}");
    
    for line search(&config.query, &contents) {
        println!("{line}");
    }
    
    Ok(())
}
```

To run test:

```bash
$ cargo run -- us poem.txt
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
     Running `target\debug\minigrep.exe us poem.txt`
Searching for us
In file: poem.txt
Then there's a pair of us - don't tell!
They'd banish us, you know.
```



## 10.5 Working with Environment Variables

### 10.5.1 Writing a Failing Test for the Case-Insensitive `search` function

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn case_sensitive() {
        let query = "duct";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Duct tap.";
    
        assert_eq!(vec!["safe, fast, productive."], search(query, contents));
    }
    
    #[test]
    fn case_insensitive() {
        let query = "rUsT";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Trust me.";
    
        assert_eq!(
            vec!["Rust:", "Trust me."], 
            search_case_insensitive(query, contents)
        );
    }
}
```



### 10.5.2 Implementing the `search_case_insensitive` Function

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn case_sensitive() {
        let query = "duct";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Duct tap.";
    
        assert_eq!(vec!["safe, fast, productive."], search(query, contents));
    }
    
    #[test]
    fn case_insensitive() {
        let query = "rUsT";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Trust me.";
    
        assert_eq!(
            vec!["Rust:", "Trust me."], 
            search_case_insensitive(query, contents)
        );
    }
}
```



### 10.5.3 Using the Environment Variables

```rust
use std::env;
use std::fs;
use std::error::Error;

pub struct Config {
    pub query: String,
    pub file_path: String,
    pub ignore_case: bool,
}

impl Config {
    pub fn build(args: &[String]) -> Result<Config, &'static str> {
        if args.len() < 3 {
            return Err("not enough arguments");
        }
        
        let query = args[1].clone();
        let file_path = args[2].clone();
        
        let ignore_case = env::var("IGNORE_CASE").is_ok();
    
        Ok(Config { query, file_path, ignore_case })
    } 
}

pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(config.file_path)?;
    
    let results = if config.ignore_case {
        search_case_insensitive(&config.query, &contents)
    } else {
        search(&config.query, &contents)
    };
    
    for line in results {
        println!("{line}");
    }
    
    Ok(())
}

pub fn search<'a>(query: &str, contents: &'a str) -> Vec<&'a str> {
    let mut result = Vec::new();
    
    for line in contents.lines() {
        if line.contains(query) {
            result.push(line);
        }
    }
    
    result
}

pub fn search_case_insensitive<'a>(query: &str, contents: &'a str) -> Vec<&'a str> {
    let query = query.to_lowercase();
    let mut results = Vec::new();
    
    for line in contents.lines() {
        if line.to_lowercase().contains(&query) {
            results.push(line);
        }
    }
    
    results
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn case_sensitive() {
        let query = "duct";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Duct tap.";
    
        assert_eq!(vec!["safe, fast, productive."], search(query, contents));
    }
    
    #[test]
    fn case_insensitive() {
        let query = "rUsT";
        let contents = "\
Rust:
safe, fast, productive.
Pick three
Trust me.";
    
        assert_eq!(
            vec!["Rust:", "Trust me."], 
            search_case_insensitive(query, contents)
        );
    }
}
```

To run it:

```bash
$ cargo run -- to poem.txt
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
     Running `target\debug\minigrep.exe to poem.txt`
Searching for to
In file: poem.txt
Are you nobody, too?
How dreary to be somebody!

$ IGNORE_CASE=1 cargo run -- to poem.txt
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
     Running `target\debug\minigrep.exe to poem.txt`
Searching for to
In file: poem.txt
Are you nobody, too?
How dreary to be somebody!
To tell your name the livelong day
To an admiring bog!
```



## 10.6 Writing Error Messages to Standard Error Instead of Standard Output

using the `eprintln!` macro that prints to the standard error stream.

```rust
use std::{env, process};
use minigrep;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let config = minigrep::Config::build(&args).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });
    
    if let Err(e) = minigrep::run(config) {
        eprintln!("Application error: {e}");
        process::exit(1);
    }
}
```

To run it:

```bash
$ cargo run -- to poem2.txt > output.txt
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
     Running `target\debug\minigrep.exe to poem2.txt`
Application error: The system cannot find the file specified. (os error 2)
error: process didn't exit successfully: `target\debug\minigrep.exe to poem2.txt` (exit code: 1)

$ cat output.txt
```









































































