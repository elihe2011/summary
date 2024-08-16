# 2. Ownership

Ownership is a set of rules that govern how a Rust program manages memory.



## 2.1 Ownership

### 2.1.1 Rules

Ownership rules:

- Each value in Rust has an *Owner*
- There can only be **one** owner at a time
- When the owner goes out of scope, the value will be dropped



### 2.1.2 Variable Scope

```rust
{
    let s = "hello";  // valid in scope
    
    // do stuff with s
} 
// scope is over, no longer valid
```



### 2.1.3 Move

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



### 2.1.4 Clone

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1.clone();  // value copyed here
    
    println!("s1={s1}"); 
    println!("s2={s2}");
}
```



### 2.1.5 Stack-Only Data: Copy

If a type implements the Copy trait, variables that use it do not move. but rather are trivially copied, making them still valid after assignment to another variable.

The types that implements Copy:

- integer
- boolean
- float
- char
- tuple if only contain tyoes that also implement Copy. For example, (i32, f64), but (i32, String) does not.



### 2.1.6 Ownership & Functions

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



### 2.1.7 Return Values & Scope

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



## 2.2 References & Borrowing

### 2.2.1 Reference

```rust
fn main() {
    let s1 = String::from("hello");
    let len = calculate_length(&s1);
    
    println!("The length of {s1} is {len}."); 
}

fn calculate_length(s: &String) -> usize {
    s.len()
}
```



### 2.2.2 Mutable Reference

Try to modify something we're borrowing, it doesn't work.

```rust
fn main() {
    let s = String::from("hello");
    change(&s);
    
    println!("{s}"); 
}

fn change(s: &String) {
    s.push_str(", world!");
}
```

A mutable reference is ok:

```rust
fn main() {
    let mut s = String::from("hello");
    change(&mut s);
    
    println!("{s}"); 
}

fn change(s: &mut String) {
    s.push_str(", world!");
}
```

If you have a mutable reference to a value, you can have no other references to that value.

```rust
fn main() {
    let mut s = String::from("hello");
    
    let r1 = &mut s;
    let r2 = &mut s;  // cannot borrow `s` as mutable more than once at a time
    
    println!("{r1}, {r2}"); 
}
```

Combine mutable and immutable references:

```rust
fn main() {
    let mut s = String::from("hello");
    
    let r1 = &s;
    let r2 = &s; 
    let r3 = &mut s; // cannot borrow `s` as mutable because it is also borrowed as immutable
    
    println!("{r1}, {r2}, {r3}"); 
}
```

A reference's scope starts from where it is introduced and continues through the last time that reference is used:

```rust
fn main() {
    let mut s = String::from("hello");
    
    let r1 = &s;
    let r2 = &s; 
    println!("{r1}, {r2}");
    
    let r3 = &mut s; // no problem
    println!("{r3}"); 
}
```



### 2.2.3 Dangling References

***A dangling pointer***: it references a location in memory that may have been given to someone else, by freeing some memory while preserving a pointer to that memory.

```rust
fn main() {
    let reference_to_nothing = dangle();
    
    println!("{reference_to_nothing}"); 
}

// when the code of dangle is finished, s will be deallocated.
fn dangle() -> &String {
    let s = String::from("hello");
    &s  // cannot return reference to local variable `s`
}
```

solution: 

```rust
fn no_dangle() -> String {
    let s = String::from("hello");
    s
}
```



### 2.2.4 The Rules of References

- At any given time, you can have either one mutable reference or any number of immutable references.
- References must always be valid.



## 2.3 Slice

A slice is a kind of reference, so it does not have ownership.

```rust
fn main() {
    let s = String::from("who is your destiny?");
    
    let pos = first_word(&s);
    
    println!("{}", &s[..pos]); 
}

fn first_word(s: &String) -> usize {
    let bytes = s.as_bytes();
    
    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return i;
        }
    }

    s.len()
}
```



### 2.3.1 String Slices

A string slice is a reference to part of a String:

```rust
fn main() {
    let s = String::from("hello world");
    
    let s1 = &s[..5];
    let s2 = &s[6..];
    println!("{s1}, {s2}");
    
    let s3 = &s[2..8];
    let s4 = &s[..];
    println!("{s3}, {s4}")
}
```

A potential BUG:

```rust
fn main() {
    let mut s = String::from("hello world");
    
    let s1 = first_word(&s);
    
    s.clear();  // cannot borrow `s` as mutable because it is also borrowed as immutable
    
    println!("{s1}") // immutable borrow
}

fn first_word(s: &String) -> &str {
    let bytes = s.as_bytes();
    
    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return &s[..i];
        }
    }
    
    &s[..]
}
```



### 2.3.2 String Literals as Slice

```rust
fn main() {
    let s = String::from("hello world");
    let s1 = first_word(&s);
    println!("{s1}");
    
    
    let literal_string = "hello world";
    let s2 = first_word(literal_string);
    println!("{s2}");
    
    let s3 = first_word(&literal_string[6..]);
    println!("{s3}");
}

fn first_word(s: &str) -> &str {
    let bytes = s.as_bytes();
    
    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return &s[..i];
        }
    }
    
    &s[..]
}
```



### 2.3.3 Other Slice

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];
    
    let slice = &a[1..3];
    
    assert_eq!(slice, &[2, 3]);
}
```





























