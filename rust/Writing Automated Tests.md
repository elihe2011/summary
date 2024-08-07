# 9. Writing Automated Tests

## 9.1 How to Write Tests

Tests are Rust functions that verify that the non-test code is functioning in the expected manner. The bodies of test functions typically perform these three actions:

- Set up any needed data or state.
- Run the code you want to test
- Assert the result are what you expect.



### 9.1.1 The Anatomy of a Test Function

To create a new library project called `adder`:

```bash
$ cargo new adder --lib
     Created library `adder` package
$ cd adder
```

Filename: `src/lib.rs`

```rust
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
```

To test the project:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 1.64s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 1 test
test tests::it_works ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

To add a panic test:

```rust
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
    
    #[test]
    fn not_work() {
        panic!("Make this test fail");
    }
}
```

To run test again:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.22s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 2 tests
test tests::it_works ... ok
test tests::not_work ... FAILED

failures:

---- tests::not_work stdout ----
thread 'tests::not_work' panicked at 'Make this test fail', src\lib.rs:17:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::not_work

test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

error: test failed, to rerun pass `--lib`
```



### 9.1.2 Checking Results with the `assert!` Macro

```rust
#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn larger_can_hold_smaller() {
        let larger = Rectangle {
            width: 8,
            height: 7,
        };
        let smaller = Rectangle {
            width: 6,
            height: 4,
        };
        
        assert!(larger.can_hold(&smaller));
    }
}
```



### 9.1.3 Testing Equality with the `assert_eq!` and `assert_ne!` Macros

```rust
fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn it_adds_two() {
        assert_eq!(add_two(2), 4);
        
        assert_ne!(add_two(3), 6);
    }
}
```



### 9.1.4 Adding Custom Failure Messages

```rust
pub fn greeting(name: &str) -> String {
    format!("Hello")
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn greeting_contains_name() {
        let result = greeting("Tom");
        assert!(
            result.contains("Tom"),
            "Greeting did not contain name, value was `{}`",
            result
        );
    }
}
```



### 9.1.5 Checking for Panics with `should_panic`

```rust
pub struct Guess {
    value: i32,
}

impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 || value > 100 {
            panic!("Guess value must be between 1 and 100, got {value}");
        }
        
        Guess { value }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    #[should_panic]
    fn greater_than_100() {
        Guess::new(105);
    }
}
```



To add an optional `expected` parameter to the `should_panic` attribute:

```rust
pub struct Guess {
    value: i32,
}

impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 {
            panic!("Guess value must be greater than or equal to 1, got {value}");
        } else if value > 100 {
            panic!("Guess value must be less than or equal to 100, got {value}");
        }
        
        Guess { value }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    #[should_panic(expected = "less than or equal to 100")]
    fn greater_than_100() {
        Guess::new(105);
    }
}
```



### 9.1.6 Using `Result<T, E>` in Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn it_works() -> Result<(), String> {
        if 2 + 2 == 4 {
            Ok(())
        } else {
            Err(String::from("two plus two does not equal to four"))
        }
    }
}
```

You can’t use the `#[should_panic]` annotation on tests that use `Result<T, E>`. To assert that an operation returns an `Err` variant, *don’t* use the question mark operator on the `Result<T, E>` value. Instead, use `assert!(value.is_err())`.



## 9.2 Controlling How Tests are Run

Command line options:

-  `cargo test --help` : displays the options you can use
-  `cargo test -- --help`: displays the options you can use after the separator. *run test, and print Func-tests & Doc-tests options separately*



### 9.2.1 Running Tests in Parallel or Consecutively

```bash
$ cargo test -- --test-threads=1
```



### 9.2.2 Showing Function Output

By default, if a test passes, Rust's test library captures anything printed to standard output. For example, if we call `println!` in a test and the test passes, we won't see the `println!` output in the terminal; we'll see only the line that indicates the test passes. If a test fails, we'll see whatever was printed to standard output with rest of the failure message.

```rust
pub fn prints_and_returns(a: i32) -> i32 {
    println!("I got the value {a}");
    10
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn this_test_will_pass() {
        let value = prints_and_returns(5);
        assert_eq!(10, value);
    }
    
    #[test]
    fn this_test_will_fail() {
        let value = prints_and_returns(3);
        assert_eq!(3, value);
    }
}
```

To run test:

```bash
$ cargo test
   Compiling silly-function v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\silly-function)
    Finished test [unoptimized + debuginfo] target(s) in 0.36s
     Running unittests src\lib.rs (target\debug\deps\silly_function-b95fe12a7d0040e7.exe)

running 2 tests
test tests::this_test_will_pass ... ok
test tests::this_test_will_fail ... FAILED

failures:

---- tests::this_test_will_fail stdout ----
I got the value 3
thread 'tests::this_test_will_fail' panicked at 'assertion failed: `(left == right)`
  left: `3`,
 right: `10`', src\lib.rs:19:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::this_test_will_fail

test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

error: test failed, to rerun pass `--lib`
```



To show the output of successful tests:

```bash
$ cargo test -- --show-output
    Finished test [unoptimized + debuginfo] target(s) in 0.00s
     Running unittests src\lib.rs (target\debug\deps\silly_function-b95fe12a7d0040e7.exe)

running 2 tests
test tests::this_test_will_fail ... FAILED
test tests::this_test_will_pass ... ok

successes:

---- tests::this_test_will_pass stdout ----
I got the value 5


successes:
    tests::this_test_will_pass

failures:

---- tests::this_test_will_fail stdout ----
I got the value 3
thread 'tests::this_test_will_fail' panicked at 'assertion failed: `(left == right)`
  left: `3`,
 right: `10`', src\lib.rs:19:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::this_test_will_fail

test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

error: test failed, to rerun pass `--lib`
```



### 9.2.3 Running a Subset of Tests by Name

```rust
pub fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn add_two_and_two() {
        assert_eq!(4, add_two(2));
    }
    
    #[test]
    fn add_three_and_two() {
        assert_eq!(5, add_two(3));
    }
    
    #[test]
    fn one_hundred() {
        assert_eq!(102, add_two(100));
    }
}
```



To run all the tests in parallel:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.18s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 3 tests
test tests::add_three_and_two ... ok
test tests::add_two_and_two ... ok
test tests::one_hundred ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```



To run single test:

```bash
$ cargo test one_hundred
    Finished test [unoptimized + debuginfo] target(s) in 0.03s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 1 test
test tests::one_hundred ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 2 filtered out; finished in 0.00s
```



Filtering to run multiple tests:

```bash
$ cargo test add
    Finished test [unoptimized + debuginfo] target(s) in 0.00s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 2 tests
test tests::add_three_and_two ... ok
test tests::add_two_and_two ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s
```



### 9.2.4 Ignoring Some Test Unless Specifically Requested

```rust
#[cfg(test)]
mod tests {    
    #[test]
    fn it_works() {
        assert_eq!(2+2, 4);
    }
    
    #[test]
    #[ignore]
    fn expensive_test() {
        // code that takes an hour to run
    }
}
```



To run all tests:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.23s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 2 tests
test tests::expensive_test ... ignored
test tests::it_works ... ok

test result: ok. 1 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```



To run only the ignored tests:

```bash
$ cargo test -- --ignored
    Finished test [unoptimized + debuginfo] target(s) in 0.00s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 1 test
test tests::expensive_test ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```



## 9.3 Test Organization

### 9.3.1 Unit Tests

The `#[cfg(test)]` annotation on the tests module tells Rust to compile and run the test code only when you run `cargo test`, not when you run `cargo build`. 

```rust
pub fn add(left: usize, right: usize) -> usize {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
```



### 9.3.2 Integration Tests

In Rust, integration tests are entirely external to your library.

#### 9.3.2.1 The `tests` Directory

```bash
adder
├── Cargo.lock
├── Cargo.toml
├── src
│   └── lib.rs
└── tests
    └── integration_test.rs
```

Filename: `tests/integration_test.rs`

```rust
use adder::add_two;

#[test]
fn it_works() {
    assert_eq!(4, add_two(2));
}
```

To run the test:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.21s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests\integration_test.rs (target\debug\deps\integration_test-6fd9f28f0e21fd4c.exe)

running 1 test
test it_works ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```



#### 9.3.2.2 Submodules in Integration Tests

Filename: tests/common.rs

```rust
pub fn setup() {
    // setup code specific to your library's tests would go here
}
```

To run the tests again, we’ll see a new section in the test output for the *common.rs* file, even though this file doesn’t contain any test functions nor did we call the `setup` function from anywhere:

```bash
$ cargo test
   Compiling adder v0.1.0 (E:\HHZ\gitee.com\elihe\learn-rust\12-test\05-test-anatomy\adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.15s
     Running unittests src\lib.rs (target\debug\deps\adder-291456aeb3d2db32.exe)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests\common.rs (target\debug\deps\common-fde2fd3c01f4b29c.exe)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests\integration_test.rs (target\debug\deps\integration_test-6fd9f28f0e21fd4c.exe)

running 1 test
test it_works ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

To avoid having `common` appear in the test output, instead of creating *tests/common.rs*, we’ll create *tests/common/mod.rs*.

```bash
├── Cargo.lock
├── Cargo.toml
├── src
│   └── lib.rs
└── tests
    ├── common
    │   └── mod.rs
    └── integration_test.rs
```



Filename: tests/integration_test.rs

```rust
use adder;

mod common;

#[test]
fn it_adds_two() {
    common::setup();
    assert_eq!(4, adder::add_two(2));
}
```





























