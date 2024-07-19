# 1. 基础概念

## 1.1 Variables

### 1.1.1 Mutability

```rust
fn main() {
    let mut x = 5;
    println!("The value of x is: {}", x);
    x = 6;
    println!("The value of x is: {}", x);
}
```



### 1.1.2 Constants

```rust
const THREE_HOURS_IN_SECONDS: u32 = 60 * 60 * 3;
```



### 1.1.3 Shadowing

```rust
fn main() {
    let x = 5;
    
    let x =  x + 1; // shadow
    
    {
        let x = x * 2; // shadow
        println!("The value of x in the inner scope is: {}", x);  // 12
    }
    
    println!("The value of x is {}", x); // 6
}

// ok
let spaces = "  ";
let spaces = spaces.len();

// error
let mut spaces = "  ";
spaces = spaces.len();  // type conflict
```



## 1.2 Data Types

### 1.2.1 Scalar 

#### 1.2.1.1 Integer

| Length  | Signed  | Unsigned |
| ------- | ------- | -------- |
| 8-bit   | `i8`    | `u8`     |
| 16-bit  | `i16`   | `u16`    |
| 32-bit  | `i32`   | `u32`    |
| 64-bit  | `i64`   | `u64`    |
| 128-bit | `i128`  | `u128`   |
| arch    | `isize` | `usize`  |



| Number literals  | Example       |
| ---------------- | ------------- |
| Decimal          | `98_222`      |
| Hex              | `0xff`        |
| Octal            | `0o77`        |
| Binary           | `0b1111_0000` |
| Byte (`u8` only) | `b'A'`        |



#### 1.2.1.2 Float

```rust
fn main() {
    let a = 2.0;       // f64
    let b: f32 = 3.0;  // f32
}
```



#### 1.2.1.3 Boolean

```rust
fn main() {
    let t = true;
    let f: bool = false;  // explicit
}
```



#### 1.2.1.4 Character

4 bytes in size and represents a Unicode Scalar Value. `U+0000` ~ `U+D7FF` & `U+E000` ~ `U+10FFFF`

```rust
fn main() {
    let c = 'z';
    let z: char = 'Z';  // explicit
    let emoji = '😄'；
}
```



### 1.2.2 Compound

#### 1.2.2.1 Tuple

```rust
fn main() {
    let tup = (500, 6.4, "abc");
    
    let (x, y, z) = tup;  // destructure
    
    // access by indices
    let five_hundred = x.0;
    let one = x.2;
}
```



#### 1.2.2.2 Array

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];
    let a: [i32; 5] = [1, 2, 3, 4, 5];  // explicit
    
    let a = [3; 5];  // [3, 3, 3, 3, 3]
    
    let first = a[0];  // access via index
    let second = a[1];
}
```



## 1.3 Functions

### 1.3.1 Parameters

```rust
fn main() {
    foo(5);
}

fn foo(x: i32) {
    println!("The value of x is: {x}");
}
```



### 1.3.2 Statements & Expressions

Distinctions:

- **Statements** are  instructions that perform some action and do  <font color="red">not return a value</font>
- **Expressions** evaluate to resultant value



```rust
fn main() {
    // let y = (let x = 5);  // "let x = 5" statment does not return a value
    
    let y = {
        let x = 5;
        x + 1
    };
    
    println!("{y}");
}
```

This is an expression: 

```rust
{
    let x = 5;
    x + 1
}
```



### 1.3.3 Return Values

```rust
fn plus_one(x: u32) -> u32 {
    x + 1
}
```



## 1.4 Comments

```rust
/**
The main function
*/
fn main() {
    // I'm feeling lucky today
    let lucky_number = 7;
}
```



## 1.5 Control Flow

### 1.5.1 if

```rust
fn main() {
    let number = 3;
    
    if number < 5 {
        println!("less than 5");
    } else if number > 5 {
        println!("greater than 5");
    } else {
        println!("equal to 5");
    }
}
```



### 1.5.2 loop

```rust
fn main() {
    let mut counter = 0;
    
    let result = loop {
        counter += 1;
        
        if counter == 10 {
            break counter * 2;
        }
    }
    
    println!("The result is {result}");
}
```



```rust
fn main() {
    let mut count = 0;
    
    'counting_up': loop {
        println!("count = {count}");
        let mut remaining = 10;
        
        loop {
            println!("remaining = {remaining}");
            if remaining == 9 {
                break;
            }
            if count ==  2 {
                break 'counting_up';
            }
            
            count += 1;
        }
    }
    
    println!("End count = {count}");
}
```



### 1.5.3 while

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];
    let mut index = 0;
    
    while index < 5 {
        println!("the value is: {}", a[index]);
        
        index += 1;
    }
}
```



### 1.5.4 for-in

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];
    
    for elem in a {
        println!("the value is: {elem}");
    }
}
```



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

































