# 4. Enums and Pattern Matching

## 4.1 Defining an Enums

### 4.1.1 Enum Values

```rust
#[derive(Debug)]
enum IpAddrKind {
    V4,
    V6,
}

#[derive(Debug)]
struct IpAddr {
    kind: IpAddrKind,
    address: String,
}

fn main() {
    let home = IpAddr {
        kind: IpAddrKind::V4,
        address: String::from("127.0.0.1"),
    };
    println!("{home:?}");
    
    let loopback = IpAddr {
        kind: IpAddrKind::V6,
        address: String::from("::1")
    };
    println!("{loopback:?}")
}
```

Put data directly into each enum variant.

```rust
#[derive(Debug)]
enum IpAddr {
    V4(String),
    V6(String),
}

fn main() {
    let home = IpAddr::V4(String::from("127.0.0.1"));
    println!("{home:?}");
    
    let loopback = IpAddr::V6(String::from("::1"));
    println!("{loopback:?}");
}
```



### 4.1.2 Option

`Option<T>` is defined by the standard library as follows:

```rust
enum Option<T> {
    None,
    Some(T),
}
```



## 4.2 Match Control Flow

```rust
#[derive(Debug)]
enum Coin {
    Penny,
    Nickle,
    Dime,
    Quarter,
}

fn value_in_cents(coin: Coin) -> u8 {
    match coin {
        Coin::Penny => 1,
        Coin::Nickle => 5,
        Coin::Dime => 10,
        Coin::Quarter => 25,
    }
}

fn main() {
    let dime = Coin::Dime;
    println!("The value of dime is {} cents", value_in_cents(dime));
}
```



### 4.2.1 Patterns That Bind to Values

```rust
#![allow(dead_code)]
#[derive(Debug)]
enum UsState {
    Albama,
    Alaska,
}

#[derive(Debug)]
enum Coin {
    Penny,
    Nickle,
    Dime,
    Quarter(UsState),
}

fn value_in_cents(coin: Coin) -> u8 {
    match coin {
        Coin::Penny => 1,
        Coin::Nickle => 5,
        Coin::Dime => 10,
        Coin::Quarter(state) => {
            println!("State quarter from {state:?}!");
            25
        },
    }
}

fn main() {
    let quarter = Coin::Quarter(UsState::Alaska);
    println!("The value of quarter is {} cents", value_in_cents(quarter));
}
```



### 4.2.2 Matching with `Option<T>`

```rust
fn plus_one(x: Option<i32>) -> Option<i32> {
    match x {
        None => None,
        Some(n) => Some(n+1),
    }
}

fn main() {
    let five = Some(5);
    let six = plus_one(five);
    let none = plus_one(None);
    
    println!("six: {:?}", six);
    println!("none: {:?}", none);
}
```



### 4.2.3 Catch-all Patterns and the `_` Placeholder 

Run for the `other` arm uses the variable by passing it to the `move_player` function.

```rust
fn main() {
    let dice_roll = 9;
    
    match dice_roll {
        3 => add_fancy_hat(),
        7 => remove_fancy_hat(),
        other => move_player(other),
    }
}

fn add_fancy_hat() {
    println!("add fancy hat");
}

fn remove_fancy_hat() {
    println!("remove fancy hat");
}

fn move_player(n: u8) {
    println!("got {}, move player", n);
}
```

`_` is a special pattern that matches any value and does not bind to that value.

```rust
fn main() {
    let dice_roll = 9;
    
    match dice_roll {
        3 => add_fancy_hat(),
        7 => remove_fancy_hat(),
        _ => reroll(),
    }
}

fn add_fancy_hat() {}
fn remove_fancy_hat() {}
fn reroll() {}
```



## 4.3 Concise Control Flow with if let

```rust
fn main() {
    let config_max = Some(3u8);
    
    if let Some(max) = config_max {
        println!("got {max}");
    } else {
        println!("match nothing");
    }
}
```























