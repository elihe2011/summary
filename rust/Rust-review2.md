



# 2. Ownership

Ownership is a set of rules that govern how a Rust program manages memory.

## 2.1 Rules

Ownership rules:

- Each value in Rust has an *Owner*
- There can only be **one** owner at a time
- When the owner goes out of scope, the value will be dropped



## 2.2 Variable Scope

```rust
{
    let s = "hello";  // valid in scope
    
    // do stuff with s
} 
// scope is over, no longer valid
```



## 2.3 Move

Integers are simple values with a known, fixed size, they are pushed onto the stack.

```rust
fn main() {
    let x = 5;
    let y = x;
    
    println!("x={x}, y={y}"); // x=5, y=5
}
```



A String is made up of three parts as below, this group of data is stored on the **stack**. The memory on the **heap** that holds the contents:

- ptr：a pointer to the memory that holds the contents of the string
- length：used memory in bytes
- capacity: the total amount of memory in bytes

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1;  // value moved here
    
    // println!("s1={s1}");  // value borrowed here after move
    println!("s2={s2}");
}
```

if Rust copy the heap data, the operation could be very expensive in terms of runtime performance if the the data on the heap were large.



## 2.4 Clone

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1.clone();  // value copyed here
    
    println!("s1={s1}"); 
    println!("s2={s2}");
}
```



## 2.5 Stack-Only Data: Copy

If a type implements the Copy trait, variables that use it do not move. but rather are trivially copied, making them still valid after assignment to another variable.

The types that implements Copy:

- integer
- boolean
- float
- char
- tuple if only contain tyoes that also implement Copy. For example, (i32, f64), but (i32, String) does not.



## 2.6 Ownership & Functions

```rust
fn main() {
    let s = String::from("hello");
    takes_ownership(s); // value move here
    
    let x = 5;
    makes_copy(x);      // value copy here
}

fn takes_ownership(s: String) {
    println!("{s}");
}

fn makes_copy(i: i32) {
    println!("{i}");
}
```



## 2.7 Return Values & Scope

```rust
fn main() {
    let s1 = gives_ownership();
    
    let s2 = String::from("hello");
    let (s3, len) = takes_and_gives_back(s2); 
}

fn gives_ownership() -> String {
    let s = String::from("yours");
    s  // move out
}

fn takes_and_gives_back(s: String) -> (String, usize) {
    let length = s.len();
    (s, length)
}
```

































