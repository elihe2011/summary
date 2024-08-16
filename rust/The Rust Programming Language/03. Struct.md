# 3. Struct

## 3.1 Define & Instantiate

### 3.1.1 General Struct

```rust
#[allow(dead_code)]
#[derive(Debug)]
struct User {
    active: bool,
    username: String,
    email: String,
    sign_in_count: u64,
}

fn build_user(username: String, email: String) -> User {
    User {
        active: true,
        username: username,   // init explict
        email,                // use field init shorthand
        sign_in_count: 1,
    }
}

fn main() {
    let user1 = build_user(String::from("luna"), String::from("luna@hy.io"));
    
    let user2 = User {
        username: String::from("eli"),
        email: String::from("eli@hy.io"),
        ..user1  // struct update syntax
    };
    
    println!("{:?}\n{:?}", user1, user2);
}
```



### 3.1.2 Tuple Struct

Tuple struct without named fields, they just have the types of the fields

```rust
#![allow(dead_code)]

#[derive(Debug)]
struct Color(u32, u32, u32);

#[derive(Debug)]
struct Point(f64, f64, f64);

fn main() {
    let black = Color(0, 0, 0);
    let point = Point(1.2, 3.3, 2.6);
    
    println!("{:?}\n{:?}", black, point);
    
    println!("R of color: {}", black.0);
}
```



### 3.1.3 Unit-Like Struct

Unit-like structs don't have any fields, and they behave similarly to `()`. 

Unit like structs can be useful when you need to implement a trait on some type but don't have any data that you want to store in the type itself.

```rust
struct AlwaysEqual;

fn main() {
    let subject = AlwaysEqual;
}
```



### 3.1.4 Ownership of Struct Data

To store references to data owned by something else, but to do so requires the use of lifetimes. Lifetimes ensure that the data referenced by a struct is valid for as long as the struct is.

```rust
#[derive(Debug)]
struct User {
    active: bool,
    username: &str,   // slice is a reference, expected named lifetime parameter
    email: &str,
    sign_in_count: u64,
}

fn main() {
    let user = User {
        active: true,
        username: "luna",
        email: "luna@hy.io",
        sign_in_count: 2,
    };
    
    println!("{:?}", user);
}
```



## 3.2 Method Syntax

### 3.2.1 Defining Methods

```rust
struct Rectangle {
    width: u32,
    height: u32
}

impl Rectangle {
    fn area(self: &Self) -> u32 {
        self.width * self.height
    }
    
    // short for "self: &Self"
    fn width(&self) -> bool {
        self.width > 0 
    }
}

fn main() {
    let rect = Rectangle {
        width: 12,
        height: 15,
    };
    
    println!("The area of the rectangle is {} square pixels", rect.area());
    
    if rect.width() {
        println!("The rectangle has a nonzero width, it is {}", rect.width);
    }
}
```



### 3.2.2 Methods with more Parameters

```rust
struct Rectangle {
    width: u32,
    height: u32
}

impl Rectangle {
    fn area(self: &Self) -> u32 {
        self.width * self.height
    }
    
    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }
}

fn main() {
    let rect = Rectangle {
        width: 12,
        height: 15,
    };
    
    println!("The area of the rectangle is {} square pixels", rect.area());
    
    let rect2 = Rectangle {
        width: 7,
        height: 21,
    };
    println!("rect can hold rect2: {}", rect.can_hold(&rect2));
    
    let rect3 = Rectangle {
        width: 6,
        height: 10,
    };
    println!("rect can hold rect3: {}", rect.can_hold(&rect3));
}
```



### 3.2.3 Associated Functions

An associated functions that defined within an `impl` block, but don't have `self` as their first parameter (and thus are not methods) because they don't need an instance of the type to work with.

```rust
struct Rectangle {
    width: u32,
    height: u32
}

impl Rectangle {
    fn square(size: u32) -> Self {
        Self {
            width: size,
            height: size,
        }
    }

    fn area(self: &Self) -> u32 {
        self.width * self.height
    }
}

fn main() {
    let square = Rectangle::square(5); 
    
    println!("The area of the square is {} square pixels", square.area());
}
```



 

















