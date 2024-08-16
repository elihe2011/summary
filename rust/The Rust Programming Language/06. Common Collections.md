# 6. Common Collections

## 6.1 Storing List of Values with Vectors

### 6.1.1 Creating a New Vector

```rust
let v: Vec<i32> = Vec::new();

let v = vec![1, 2, 3];
```



### 6.1.2 Updating a Vector

```rust
fn main() {
    let mut v = Vec::new();
    
    v.push(5);
    v.push(8);
    
    println!("{:?}", v);
}
```



### 6.1.3 Reading Elements of Vector

```rust
fn main() {
    let v = vec![1, 2, 3, 4, 5];
    
    // it may raise an error of the index out of bounds
    let third: &i32 = &v[2];
    println!("The third element is {}", third);
    
    let sixth: Option<&i32> = v.get(5);
    match sixth {
        Some(n) => println!("The sixth element is {}", n),
        None => println!("Not found"),
    }
}
```

When the program has a valid reference, the borrow checker enforces the ownership and borrowing rules to ensure this reference and any other references to the contents of the vector remain valid.

```rust
fn main() {
    let mut v = vec![1, 2, 3, 4, 5];
    
    let first: &i32 = &v[0]; // immutable borrow
    
    v.push(6);  // mutable borrow
    println!("{:?}", v);
    
    // cannot borrow `v` as mutable because it is also borrowed as immutable
    println!("The first element is {}", first);
}
```



### 6.1.4 Iterating Over the Values in a Vector

To borrow a moved value:

```tust
fn main() {
    let v = vec![1, 2, 3, 4, 5];
    
    // `v` moved due to this implicit call to `.into_iter()`
    for i in v {
        println!("{i}");
    }
    
    //println!("{v:?}"); // `v` had been moved
}
```

An immutable reference to each element:

```rust
fn main() {
    let v = vec![1, 2, 3, 4, 5];
    
    // `v` borrowed due to this implicit call to `.iter()`
    for i in &v {
        println!("{i}");
    }
    
    println!("{v:?}"); // ok
}
```

A mutable reference:

```rust
fn main() {
    let mut v = vec![1, 2, 3, 4, 5];
    
    for i in &mut v {
        *i *= *i;
    }
    
    println!("{v:?}"); 
}
```



### 6.1.5 Using an Enum to Store Multiple Types

Vectors can only store values that are of the same type. The variants of an enum are defined under the same enum type, so when we need one type to represent elements of different types, we can define and use an enum.

```rust
#[derive(Debug)]
enum SpreadsheetCell {
    Int(i32),
    Float(f64),
    Text(String),
}


fn main() {
    let row = vec![
        SpreadsheetCell::Int(3),
        SpreadsheetCell::Float(10.56),
        SpreadsheetCell::Text(String::from("hello")),
    ];
    
    println!("{row:?}"); 
}
```



## 6.2 Storing ITF-8 Encoded Text with Strings

### 6.2.1 What is a String

Rust has only one string type in the core language, which is the string slice `str` that is usually seen in its borrowed from `&str`(string slice). 

The `String` type, which provided by Rust's standard library rather than coded into the core language, is a growable, mutable, owned, UTF-8 encoded string type.



### 6.2.2 Creating a New String

```rust
// Method 1:
let mut s = String::new();

// Method 2: 
let data = "initial contents";
let s = data.to_string();

// Method 3:
let s = String::from("initial contents");
```



### 6.2.3 Updating a String

```rust
fn main() {
    let mut s = String::new();
    
    // appending a string slice
    s.push_str("hello");
    
    
    // appending a char
    s.push(' ');
    
    // concatenation with operator `+`
    s += "world";
    
    // macro
    s = format!("{}{}", &s, "!");

    println!("{s}"); 
}
```



### 6.2.4 Indexing into String

To try to access parts of a String using indexing syntax in Rust, you'll get an error.

```rust
fn main() {
    let s = String::from("hello");
    
    // the type `str` cannot be indexed by `{integer}`
    let c = s[1];
    
    println!("{c}"); 
}
```



### 6.2.5 Internal Representation

A String is a wrapper over a `Vec<u8>`

```rust
fn main() {
    let hello = String::from("Hola");
    println!("{}", hello.len()); // 4

    // begins with the capital Cyrillic letter Ze, not the number 3
    let hello = String::from("Здравствуйте");
    println!("{}", hello.len()); // 24, because each Unicode scalar value in that string takes 2 bytes of storage
    
    /*let hello = "Здравствуйте";
    let answer = &hello[0]; // error, `З` occupy two bytes
    println!("{}", answer);*/
    
    let answer = hello.as_bytes()[0];
    println!("{:?}", answer); // 208
}
```



### 6.2.6 Bytes and Scalar Values and Grapheme Cluster

Three relevant ways to look at strings from Rust's perspective: as bytes, scalar values, and grapheme clusters(the closest thing to what we would call letters)

The Hindi word “नमस्ते” written in the Devanagari script, it is stored as a vector of `u8` values that looks like this:

```
[224, 164, 168, 224, 164, 174, 224, 164, 184, 224, 165, 141, 224, 164, 164,
224, 165, 135]
```

As Unicode scalar values, which are what Rust’s `char` type is, those bytes look like this:

```
['न', 'म', 'स', '्', 'त', 'े']
```

As grapheme clusters, we’d get what a person would call the four letters that make up the Hindi word:

```
["न", "म", "स्", "ते"]
```



### 6.2.7 Slicing Strings

Indexing into a string is often a bad idea because it's not clear what the return type of the string-indexing operation should be: a byte value, a character, a grapheme cluster, or a string slice.

Rather  than indexing using `[]` with a single number, you can use `[]` with a range to create a string slice containing particular bytes.

```rust
fn main() {
    let hello = "Здравствуйте";
    let s = &hello[0..4]; 
    println!("{}", s); // Зд
}
```



### 6.2.8 Methods for Iterating Over Strings

```rust
fn main() {
    let s = "Зд";
    
    for c in s.chars() {
        print!("{} ", c); // З д 
    }
    println!(); 
    
    for b in s.bytes() {
        print!("{b} "); // 208 151 208 180
    }
}
```



## 6.3 Storing Keys with Associated Values in Hash Maps

### 6.3.1 Creating a New Hash Map

```rust
use std::collections::HashMap;

fn main() {
    let mut scores = HashMap::new();
    
    scores.insert(String::from("blue"), 10);
    scores.insert(String::from("red"), 23);
    
    println!("{scores:?}");
}
```



### 6.3.2 Accessing Values in a Hash Map

To get a value out of the hash map by providing its key to the `get` method:

```rust
use std::collections::HashMap;

fn main() {
    let mut scores = HashMap::new();
    
    scores.insert(String::from("blue"), 10);
    scores.insert(String::from("red"), 23);
    
    let team_name = String::from("red");
    
    // copied(): get an Option<i32> rather than Option<&i32>
    // unwrap_or(0): set score to 0 if scores doesn't have an entry for the key
    let score = scores.get(&team_name).copied().unwrap_or(0);
    println!("{score}");
}
```

To iterate over each key-value pair in a hash map in a similar manner as we do with vectors:

```rust
use std::collections::HashMap;

fn main() {
    let mut scores = HashMap::new();
    
    scores.insert(String::from("blue"), 10);
    scores.insert(String::from("red"), 23);
    
    for (key, value) in &scores {
        println!("{key}: {value}");
    }
}
```



### 6.3.3 Hash Maps and Ownership

For types that implement the `Copy` trait, like `i32`, the values are copied into the hash map. For owned values like `String`, the values will be moved and the hash map will be the owner of those values.

```rust
use std::collections::HashMap;

fn main() {
    let key = String::from("blue");
    let value = 10;
    
    let mut scores = HashMap::new();
    scores.insert(key, value);
    
    // println!("{key}"); // borrow of moved value: `key`
    println!("{value}");  // ok
    println!("{scores:?}");
}
```



### 6.3.4 Updating a Hash Map

```rust
use std::collections::HashMap;

fn main() {
    let mut scores = HashMap::new();
    
    scores.insert(String::from("blue"), 10);
    scores.insert(String::from("blue"), 25);  // Overwriting a value
    
    // Add a key and value only if a key isn't present
    scores.entry(String::from("blue")).or_insert(30);
    scores.entry(String::from("red")).or_insert(40);
    
    println!("{scores:?}");
}
```



Updating a Value Based on the Old Value:

```rust
use std::collections::HashMap;

fn main() {
    let text = "hello world wonderful world";
    
    let mut map = HashMap::new();

    for word in text.split_whitespace() {
        let count = map.entry(word).or_insert(0);
        *count += 1;
    }
   
    println!("{map:?}");
}
```



### 6.3.5 Hashing Functions

By default, `Hashmap` uses a hashing function called *SipHash* that can provide resistance to denial-of-service(DoS) attacks involving hash tables.





























