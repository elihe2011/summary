# 5. Packages, Crates and Modules

The module system of Rust:

- **Packages**: A Cargo feature that lets you build, test and share crates
- **Crates**: A tree of modules that produces a library or executable
- **Modules** and **use**: Let you control the organization, scope, and privacy of paths
- **Paths**: A way of naming an item, such as a struct, function, or module



## 5.1 Packages and Crates

A crate is the smallest amount of code that the Rust compiler considers at a time.

Two forms of a crate:

- Binary crate: a program you can compile to an executable that you can run, such as a command-line program or a server. It must have a function called `main` that defines what happens when the executable runs.
- Library crate: don't have a `main` function, and don't compile to an executable.

To create a package:

```sh
$ cargo new my-project
     Created binary (application) `my-project` package
$ ls my-project
Cargo.toml
src
$ ls my-project/src
main.rs
```



## 5.2 Defining Modules to Control Scope and Privacy

### 5.2.1 Modules Cheat Sheet

How modules work:

- **Start from the crate root**: When compiling a crate, the compiler first looks in the crate root file (usually `src/lib.rs` for a library crate *or* `src/main.rs` for a binary crate） for code to compile.
- **Declaring modules**: In the crate root file, you can declare new modules; say you declare a "garden" module with `mod garden；`. The compiler will look for the module's code in these places:
  - Inline, within curly brackets that replace the semicolon following `mod gargen`
  - In the file `src/garden.rs`
  - In the file `src/garden/mod.rs`

- **Declaring submodules**: In any file other than the crate root, you can declare submodules. For example, you might declare `mod vegetables;` in `src/garden.rs`. The compiler will look for the submodule's code within the directory named for the parent module in these places:
  - Inline, directly following `mod vegetables`, with curly brackets instead of the semicolon
  - In the file `src/garden/vegetables.rs`
  - In the file `src/garden/vegetables/mod.rs`
- **Paths to code in modules**: Once a module is part of your crate, you can refer to code in that module from anywhere else in that same crate, as long as the privacy rules allow, using the path to the code. For example. an `Asparagus` type in the garden vegetables module would be found at `crate::garden::vegetables::Asparagus`
- **Private vs. Public**: Code within a module is private from its parent modules by default. To make a module public, declare it with `pub mode` instead of `mod`. To make items within a public module public as well, use `pub` before their declarations.
- **The `use` keyword**: Within a scope, the use keyword creates shortcuts to items to reduce repetition of long paths. In any scope that can refer to `crate::garden::vegetables::Asparagus`, you can create a shortcut with `use crate::garden::vegetables::Asparagus;` and from then on you only need to write `Asparagus` to make use of that type in the scope.

```bash
$ cargo new backyard
$ cd backyard
$ tree
.
├── Cargo.lock
├── Cargo.toml
├── src
│   ├── garden
│   │   └── vegetables.rs
│   ├── garden.rs
│   └── main.rs
```

Filename: `src/main.rs`

```rust
use crate::garden::vegetables::Asparagus;

pub mod garden;

fn main() {
    let plant = Asparagus{};
    println!("I'm growing {plant:?}");
}
```

Filename: `src/garden.rs`

```rust
pub mod vegetables;
```

Filename: `src/garden/vegetables.rs`

```rust
#[derive(Debug)]
pub struct Asparagus {}
```



### 5.2.2 Grouping Related Code in Modules

To create a library crate named `restaurant` by running `cargo new restaurant --lib`

Filename: `src/lib.rs`

```rust
mod front_of_house {
    mod hosting {
        fn add_to_waitlist() {}
        
        fn seat_at_table() {}
    }
    
    mod serving {
        fn take_order() {}
        
        fn serve_order() {}
        
        fn take_payment() {}
    }
}
```

The module tree:

```
crate
 └── front_of_house
     ├── hosting
     │   ├── add_to_waitlist
     │   └── seat_at_table
     └── serving
         ├── take_order
         ├── serve_order
         └── take_payment
```



## 5.3 Paths for Referring to an Item in the Module Tree

A path can take two forms:

- An absolute path is the full path starting from a crate root; for code from an external crate, the absolute path begins with the crate name, and for code from the current crate, it starts with the literal `crate`.
- A relative path starts from the current module and uses `self`, `super`, or an identifier in the current module.

Filename: `src/lib.rs`

```rust
mod front_of_house {
    mod hosting {
        fn add_to_waitlist() {}
    }
}

// module `hosting` is private, cannot compile
pub fn eat_at_restaurant() {
    // Absolute path
    crate::front_of_house::hosting::add_to_waitlist();
    
    // Relative path
    front_of_house::hosting::add_to_waitlist();
}
```



### 5.3.1 Exposing Paths with the `pub` Keyword

Filename: `src/lib.rs`

```rust
mod front_of_house {
    // add pub
    pub mod hosting {
        // add pub
        pub fn add_to_waitlist() {}
    }
}

// module `hosting` is private, cannot compile
pub fn eat_at_restaurant() {
    // Absolute path
    crate::front_of_house::hosting::add_to_waitlist();
    
    // Relative path
    front_of_house::hosting::add_to_waitlist();
}
```



### 5.3.2 Starting Relative Paths with `super`

Filename: `src/lib.rs`

```rust
fn deliver_order() {}

mod back_of_house {
    fn fix_incorrect_order() {
        cook_order();
        super::deliver_order();
    }
    
    fn cook_order() {}
}
```



### 5.3.3 Making Structs and Enums Public

If we use `pub` before a struct definition, we make the struct public, but the struct's fields will be private.

```rust
mod back_of_house {
    pub struct Breakfast {
        pub toast: String,
        seasonal_fruit: String
    }
    
    impl Breakfast {
        pub fn summer(toast: &str) -> Breakfast {
            Breakfast {
                toast: String::from(toast),
                seasonal_fruit: String::from("peaches"),
            }
        }
    }
}

pub fn eat_at_restaurant() {
    // Order a breakfast in the summer with Rye toast
    let mut meal = back_of_house::Breakfast::summer("Rye");
    // Change our mind about what bread we'd like
    meal.toast = String::from("Wheat");
    println!("I'd like {} toast please", meal.toast);
    
    // The next line won't compule if we uncomment it; we're not allowed
    // to see or modify th seasonal fruit that comes with the meal
    //meal.seasonal_fruit = String::from("blueberries");
}
```



In contrast, if we make an enum public, all of its variants are then public. We only need the `pub` before the `enum` keyword.

```rust
mod back_of_house {
    pub enum Appetizer {
        Soap,
        Salad,
    }
}

pub fn eat_at_restaurant() {
    let order1 = back_of_house::Appetizer::Soap;
    let order2 = back_of_house::Appetizer::Salad;
}
```



## 5.4 Bringing Paths into Scope with the use Keyword

To create a shortcut to a path with the `use` keyword once, and then use the shorter name everywhere else in the scope.

```rust
mod front_of_house {
    pub mod hosting {
        pub fn add_to_waitlist() {}
    }
}

use crate::front_of_house::hosting;

pub fn eat_at_restaurant() {
    hosting::add_to_waitlist();
}
```



Note that `use` only creates the shortcut for the particular scope in which the `use` occurs.

```rust
mod front_of_house {
    pub mod hosting {
        pub fn add_to_waitlist() {}
    }
}

// undeclared crate or module
/*use crate::front_of_house::hosting;

mod customer {
    pub fn eat_at_restaurant() {
        hosting::add_to_waitlist();  // use of undeclared crate or module `hosting`
    }
}*/

// Solution 1: move the `use` within the customer mod too
/*mod customer {
    use crate::front_of_house::hosting;
    
    pub fn eat_at_restaurant() {
        hosting::add_to_waitlist();  // use of undeclared crate or module `hosting`
    }
}*/

// Solution 2: reference the shortcut in the parent module with `super::hosting` within the child `customer` module
use crate::front_of_house::hosting;

mod customer {
    pub fn eat_at_restaurant() {
        super::hosting::add_to_waitlist();  // use of undeclared crate or module `hosting`
    }
}
```



### 5.4.1 Creating Idiomatic use Paths

Bringing the `add_to_waitlist` function into scope with `use`, which is **unidiomatic**

```rust
mod front_of_house {
    pub mod hosting {
        pub fn add_to_waitlist() {}
    }
}

use crate::front_of_house::hosting::add_to_waitlist;

pub fn eat_at_restaurant() {
    add_to_waitlist(); 
}
```



Bringing two types with the same name into the same scope requires using their parent modules:

```rust
use std::fmt;
use std::io;

fn function1() -> fmt::Result {}

fn function2() -> io::Result<()> {}
```



### 5.4.2 Providing New Names with the `as` Keyword

```rust
use std::fmt::Result;
use std::io::Result as IoResult;

fn function1() -> Result {}

fn function2() -> IoResult<()> {}
```



### 5.4.3 Re-exporting Names with `pub use`

When we bring a name into scope with the `use` keyword, the name available in the new scope is private. To enable the code that calls our code to refer to that names as if it had been defined in that code's scope, we can combine `pub` and `use`.

Making a name available for any code to use from a new scope with `pub use`

```rust
mod front_of_house {
    pub mod hosting {
        pub fn add_to_waitlist() {}
    }
}

pub use crate::front_of_house::hosting;

pub fn eat_at_restaurant() {
    hosting::add_to_waitlist(); 
}
```

Before this change, external code would have to call the `add_to_waitlist` function by using the path `restaurant::front_of_house::hosting::add_to_waitlist()`, which also would have required the `front_of_house` module to be marked as `pub`. Now that this `pub use` has re-exported the `hosting` module from the root module, external code can use the path `restaurant::hosting::add_to_waitlist()` instead.



### 5.4.4 Using External Packages

Filename: `Cargo.toml`

```toml
[dependencies]
rand = "0.8.5"
```

Filename: `src/main.rs`

```rust
use rand::Rng;

fn main() {
    let secret_number = rand::thread_rng().gen_range(1..=100);
}
```



### 5.4.5 Using Nested Paths to Clean Up Large use Lists

```rust
use std::cmp::Ordering;
use std::io;
// to
use std::{cmp::Ordering, io};

use std::io;
use std::io::Write;
// to
use std::io::{self, Write};
```



### 5.4.6 The Glob Operator

```rust
use std::collections::*;
```



## 5.5 Separating Modules into Different Files

To extract the `front_of_house` module to its own file.

Filename: `src/lib.rs`

```rust
mod front_of_house;

pub use crate::front_of_house::hosting;

pub fn eat_at_restaurant() {
    hosting::add_to_waitlist(); 
}
```

Filename: `src/front_of_house.rs`

```rust
pub mod hosting {
    pub fn add_to_waitlist() {}
}
```



Continue to extract the `hosting` module to its own file.

Filename: `src/front_of_house.rs`

```rust
pub mod hosting;
```

Filename: `src/front_of_house/hosting.rs`

```rust
pub fn add_to_waitlist() {}
```



**Alternate File Paths**

For a module named `front_of_house` declared in the crate root, the compile will look for the module's code in:

- `src/front_of_house.rs`
- `src/front_of_house/mod.rs` (older style, still supported path)

For a module named `hosting` that is a submodule of `front_of_house`, the compiler will look for the module's code in:

- `src/front_of_house/hosting.rs`
- `src/front_of_house/hosting/mod.rs` (older style, still supported path)

*If you use both styles for the same module, you'll get a compiler error.*























