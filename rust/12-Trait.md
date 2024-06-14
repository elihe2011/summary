

# 1. Trait

Trait 在 Rust 中类似其他语言中的**接口，它定义了一个实现特定功能必须拥有的方法签名集合**。它们可以用来定义共享行为。

```rust
struct Sheep { naked: bool, name: &'static str}

trait Animal {
    fn new(name: &'static str) -> Self;

    fn name(&self) -> &'static str;
    fn noise(&self) -> &'static str;

    fn talk(&self) {
        println!("{} says {}", self.name(), self.noise())
    }
}

impl Sheep {
    fn is_naked(&self) -> bool {
        self.naked
    }

    fn shear(&mut self) {
        if self.is_naked() {
            println!("{} is already naked...", self.name);
        } else {
            println!("{} gets a haircut", self.name);

            self.naked = true;
        }
    }
}

impl Animal for Sheep {
    fn new(name: &'static str) -> Self {
        Sheep{ name: name, naked: false }
    }

    fn name(&self) -> &'static str {
        self.name
    }

    fn noise(&self) -> &'static str {
        if self.is_naked() {
            "baaaaah?"
        } else {
            "baaaaah!"
        }
    }

    fn talk(&self) {
        println!("{} pause briefly... {}", self.name, self.noise())
    }
}

fn main() {
    let mut dolly: Sheep = Animal::new("Dolly");

    dolly.talk();
    dolly.shear();
    dolly.talk();
}
```



## 1.1 Trait 的特点

- **默认实现**：提供默认的方法实现，使用该 trait 的类型可以选择使用或重写这些默认实现。
- **组合**：支持为一个类型实现多个 trait，从而组合不同的行为。
- **泛型约束**：即 trait bound，仅让实现了特定 trait 的类型使用某些泛型函数和结构体。
- **动态分发**：即 trait objects，允许在运行时调用具体类型实现的方法。



## 1.2 Trait bounds

在泛型编程中，trait bounds 用于指定一个泛型类型必须实现一个或多个 trait

```rust
// items 必须实现 Drawable trait
fn print_drawables<T: Drawable>(items: &[T]) {
    for item in items {
        item.draw();
    }
}
```



## 1.3 Trait Objects

对不同类型进行统一处理时，trait objects 提供了一种方法，它们通过一个指向实现了特定 trait 的类型的指针来实现动态分发。

```rust
// &dyn Drawable 是 trait object 的应用，在运行时处理不同的实现了 Drawable trait 的类型
fn print_drawables_dyn(drawables: &[&dyn Drawable]) {
    for drawable in drawables {
        drawable.draw();
    }
}
```



## 1.4 Trait 作为参数

将 trait 作为参数传递，使得函数能够更加通用和灵活

```rust
fn draw_anything(d: &dyn Drawable) {
    d.draw();
}
```



# 2. 派生 derive

通过 `#[derive]` 属性，编译器能够一个某些 trait 的基本实现。如果需要更复杂的行为，这些 trait 也可以手动实现。

可自动派生的 trait：

- `Eq`, `PartialEq`, `Ord`, `PartialOrd`  比较
- `Clone`  从 `&T` 创建副本 `T`
- `Copy` 使类型具有“复制语义”(copy semantics) 而非“移动语义”(move semantics)
- `Hash` 从 `&T` 计算哈希值 (hash)
- `Default` 创建数据类型的一个空实例
- `Debug` 使用 `{:?}` formatter 来格式化一个值

 ```rust
 #[derive(PartialEq, PartialOrd)]
 struct Centimeters(f64);
 
 #[derive(Debug)]
 struct Inches(i32);
 
 impl Inches {
     fn to_centimeters(&self) -> Centimeters {
         let &Inches(inches) = self;
 
         Centimeters(inches as f64 * 2.54)
     }
 }
 
 fn main() {
     let foot = Inches(12);
 
     println!("One foot equals {:?}", foot);
 
     let meter = Centimeters(50.0);
 
     let cmp = {
         if foot.to_centimeters() < meter {
             "smaller"
         } else {
             "bigger"
         }
     };
     println!("One foot is {} than one meter.", cmp);
 }
 ```



# 3. 使用 dyn 返回 trait

Rust 编译器需要直到每个函数的返回类型需要多少空间，这意味着所有函数都必须返回一个具体类型。

但函数如何返回 trait？因为其不同的实现将需要不同的内存量，所以无法直接返回。

解决方法：返回一个包含 trait 的 Box。因为 Box 只对堆中某些内存的引用，引用的大小是静态已知的，满足函数返回值的要求。

当函数通过上述方式返回指向堆的 trait 指针，则需要使用 dyn 关键字指定返回类型，例如 `Box<dyn Animal>`

```rust
struct Sheep {}
struct Cow {}

trait Animal {
    fn noise(&self) -> &'static str;
}

impl Animal for Sheep {
    fn noise(&self) -> &'static str {
        "baaaaah!"
    }
}

impl Animal for Cow {
    fn noise(&self) -> &'static str {
        "moooooo!"
    }
}

fn random_animal(random_number: f64) -> Box<dyn Animal> {
    if random_number < 0.5 {
        Box::new(Sheep {})
    } else {
        Box::new(Cow {})
    }
}

fn main() {
    let random_number = 0.234;
    let animal = random_animal(random_number);
    println!("You've randomly chosen an animal, and it says {}", animal.noise());
}
```



# 4. 运算符重载

示例，通过`ops::Add` 实现对 `+` 的重载

```rust
use std::ops;

struct Foo;
struct Bar;

#[derive(Debug)]
struct FooBar;

#[derive(Debug)]
struct BarFoo;

impl ops::Add<Bar> for Foo {
    type Output = FooBar;
    fn add(self, _rhs: Bar) -> Self::Output {
        println!("> Foo.add(Bar) was called");

        FooBar
    }
}

impl ops::Add<Foo> for Bar {
    type Output = BarFoo;
    fn add(self, _rhs: Foo) -> Self::Output {
        println!("> Bar.add(Foo) was called");

        BarFoo
    }
}

fn main() {
    println!("Foo + Bar = {:?}", Foo + Bar);
    println!("Bar + Foo = {:?}", Bar + Foo);
}
```



# 5. Drop

Drop trait 只有一个方法： drop，当对象离开作用域时会自动调用该方法，其主要作用是释放实现者实例拥有的资源。

`Box`，`Vec`, `String`, `File` 及 `Process` 是一些实现了 Drop trait 来释放资源的类型。

```rust
struct Droppable {
    name: &'static str,
}

impl Drop for Droppable {
    fn drop(&mut self) {
        println!("> Dropping {}", self.name);
    }
}

fn main() {
    let _a = Droppable { name: "a" };

    {
        let _b = Droppable { name: "b" };

        {
            let _c = Droppable { name: "c" };
            let _d = Droppable { name: "d" };

            println!("Exiting block B");
        }
        println!("Just exited block B");

        println!("Exiting block A");
    }
    println!("Just exited block A");

    // 手动调用 drop 函数销毁
    drop(_a);

    println!("End of the main function");
}
```



# 6. Iterator

Iterator trait 用来对集合类型实现迭代器。

该 trait 只需要定义一个返回 next 元素的方法。

for 结构会使用 `.into_iter()` 方法将一些集合类型转换为迭代器

```rust
struct Fibonacci {
    curr: u32,
    next: u32,
}

impl Iterator for Fibonacci {
    type Item = u32;

    fn next(&mut self) -> Option<Self::Item> {
        let new_next = self.curr + self.next;

        self.curr = self.next;
        self.next = new_next;

        Some(self.curr)
    }
}

fn fibonacci() -> Fibonacci {
    Fibonacci { curr: 1, next: 1 }
}

fn main() {
    // 序列迭代器
    let mut sequence = 0..3;
    println!("Four consecutive `next` calls on 0..3");
    println!("> {:?}", sequence.next());
    println!("> {:?}", sequence.next());
    println!("> {:?}", sequence.next());
    println!("> {:?}", sequence.next());

    // for 迭代
    println!("Iterate through 0..3 using `for`");
    for i in 0..3 {
        println!("> {}", i);
    }

    // 数组
    let array = [1u32, 4, 7, 8];
    println!("Iterate the following array: {:?}", array);
    for i in array.iter() {
        println!("> {}", i);
    }

    // take(n) 获取前 n 项
    println!("The first four terms of the Fibonacci sequence are:");
    for i in fibonacci().take(4) {
        println!("> {}", i);
    }

    // skip(n) 跳过前 n 项
    println!("The next for terms of the Fibonacci sequence are:");
    for i in fibonacci().skip(4).take(4) {
        println!("> {}", i);
    }
}
```



# 7. impl Trait

如果函数返回实现了 MyTrait 的类型，可以将其返回类型编写为 `-> impl MyTrait`，这将大大简化你的类型签名。

```rust
use std::iter;
use std::vec::IntoIter;

fn combine_vecs_explicit_return_type(
    v: Vec<i32>,
    u: Vec<i32>,
) -> iter::Cycle<iter::Chain<IntoIter<i32>, IntoIter<i32>>> {
    v.into_iter().chain(u.into_iter()).cycle()
}

fn combine_vecs(
    v: Vec<i32>,
    u: Vec<i32>,
) -> impl Iterator<Item=i32> {
    v.into_iter().chain(u.into_iter()).cycle()
}

fn main() {
    let v1 = vec![1, 2, 3];
    let v2 = vec![4, 5];

    // let mut v3 = combine_vecs_explicit_return_type(v1, v2);
    let mut v3 = combine_vecs(v1, v2);

    assert_eq!(Some(1), v3.next());
    assert_eq!(Some(2), v3.next());
    assert_eq!(Some(3), v3.next());
    assert_eq!(Some(4), v3.next());
    assert_eq!(Some(5), v3.next());

    println!("all done");
}
```

针对某些 Rust 类型无法写出，例如每个闭包都有自己未命名的具体类型。在使用 `impl Trait` 语法之前，必须在堆上进行分配才能返回闭包。但现在可以静态地完成所有操作：

```rust
fn make_adder_function(y: i32) -> impl Fn(i32) -> i32 {
    let closure = move |x: i32| { x + y };
    closure
}

fn main() {
    let plus_one = make_adder_function(1);
    assert_eq!(plus_one(2), 3);
    println!("all done");
}
```

还可以使用 `impl Trait` 返回使用 map 或 filter 闭包的迭代器

```rust
fn double_positives<'a>(numbers: &'a Vec<i32) -> impl Iterator<Item = i32> + 'a {
    numbers.iter().filter(|x| x > &&0).map(|x| x * 2)
}
```



# 8. Clone

当处理资源时，默认的行为是在赋值或函数调用的同时将它们转移。但也可以通过 Clone trait 把资源复制一份。

```rust
// 不含资源的单元结构体
#[derive(Debug, Clone, Copy)]
struct Nil;

// 包含资源的结构体
#[derive(Clone, Debug)]
struct Pair(Box<i32>, Box<i32>);

fn main() {
    // 实例化 Nil
    let nil = Nil;

    // 复制，未发生资源移动 move
    let copied_nil = nil;

    println!("original: {:?}", nil);
    println!("copied: {:?}", copied_nil);

    // 实例化 Pair
    let pair = Pair(Box::new(1), Box::new(2));
    println!("original: {:?}", pair);

    // 移动
    let moved_pair = pair;
    println!("copied: {:?}", moved_pair);

    // pair 已失去资源
    // println!("original: {:?}", pair);

    // 克隆
    let cloned_pair = moved_pair.clone();
    drop(moved_pair);

    // moved_pair 被销毁，无法访问
    // println!("copied: {:?}", moved_pair);

    // clone 的资源可正常访问
    println!("cloned: {:?}", cloned_pair);
}
```



# 9. 父 trait

Rust 没有“继承”，但可以将一个 trait 定义为另一个 trait 的超集 (即父 trait)

```rust
trait Person {
    fn name(&self) -> String;
}

trait Student: Person {
    fn university(&self) -> String;
}

trait Programmer {
    fn fav_language(&self) -> String;
}

trait CompSciStudent: Programmer + Student {
    fn git_username(&self) -> String;
}

fn comp_sci_student_greeting(student: &dyn CompSciStudent) -> String {
    format!("My name is {} and I attend {}. My favoriate language is {}. My Git username is {}",
        student.name(),
        student.university(),
        student.fav_language(),
        student.git_username(),
    )
}
```



# 10. 消除重叠 trait

针对多个 trait 具有相同的方法，为消除歧义，可以使用完全限定语法 (Fully Qualified Syntax)

```rust
trait UsernameWidget {
    fn get(&self) -> String;
}

trait AgeWidget {
    fn get(&self) -> u8;
}

struct Form {
    username: String,
    age: u8,
}

impl UsernameWidget for Form {
    fn get(&self) -> String {
        self.username.clone()
    }
}

impl AgeWidget for Form {
    fn get(&self) -> u8 {
        self.age
    }
}

fn main() {
    let form = Form {
        username: "rustacean".to_owned(),
        age: 28,
    };

    let username = <Form as UsernameWidget>::get(&form);
    assert_eq!("rustacean".to_owned(), username);

    let age = <Form as AgeWidget>::get(&form);
    assert_eq!(28, age);
}
```

























