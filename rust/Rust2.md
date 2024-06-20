







- 













## 2.7 方法

方法一般与结构体、枚举、特性(trait) 一起使用



### 2.7.1 定义方法(impl)

```rust
pub struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    // 关联函数，不带self
    pub fn new(width: u32, height: u32) -> Rectangle {
        Rectangle {
            width,
            height,
        }
    }

    pub fn area(&self) -> u32 {
        self.width * self.height
    }

    // getter
    pub fn width(&self) -> u32 {
        self.width
    }

    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }
}

fn main() {
    let r = Rectangle::new(5, 7);
    println!("area={}", r.area());
    println!("width={}", r.width());

    let r2 = Rectangle::new(4, 5);
    println!("{}", r.can_hold(&r2));
}
```

关于 self：

- `self`：表示实例的所有权转移到该方法中，较少使用
- `&self`：表示该方法对实例的不可变借用

- `&mut self`：表示可变借用



## 2.8 泛型和特性

### 2.8.1 泛型 Generics

#### 2.8.1.1 泛型是什么

泛型就是一种多态。泛型主要目的是为程序员提供编程的便利，减少代码的臃肿，同时可以极大地丰富语言本身的表达能力。

```rust
fn add<T: std::ops::Add<Output = T>>(x: T, y: T) -> T {
    x + y
}

fn main() {
    println!("add i8: {}", add(3i8, 5i8));
    println!("add i32: {}", add(14, 9));
    println!("add f64: {}", add(1.5f64, 3.1f64));
}
```

示例2：

```rust
fn largest<T: std::cmp::PartialOrd>(list: &[T]) -> &T {
    let mut max= &list[0];

    for item in list.iter() {
        if item > max {
            max = item;
        }
    }

    max
}

// 使用特征约束
fn largest<T: PartialOrd + Copy>(list: &[T]) -> T {
    let mut max= list[0];

    for &item in list.iter() {
        if item > max {
            max = item;
        }
    }

    max
}

fn main() {
    let number_list = vec![32, 17, 25, 68, 23];
    let result = largest(&number_list);
    println!("the largest number in list: {}", result);

    let char_list = vec!['a', 'z', 'g', 'x'];
    let result = largest(&char_list);
    println!("the largest char in list: {}", result);
}
```



### 2.8.2 特征 Trait

与接口类似，Trait 定义了一组可以被共享的行为，只要实现了特征，就能使用这组行为。



#### 2.8.2.1 定义特征

将一些方法组合在一起，目的是定义一个实现某些目标所需的行为的集合。

```rust
pub trait Summary {
    fn summarize(&self) -> String;
}
```



#### 2.8.2.2 实现特征

```rust
pub struct Post {
    pub title: String,
    pub author: String,
    pub content: String,
}

impl Summary for Post {
    fn summarize(&self) -> String {
        format!("article: {}, author: {}", self.title, self.author)
    }
}

pub struct Tweet {
    pub username: String,
    pub message: String,
}

impl Summary for Tweet {
    fn summarize(&self) -> String {
        format!("username: {}, message: {}", self.username, self.message)
    }
}
```

特征定义与实现的位置的原则：**如果想要为类型 A 实现特征 T，那么 A 或 T 至少有一个是在当前作用域定义中的**！该规则称为“孤儿规则”，用于确保其他人编写的代码不会破坏你的代码，也确保你不会莫名其妙地破坏牛马不相及的代码。

**默认实现**：即在特征中定义具有默认实现的方法，其他类型无需再实现或重载该方法

```rust
pub trait Summary {
    pub summarize_author(&self) -> String;
    
    pub summarize(&self) -> String {
        format!("Read more from {}", self.summarize_author())
    }
}
```



#### 2.8.2.3 特征作为函数参数

```rust
pub fn notify(item: &impl Summary) {
    println!("Breaking news! {}", item.summarize());
}
```

类似其他语言中，使用接口作为函数参数。



#### 2.8.1.4 特征约束 (trait bound)

```rust
// 改语法糖 impl Summary 形式为特征约束 T: Summary, 
pub fn notify<T: Summary>(item: &T) {
    println!("Breaking news! {}", item.summarize());
}

// 多个参数
pub fn notify(item1: &impl Summary, item2: &impl Summary) {}
pub fn notify<T: Summary>(item1: &T, item2: &T) {}
```



**多次约束**：

```rust
// 语法糖形式
pub fn notify(item: &(impl Summary + Display)) {}

// 特征约束形式
pub fn notify<T: Summary + Display>(item: &T) {}
```



**Where 约束**:

```rust
// 特征约束很多时，函数签名将变得很复杂
fn some_function<T: Display + Clone, U: Clone + Debug>(t: &T, u: &U) -> i32 {}

// 通过 where 改写
fn some_function<T, U>(t: &T, u: &U) -> i32
    where T: Display + Clone,
          U: Clone + Debug
{}
```



**使用特征约束有条件地实现方法或特征**：

特征约束，可以再指定类型 + 指定特征的条件下去实现方法

```rust
use std::fmt::Display;

struct Pair<T> {
    x: T,
    y: T,
}

impl<T> Pair<T> {
    fn new(x: T, y: T) -> Self {
        Self {
            x,
            y,
        }
    }
}

impl<T: Display + PartialOrd> Pair<T> {
    fn cmp_display(&self) {
        if self.x > self.y {
            println!("The largest member is x = {}", self.x);
        } else {
            println!("The largest member is y = {}", self.y);
        }
    }
}
```



有条件地实现特征：

```rust
impl<T: Display> ToString for T {
    // --snip--
}
```

对于任何实现了 Display 特征的类型调用由  ToString 定义的 `to_string()` 方法。



#### 2.8.2.5 函数返回 impl Trait

通过 `impl Trait` 来说明一个函数返回了一个类型，改类型实现了某个特征：

```rust
fn returns_summarizable() impl Summary {
    Tweet {
        username: String::from("jack"),
        content: String::from("just a test"),
    }
}
```



#### 2.8.2.6 通过 derive 派生特征

`#[derive(Debug)]` 是一种特征派生语法，被 derive 标记的对象回自动实现对应的默认特征代码，继承相应的功能。例如结构体标记后，就可以使用 `println!("{:?}", s)` 的形式打印该结构体的对象。

derive 派生出来的是 Rust 默认提供的特征，在开发过程中极大简化了自己手动实现相应特征的需求。



#### 2.8.2.7 调用方法需要引入特征

```rust
use std::convert:TryInto;

fn main() {
    let a: i32 = 10;
    let b: u16 = 100;

    let _b = b.try_into().unwrap();

    if a < _b {
        println!("ok");
    }
}
```



#### 2.8.2.8 示例

为自定义类型实现 + 操作：

```rust
use std::ops::Add;

#[derive(Debug)]
struct Point<T: Add<T, Output=T>> {
    x: T,
    y: T,
}

impl<T: Add<T, Output=T>> Add for Point<T> {
    type Output = Point<T>;

    fn add(self, p: Point<T>) -> Point<T> {
        Point{
            x: self.x + p.x,
            y: self.y + p.y,
        }
    }

    // 另一种写法
    /*fn add(self, rhs: Self) -> Self::Output {
        Self::Output{
            x: self.x + rhs.x,
            y: self.y + rhs.y,
        }
    }*/
}

fn add<T: Add<T, Output=T>>(a: T, b: T) -> T {
    a + b
}

fn main() {
    let p1 = Point{x: 1.1, y: 3.6};
    let p2 = Point{x: 2.4, y: 1.7};
    println!("{:?}", add(p1, p2));

    let p3 = Point{x: 3, y: 4};
    let p4 = Point{x: 2, y: 3};
    println!("{:?}", add(p3, p4));
}
```



自定义类型打印输出：

```rust
use std::fmt::{Display, Formatter};

#[derive(Debug,PartialEq)]
enum FileState {
    Open,
    Closed,
}

#[derive(Debug)]
struct File {
    name: String,
    data: Vec<u8>,
    state: FileState,
}

impl Display for FileState {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match *self {
            FileState::Open => write!(f, "OPEN"),
            FileState::Closed => write!(f, "CLOSED"),
        }
    }
}

impl Display for File {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        write!(f, "<{} ({})>", self.name, self.state)
    }
}

impl File {
    fn new(name: &str) -> File {
        File {
            name: String::from(name),
            data: Vec::new(),
            state: FileState::Closed,
        }
    }
}

fn main() {
    let f = File::new("abc.txt");

    println!("{:?}", f);
    println!("{}", f);

    // File { name: "abc.txt", data: [], state: Closed }
    // <abc.txt (CLOSED)>
}
```



### 2.8.3 特征对象

#### 2.8.3.1 特征对象定义

```rust
pub trait Draw {
    fn draw(&self);
}

pub struct Button {
    pub width: u32,
    pub height: u32,
    pub label: String,
}

impl Draw for Button {
    fn draw(&self) {
        todo!()
    }
}

pub struct SelectBox {
    pub width: u32,
    pub height: u32,
    pub options: Vec<String>,
}

impl Draw for SelectBox {
    fn draw(&self) {
        todo!()
    }
}

// UI组件代码
pub struct Screen {
    pub components: Vec<?>,
}
```

**特征对象**指向实现了 `Draw` 特征的类型的实例，即指向 `Button` 或 `SelectBox` 的实例，这种映射关系存储在一张表中，可以在运行时通过特征对象找到具体调用的类型方法。

可通过 `&` 引用或 `Box<T>` 智能指针的方式来创建特征对象。

```rust
trait Draw {
    fn draw(&self) -> String;
}

impl Draw for u8 {
    fn draw(&self) -> String {
        format!("u8: {}", *self)
    }
}

impl Draw for f64 {
    fn draw(&self) -> String {
        format!("f64: {}", *self)
    }
}

fn draw1(x: Box<dyn Draw>) {
    x.draw();
}

fn draw2(x: &dyn Draw) {
    x.draw();
}

fn main() {
    let x = 3.14;
    let y = 8u8;

    draw1(Box::new(x));
    draw1(Box::new(y));

    draw2(&x);
    draw2(&y);
}
```

代码说明：

- `draw1` 函数的参数是 `Box<dyn Draw>` 形式的特征对象，该特征对象通过 `Box::new(x)` 的方式创建
- `draw2` 函数的参数是 `&dyn Draw` 形式的特征对象，该特征对象是通过 `&x` 的方式创建的
- `dyn` 关键字只用在特征对象的类型声明上，在创建时无需使用 dyn

完善UI组件代码：

```rust
pub struct Screen {
    pub components: Vec<Box<dyn Draw>>,
}

impl Screen {
    pub fn run(&self) {
        for component in self.components.iter() {
            component.draw();
        }
    }
}
```

通过泛型实现：

```rust
pub struct Screen<T: Draw> {
    pub components: Vec<T>,
}

impl<T> Screen<T>
    where T: Draw {
    pub fn run(&self) {
    	for component in self.components.iter() {
            component.draw();
        }    
    }
}
```

使用组件列表：

```rust
fn main() {
    let screen = Screen {
        components: vec![
            Box::new(SelectBox {
                width: 75,
                height: 10,
                options: vec![
                    String::from("Yes"),
                    String::from("Maybe"),
                    String::from("No"),
                ],
            }),
            Box::new(Button {
                width: 50,
                height: 10,
                label: String::from("OK"),
            })
        ]
    };

    screen.run();
}
```



#### 2.8.3.2 特征对象的动态分发

静态分发和动态分发：

- **静态分发(static dispatch)**：泛型是在编译期完成处理的，编译器会为每一个泛型参数对应的具体类型生成一份代码。因为在编译期完成，对运行时性能完成没有任何影响
- **动态分发(dynamic dispatch)**：直到运行时，才能确定需要调用什么方法。

静态分发 `Box<T>` 和动态分发 `Box<dyn Trait>` 的区别：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/rust-static-vs-dynamic-dispatch.png)

- **特征对象大小不固定**：对于特征 Draw，类型 Button 和 SelectBox 都可以实现它，因此特征没有固定大小
- **几乎总是使用特征对象的引用方式**，如 `&dyn Draw`，`Box<dyn Draw>`
  - 特征对象没有固定大小，但它的引用类型的大小是固定的，它由两个指针组成 (ptr & vptr)，因此占用两个指针大小
  - 指针 ptr 指向一个实现特征 Draw 的具体类型的实例，即当作特征 Draw 来用的类型的实例，比如类型 Button 和 SelectBox 的实例
  - 指针 vptr 指向一个虚表 vtable，该虚表中保存了类型 Button 和 SelectBox 的实例对于可以调用的实现于特征 Draw 的方法。当调用方法时，直接从 vtable 中找到方法并调用。

总结：当类型 Button 实现了特征 Draw 时，类型 Button 的实例对象 btn 可以当作特征 Draw 的特征对象类型来使用，btn 中保存了作为特征对象的数据指针(指向类型 Button 的实例数据)和行为指针 (指向vtable)



#### 2.8.3.3 Self 与 self

Rust 中的两个 self：

- self：当前实例对象
- Self：特征或方法类型的别名

```rust
trait Draw {
    fn draw(&self) -> Self;
}

#[derive(Clone)]
struct Button;

impl Draw for Button {
    fn draw(&self) -> Self {
        self.clone()
    }
}

fn main() {
    let btn = Button;
    let new_btn = btn.draw();
}
```



#### 2.8.3.4 特征对象的限制

不是所有特征都拥有特征对象，只有对象安全的特征才行。当一个特征的所有方法都有如下属性时，它的对象才是安全的：

- 方法的返回类型不能是  Self
- 方法没有任何泛型参数

对象安全对于也在对象是必须的，因为一旦有了特征对象，就不再需要知道实现该特征的具体类型是什么。如果特征方法返回了具体的 Self 类型，但特征对象忘记了其真正的类型，此时 Self 没人知道它到底是谁。

对于泛型类型参数来说，当使用特征时，其会放入具体的类型参数：此具体类型变成了实现该特征类型的一部分。而当使用特征对象时，其具体类型被抹去了，故而无从得知放入泛型参数类型到底是什么。

标准库中 Clone 特征就不符合对象安全的要求：

```rust
pub trait Clone {
    fn clone(&self) -> Self;
}
```

String 类型实现了 Clone 特征，其实例调用 clone 方法时会得到一个 String 实例。类似的，当调用 `Vec<T>` 实例的 clone 方法会得到一个 `Vec<T>` 实例。clone 的签名需要知道什么类型会代替 Self，因为这是它的返回值。

如果违反对象安全规则，编译器将提示：

```rust
pub struct Screen {
    pub components: Vec<Box<dyn Clone>>,
}
```



### 2.8.4 特征进阶

#### 2.8.4.1 关联类型

关联类型是在特征定义的语句块中，声明一个自定义类型，这样就可以在特征的方法签名中使用该类型：

```rust
// 标准库迭代器特征
pub trait Iterator {
    type Item;  // 关联类型，用于替代遍历的值的类型
    
    fn next(&mut self) -> Option<Self::Item>;
}
```

**Self 用来指代当前调用者的具体类型，那么 Self::Item 用来指定该类型实现中定义的 Item 类型**：

```rust
impl Iterator for Counter {
    type Item = u32;
    
    for next(&mut self) -> Option<Self::Item> {
        // --snip--
    }
}

fn main() {
    let c = Counter{..};
    c.next()
}
```

使用泛型：

```rust
pub trait Iterator<Item> {
    fn next(&mut self) -> Option<Item>;
}
```

但是当类型定义复杂时，使用泛型的代码可读性不好，建议使用关联类型：

```rust
pub trait CacheableItem: Clone + Default + fmt::Debug + Decodable + Encodable {
    type Address: AsRef<[u8]> + Clone + fmt::Debug + Eq + Hash;
    
    fn is_null(&self) -> bool;
}
```

多类型泛型：

```rust
trait Container<A,B> {
    fn contains(&self, a: A, b: B) -> bool;
} 

trait difference<A,B,C>(container: &C) -> i32
  where
    C: Container<A,B> {...}
```

改用关联类型，更好的可读性：

```rust
trait Container {
    type A;
    type B;
    fn contains(&self, a: &Self::A, b: Self::B) -> bool;
}

fn difference<C: Container>(container: &C) {}
```



#### 2.8.4.2 默认泛型类型参数

当使用泛型类型参数时，可以为其指定一个默认的具体类型：

```rust
trait Add<RHS=Self> {
    type Output;
    
    fn add(self, rhs: RHS) -> Self::Output;
}
```

泛型参数 RHS 有一个默认值，当用户不指定 RHS 时，默认使用两个同样类型的值相加，然后返回一个关联类型 Output.

```rust
use std::ops::Add;

#[derive(Debug, PartialEq)]
struct Point {
    x: i32,
    y: i32,
}

impl Add for Point {
    type Output = Point;

    fn add(self, other: Point) -> Point {
        Point {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
    /*fn add(self, rhs: Self) -> Self::Output {
        Point {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
        }
    }*/
}

fn main() {
    assert_eq!(Point{x: 1, y: 2} + Point{x: 3, y: 4},
        Point{x: 4, y: 6})
}
```

两个不同类型相加：

```rust
use std::ops::Add;

struct Millimeters(u32);
struct Meters(u32);

impl Add<Meters> for Millimeters {
    type Output = Millimeters;
    
    fn add(self, other: Meters) -> Millimeters {
        Millimeters(self.0 + other.0 * 1000)
    }
}
```

默认类型参数主要用于：

- 减少实现的样板代码
- 扩展类型但无需大幅度修改现有代码



#### 2.8.4.3 调用同名方法

```rust
trait Pilot {
    fn fly(&self);
}

trait Wizard {
    fn fly(&self);
}

struct Human;

impl Pilot for Human {
    fn fly(&self) {
        println!("This is your captain speaking!");
    }
}

impl Wizard for Human {
    fn fly(&self) {
        println!("Up");
    }
}

impl Human {
    fn fly(&self) {
        println!("waving arms furiously!")
    }
}
```

优先调用类型自身的方法：

```rust
fn main() {
    let person = Human;
    person.fly();
}
```

调用特征上的方法，因为方法名称相同，需要显示调用：

```rust
fn main() {
    let person = Human;

    Pilot::fly(&person);
    Wizard::fly(&person);

    person.fly();
}
```



#### 2.8.4.4 完全限定语法

```rust
trait Animal {
    fn baby_name() -> String;
}

struct Dog;

impl Animal for Dog {
    fn baby_name() -> String {
        String::from("puppy")
    }
}

impl Dog {
    fn baby_name() -> String {
        String::from("Spot")
    }
}

fn main() {
    // ok
    println!("A baby dog is called a {}", Dog::baby_name());

    // cannot call associated function of trait
    // println!("A baby dog is called a {}", Animal::baby_name());

    // ok
    println!("A baby dog is called a {}", <Dog as Animal>::baby_name());
}
```

单纯从 `Animal::baby_name()` 上，编译器无法得到任何有效的信息，需要使用**完全限定语法**明确调用的函数。通过 as 关键字，向Rust编译器提供类型注释，即Animal就是Dog，而不是其他，因此最终会调用 `impl Animal for Dog` 中的方法。

完全限定语法：

```rust
<Type as Trait>::function(receiver_if_method, next_arg, ...);
```

第一个参数是方法接收器 receiver (三种self)，只有方法才拥有，例如关联函数就没有 receiver.



#### 2.8.4.5 特征定义中的特征约束

特征A使用另一个特征B的功能(另一种形式的特征约束)，此种情况下，不仅要为类型实现特征A，还要为类型实现特征B才行，即 supertrait

```rust
use std::fmt::Display;

trait OutlinePrint: Display {
    fn outline_print(&self) {
        let output = self.to_string();
        let len = output.len();
        println!("{}", "*".repeat(len + 4));
        println!("*{}*", " ".repeat(len + 2));
        println!("* {} *", output);
        println!("*{}*", " ".repeat(len + 2));
        println!("{}", "*".repeat(len + 4));
    }
}

struct Point {
    x: i32,
    y: i32,
}

impl OutlinePrint for Point {}

// Point 需要增加 对 Display 特征的实现
use std::fmt;

impl fmt::Display for Point {
    fm fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}
```



#### 2.8.4.6 在外部类型上实现外部特征(newtype)

**孤儿规则**：特征或类型必需至少一个是本地的，才能在此类型上定义特征。

**newtype模式**：可绕过孤儿规则。即为一个元组结构体创建新类型。该元组结构体封装有一个字段，该字段就是希望实现特征的具体类型。

```rust
use std::fmt;

struct Wrapper(Vec<String>);

impl fmt::Display for Wrapper {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "[{}]", self.0.join(", "))
    }
}

fn main() {
    let w = Wrapper(vec![String::from("hello"), String::from("world")]);
    println!("w = {}", w);
}
```

`struct Wrapper(Vec<String>)` 是一个元组结构体，它定义了一个新类型 Wrapper。



## 2.9 集合

### 2.9.1 动态数组 Vector

动态数组类型：`Vec<T>`

动态数组特点：

- 内存连续
- 元素类型相同



#### 2.9.1.1 创建和更新

- `Vec::new()`
- `vec![...]`

```rust
fn main() {
    let mut v1 = Vec::new();
    v1.push(1);
    println!("{:?}", v1);

    let mut v2 = vec![1, 2, 3];
    v2.remove(2);
    println!("{:?}", v2);
}
```



#### 2.9.1.2 读取元素

两种方式：

- 索引下标：性能高，但可能发生越界访问错误
- get方法：未找到时返回None，不会引发越界错误，但性能有轻微损耗

```rust
fn main() {
    let v = vec![1, 2, 3, 4, 5];

    let third = &v[2];
    println!("{}", third);

    let hundred = match v.get(100) {
        Some(n) => n,
        None => {
            println!("not found");
            &0
        }
    };

    println!("{}", hundred);
}
```



#### 2.9.1.3 同时借用多个元素

```rust
fn main() {
    let mut v = vec![1, 2, 3, 4, 5];

    // immutable borrow occurs here
    let first = &v[0];  

    // mutable borrow occurs here
    v.push(6);

    // immutable borrow later used here
    println!("the first element is {}", first);
}
```

错误原因：数据的大小是可变的，当旧数组的大小不够用时，Rust会重新分配一块更大的内存空间，然后把旧数组拷贝过来。此种情况下，之前的引用显然会指向一块无效的内存。



#### 2.9.1.4 迭代遍历

只读遍历：

```rust
fn main() {
    let v = vec![1, 2, 3, 4, 5];

    // ok
    // for i in &v {
    //     print!("{i} ")
    // }

    // ok
    for i in v {
        print!("{i} ")
    }
}}
```



遍历修改：

```rust
fn main() {
    let mut v = vec![1, 2, 3, 4, 5];
    
    for i in &mut v {
        *i += 10
    }

    println!("{:?}", v);
}

```



#### 2.9.1.5 存储不同类型元素

数组的元素类型必须相同，但可通过枚举和特征对象来实现不同类型元素存储

使用枚举：

```rust
#[derive(Debug)]
enum IpAddr {
    V4(String),
    V6(String),
}

fn main() {
    let v = vec![
        IpAddr::V4("127.0.0.1".to_string()),
        IpAddr::V6("::1".to_string()),
    ];

    for ip in v {
        println!("{:?}", ip);
    }
}
```



使用特征对象：使用场景更广，主要原因在于特征对象非常灵活，而编译器对枚举的限制较多，且无法动态增加类型

```rust
trait IpAddr {
    fn display(&self);
}

struct V4(String);
impl IpAddr for V4 {
    fn display(&self) {
        println!("ipv4: {:?}", self.0);
    }
}

struct V6(String);
impl IpAddr for V6 {
    fn display(&self) {
        println!("ipv6: {:?}", self.0);
    }
}

fn main() {
    // 必须手动指定类型 Vec<Box<dyn IpAddr>>，表示数组v存储的是特征IpAddr的对象
    let v: Vec<Box<dyn IpAddr>> = vec![
        Box::new(V4("127.0.0.1".to_string())),
        Box::new(V6("::1".to_string())),
    ];

    for ip in v {
        ip.display();
    }
}
```



#### 2.9.1.6 排序

Rust中，实现的两种排序算法：

- 稳定排序：
  - sort
  - sort_by
- 非稳定排序：
  - sort_unstable
  - sort_unstable_by

`非稳定` 不是指排序算法本身不稳定，而是指在排序过程中对相等元素的处理方式。在 `稳定` 排序算法中，对相等的元素，不会对其进行重新排序，但 `不稳定` 的算法则不保证这点。

`非稳定` 排序的算法速度优于 `稳定` 排序算法，同时，`稳定` 排序还会额外分配原数组一半的空间。



**整数数组排序**：

```rust
fn main() {
    let mut v = vec![8, 9, 5, 2, 3, 1];

    v.sort_unstable();

    println!("{:?}", v);
}
```



**浮点数数组排序**：

```rust
fn sort_float_array() {
    let mut v = vec![1.0, 5.6, 10.3, 2.0, 15f32];

    v.sort_unstable();

    println!("{:?}", v);
}
```

错误：the trait `Ord` is not implemented for `f32`

原因：浮点数中，存在一个NaN值，但这个值无法与其他的浮点数进行对比，因此浮点数类型并没有实现全数值可比较 Ord 的特性，而是实现了部分可比较特性 PartialOrd。

解决：当确定浮点数数组中，不包含 NaN 值，可以使用 partial_cmp 作为大小判断的依据

```rust
fn sort_float_array() {
    let mut v = vec![1.0, 5.6, 10.3, 2.0, 15f32];

    v.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());

    println!("{:?}", v);
}
```



**结构体数组排序**：

```rust
#[derive(Debug)]
struct Person {
    name: String,
    age: u32,
}

impl Person {
    fn new(name: String, age: u32) -> Person {
        Person {
            name,
            age,
        }
    }
}

fn main() {
    let mut people = vec![
        Person::new("Jack".to_string(), 21),
        Person::new("Dianna".to_string(), 18),
        Person::new("Tom".to_string(), 19),
    ];

    people.sort_unstable_by(|a, b| a.age.cmp(&b.age));

    println!("{:?}", people);
}
```



排序需要实现 Ord 特性，如果结构体实现了该特性，就不需要自定义比较函数！实现 Ord 需要实现 Ord、Eq、PartialEq、PartialOrd 这些特性，可通过 derive 使用这些属性。注意：`derive Ord` 特性，需要确保你的结构体所有属性均实现了 Ord 相关特性，否则会发生编译错误。derive 默认实现会依据属性的顺序依次进行比较。

```rust
#[derive(Debug, Ord, Eq, PartialOrd, PartialEq)]
struct Person {
    name: String,
    age: u32,
}

impl Person {
    fn new(name: String, age: u32) -> Person {
        Person { name, age  }
    }
}

fn main() {
    let mut people = vec![
        Person::new("Jack".to_string(), 21),
        Person::new("Dianna".to_string(), 18),
        Person::new("Tom".to_string(), 19),
    ];

    people.sort_unstable();

    println!("{:?}", people);
}
```



### 2.9.2 键值存储 HashMap

#### 2.9.2.1 创建 HashMap

**通过 new 创建**：

```rust
// 未包含在Rust的preclude中，需要手动导入
use std::collections::HashMap;

fn main() {
    // let mut gems = HashMap::new();

    // 预知KV数量时，指定大小，避免频繁的内存分配和拷贝，提升性能
    let mut gems = HashMap::with_capacity(3);

    gems.insert("红宝石", 1);
    gems.insert("蓝宝石", 3);
    gems.insert("破石头", 10);
    println!("{:?}", gems);
}
```



**通过迭代器和collect()方法创建**:

```rust
fn main() {
    let cities = vec![
        ("Beijing", 10),
        ("Shenzhen", 755),
        ("Shanghai", 21),
    ];

    // 需要通过类型标注 HashMap<_,_> 来告诉编译器帮收集为 HashMap 集合类型
    let city_map: HashMap<_,_> = cities.into_iter().collect();
    println!("{:?}", city_map);
}
```



#### 2.9.2.2 所有权转移

HashMap 的所有权规则与其它类型没有区别：

- 类型已实现 Copy 特征，该类型会被复制进 HashMap，因此无所谓所有权
- 类型未实现 Copy 特征，所有权将被转移给 HashMap 中

```rust
fn main() {
    let name = String::from("Jack");
    let age = 32;

    let mut boys = HashMap::new();

    boys.insert(name, age);   // value moved here (name)

    println!("name: {}", name);    // value borrowed here after move
    println!("age: {}", age);
    println!("boys: {:?}", boys);
}
```

name 是 String 类型，它受所有权限制，在 insert 时，其所有权被转移给了 boys，这导致其不能再次被使用！

因此，对于对于受所有权限制的类型，使用其引用，并确保其生命周期和HashMap一致：

```rust
fn main() {
    let name = String::from("Jack");
    let age = 32;

    let mut boys = HashMap::new();

    boys.insert(&name, age); // 使用name的引用，不发生所有权转移

    println!("name: {}", name);
    println!("age: {}", age);
    
    // std::mem::drop(name);  // move out of `name` occurs here
    println!("boys: {:?}", boys);
}
```



#### 2.9.2.3 遍历 HashMap

**通过 get 查询值**:  get 返回一个 `Option<&T>` 类型，查询不到时返回一个None，查询到则返回 `Some(&T)`

```rust
fn main() {
    let mut scores = HashMap::new();
    scores.insert("Jack", 99);
    scores.insert("Sarah", 87);
    scores.insert("Rania", 100);

    let score = scores.get("Rania").copied().unwrap_or(0);
    println!("{score}");
}
```



**遍历 HashMap**:

```rust
fn main() {
    let mut scores = HashMap::new();
    scores.insert("Jack", 99);
    scores.insert("Sarah", 87);
    scores.insert("Rania", 100);

    for (key, value) in scores {
        println!("{key}: {value}");
    }
}
```



#### 2.9.2.4 更新 HashMap

```rust
fn main() {
    let mut scores = HashMap::new();
    scores.insert("Jack", 99);
    scores.insert("Sarah", 87);
    scores.insert("Rania", 100);

    // 覆盖已有的值
    let old = scores.insert("Sarah", 90);
    assert_eq!(old, Some(87));

    // 不存在则插入
    let val = scores.entry("Eli").or_insert(96);
    assert_eq!(*val, 96);

    let val = scores.entry("Eli").or_insert(88);
    assert_eq!(*val, 96);
}
```



示例：单词统计

```rust
fn main() {
    let text = "I have to practice my times tables over and over and over again so I can learn them";
    let mut result = HashMap::new();

    for word in text.split_whitespace() {
        let count = result.entry(word).or_insert(0);
        *count += 1;
    }

    println!("{:?}", result);
}
```



#### 2.9.2.5 哈希函数

一个类型能否作为 Key 的关键在于能否进行相等比较，或者说该类型是否实现了 `std::cmp:Eq` 特征。浮点数 f32 和 f64 均未实现该特征，因此不能作为HashMap的 key。

HashMao 使用的哈希函数是 SipHash，它的性能不是很高，但安全性较高。SipHash 在中等大小的 Key 上，性能相当不错，但对于小型的key(例如整数) 或 大型 key(例如字符串) 来说，其性能不够好。



第三方包：`twox-hash`

```rust
fn test_twox_hash() {
    use std::hash::BuildHasherDefault;
    use std::collections::HashMap;
    use twox_hash::XxHash64;

    let mut hash: HashMap<_, _, BuildHasherDefault<XxHash64>> = Default::default();
    hash.insert(42, "the answer");
    assert_eq!(hash.get(&42), Some(&"the answer"));
}
```



第三方包：`ahash`

```rust
fn test_ahash() {
    use ahash::AHashMap;

    let mut scores = AHashMap::new();
    scores.insert("Jack", 99);
    scores.insert("Sarah", 87);

    println!("{:?}", scores);
}
```



## 2.10 生命周期







- 指针：最底层的是裸指针`*const T`和`*mut T`，但解引用它们是不安全的，必须放到`unsafe`块里。

- 函数：具有函数类型的变量实质上是一个函数指针。

- 元类型：即`()`，其唯一的值也是`()`。



- 





```rust


// string
let s = "hello, world!";       // &str
let s1 = s.to_string();        // String
let s2 = String::from("ok");   // String



// raw pointers
let x = 3;
let raw = &x as *const i32;
let p = unsafe { *raw };
let raw2: *const i32 = &x;
let p2 = unsafe { *raw2 };

// function
fn foo(x: i32) -> i32 { x };
let bar: fn(x: i32) -> i32 = foo;
```

特殊用法：

- 单字节字符 `b'H'`，单字节字符串 `b"hello"`，仅限于ASCII字符
- 原始字符串 `r#"..."#`，不需要对特殊字符进行转义
- 使用 & 将 String 转换为 `&str` 不涉及分配内存，但使用 `to_string()` 将 `&str` 转换为 String 则需要分配内存
- 数组的长度是不可变的，动态的数组称为向量(vector)，可使用宏 `vec!` 来创建
- 元组可通过 == 及 != 来判断是否相同
- 小于等于32个元素的数组、小于等于12个元素的元组，在值传递时自动复制
- 原生类型不支持隐式转换，需要使用 as 关键字显式转换
- type 关键字定义类型的别名，采用驼峰命名法

```rust
// explicit conversion
let decimal = 65.4321_f32;
let integer = decimal as u8;
let character = integer as char;

// type alias
type NanoSecond = u64;
type Point = (u8, u8);
```











## 2.6 注释

- 单行注释：以 // 开始

- 块注释：`/*  */`
- 文档注释：`///` 或 `//!`，支持 Markdown 语法，配合 rustdoc 自动生成说明文档
  - `///` 等价于属性 `#[doc = "..."]`
  - `//!` 等价于 `#[doc = "/// ..."]`







# 4. 模块系统

模块系统：

- 包 Packages：cargo 提供的创建、测试及分享 Crates 的工具。
- 箱 Crates：提供类库或可执行文件的模块树，与其他语言中的library 或 package 作用一样
- 模块 Modules：管理和组织路径，及其作用域和访问权限
- 路径 Paths：结构体、函数、模块等事物的命名方式



## 4.1 Packages & Crates

包(Package) 通过 Cargo 创建，每一个包都有一个 `Cargo.toml` 文件，包中箱(Crates)的规则：

- 只能包含0或1个类库箱(library crates)
- 可以包含任意多个二进制箱(binary crates)

创建二进制包(binary package):

```bash
❯ cargo new my-project
     Created binary (application) `my-project` package
❯ tree my-project
my-project
├── Cargo.toml
└── src
    └── main.rs
```

创建类库包(library package):

```bash
❯ cargo new --lib my-lib
     Created library `my-lib` package
❯ tree my-lib
my-lib
├── Cargo.toml
└── src
    └── lib.rs
```

默认，一个箱(crate):

- src/main.rs 二进制箱(binary crate)的根文件
- src/lib.rs 类库箱(library crate)的根文件

多个二进制箱(binary crates)：在src/bin 目录下创建 `.rs` 文件，每个文件对应一个二进制箱(binary crate)



## 4.2 Moddules

通过关键字 mod 识别

```rust
// Filename: src/lib.rs 

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

文件 src/main.rs 和 src/lib.rs，对应的模块是 crate，箱(crate)的模块结构(module structure)，也叫模块树(module tree)：

```text
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

:warning:模块 crate 默认存在，不需要通过关键字 mod 来定义



## 4.3 Paths

箱(crate)的根节点是 `crate`

- 绝对路径：从箱的根节点开始，箱的名称或crate
- 相对路径：从当前模块开始，可以使用 self 或 super

```rust
// 绝对路径 Absolute path
crate::front_of_house::hosting::add_to_waitlist();

// 相对路径 Relative path
front_of_house::hosting::add_to_waitlist();
```



## 4.4 访问权限

- 所以元素，函数functions、方法methods、结构体structs、枚举enum、模块modules，常量constants，默认都是私有的；对外公开，需要使用关键字 pub 声明
  - 公共结构体(public structs)，内部的元素(fields)和方法(methods)仍是私有的(private)
  - 公共枚举(public enums)，其所有变量(variants)都是公共的(public)
- 父模块中的元素，不能使用子模块中的私有元素
- 子模块中的元素，可以使用父模块元素(不论公有还是私有)



## 4.5 use

使用 use 关键字简化路径 paths

调用其他模块函数，通过 use 引入其所在的模块(module)

```rust
use some_mod;

fn main() {
    some_mod::some_fn();
}
```

调用其他模块结构体、枚举等，通过全路径引入：

```rust
use std::collections::HashMap;

fn main() {
    let mut map = HashMap::new();
    map.insert(1, 2);
}
```

有命名冲突时，引入父模块：

```rust
use std::fmt;
use std::io;

fn function1() -> fmt::Result {
    // --snip--
}

fn function2() -> io::Result<()> {
    // --snip--
}
```

使用 as 解决命名冲突：

```rust
use std::fmt::Result;
use std::io::Result as IoResult;

fn function1() -> Result {
    // --snip--
}

fn function2() -> IoResult<()> {
    // --snip--
}
```

引入同一个模块或包中的多个元素：

```rust
use std::{cmp::Ordering, io};
use std::io::{self, Write};
```

映入模块下所以公共元素(谨慎使用)：

```rust
use std::collections::*;
```



## 4.6 外部包

在 `Cargo.toml` 文件下的 `[dependencies]` 下添加，Cargo 会自动下载所需的依赖包

```toml
[dependencies]
rand = "0.8.5"
```



## 4.7 示例

### 4.7.1 定义模块

**Step 1**：创建 Crate，类型 library

```bash
cargo new phrases --lib

mkdir -p phrases/src/{chinese,english}
```



**Step 2**：函数定义-1

```rust
// src/chinese/greetings.rs
pub fn hello() -> String {
    "你好！".to_string()
}

// src/chinese/farewells.rs
pub fn goodbye() -> String {
    "再见！".to_string()
}

// src/chinese/mod.rs
pub mod greetings;
pub mod farewells;
```



**Step 3**：函数定义-2

```rust
// src/english/greetings.rs
pub fn hello() -> String {
    "Hello!".to_string()
}

// src/english/farewells.rs
pub fn goodbye() -> String {
    "Goodbye".to_string()
}

// src/english/mod.rs
pub mod greetings;
pub mod farewells;
```



**Step 4**：模块定义

```rust
// src/lib.rs
pub mod chinese;
pub mod english;
```



### 4.7.1 导入 Crate

**Step 1**：创建 Crate，类型 binary

```bash
cargo new basic-03 --bin
```



**Step 2**：配置本地依赖

修改 Cargo.toml 文件

```toml
[dependencies]
phrases = { path = "../phrases" }
```



**Step 3**：引用模块

```rust
extern crate phrases;

use phrases::chinese::greetings;
use phrases::chinese::farewells::goodbye;
use phrases::english::greetings::hello as english_greetings;
use phrases::english::farewells::goodbye as english_farewells;

fn main() {
    println!("Hello in chinese: {}", greetings::hello());
    println!("Goodbye in chinese: {}", goodbye());
    println!("Hello in english: {}", english_greetings());
    println!("Goodbye in english: {}", english_farewells());
}
```



## 4.8 属性

在 Rust 中，属性 (attribute) 是应用于包装箱、模块或条目的元数据(metadata)，其主要作用如下：

- 实现条件编译 (conditional compilation)
- 设置包装箱名称、版本及类型
- 取消可疑代码的警告
- 设置编译器选项
- 链接外部库
- 标记测试函数



属性的两个语法：

- `#![attribute ???]` 应用于整个包装箱
- `#[attribute ???]` 应用于紧邻的一个模块或条目



属性参数的三种不同形式：

- `#[attribute = "value"]`
- `#[attribute(key = "value")]`
- `#[attribute(value)]`



常见属性：

- `#[path="foo.rs"]`   设置一个模块需要载入的文件路径
- `#[allow(dead_code)]` 取消对未使用代码的默认lint检查
- `#[derive(PartialEq, Clone)]` 自动推导`PartialEq`和`Clone` 特性的实现
- `#[derive(Debug)]`  支持使用 `println!("{:?}", s)` 打印struct
- `#[derive(Default)]`  struct中的属性使用默认值零值



# 5. 程序测试

## 5.1 测试属性

- `#[test]` 测试属性

- `#[should_panic]` 反转测试失败
- 宏`assert!`接受一个参数，如果为 false，则 panic

```rust
#[test]
fn it_works() {
    assert!(false);
}

#[test]
#[should_panic(expected = "assertion failed")]
fn it_works_2() {
    assert_eq!("hello", "world");
}
```



## 5.2 测试模块

测试模块前添加 `#[cfg(test)]` 属性

```rust
pub fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod test {
    use super::add_two;

    #[test]
    fn it_works() {
        assert_eq!(4, add_two(2));
    }
}
```



## 5.3 测试目录

对于集成测试，可新建一个 tests 目录，这样其中的代码就不需要再引入单元风格的测试模块了



## 5.4 文档测试

```rust
/// This function adds two to its argument.
///
/// # Examples
///
/// ```
/// use phrases::add_two;
///
/// assert_eq!(4, add_two(2));
/// ```
pub fn add_two(a: i32) -> i32 {
    a + 2
}
```



## 5.5 错误处理

Rust 中两种形式的错误：

- 失败(failure)：可通过某种方式恢复
- 恐慌(panic)：不可恢复



通过 `Option<T>` 类型表明函数可能会失败：

```rust
fn from_str<A: FromStr>(s: &str) -> Option<A> {
    
}
```

函数 `from_str()` 返回一个 `Option<A>` ：

- 转换成功，返回 Some(value)
- 转换失败，返回 None

对需要提供出错信息的情形，可使用 `Result<T, E>` 类型

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

如果不想出来错误我，可使用 unwrap() 方法来产生 panic：

```rust
let mut buffer = String::new();
let input = io::stdin().read_line(&mut buffer).unwrap();
```

当 Result 是 Err 时，unwrap() 会 panic，直接退出程序。更好的做法：

```rust
let input = io::stdin().read_line(&mut buffer)
			           .ok()
                       .except("Failed to read line");
```

其中`ok()`将`Result`转换为`Option`，`expect()`和`unwrap()`功能类似，可以用来提供更多的错误信息。

还可以使用宏`try!`来封装表达式，当`Result`是`Err`时会从当前函数提早返回`Err`



# 6. 内存安全

Rust 推崇安全和速度至上，它没有垃圾回收机制，却成功实现了内存安全(memory safety)



## 6.1 所有权

所有权(ownership)系统时零成本抽象(zero-cost abstraction)的一个主要例子。对所有权的分析在编译阶段就完成，并不带来任何运行时成本(run-time cost)

默认情况下，Rust在栈(stack)上分配内存，对栈空间变量的再赋值都是复制的；如果在堆(heap)中分配，则必须使用盒子来构造。

```rust
fn main() {
    let x = Box::new(5);

    add_one(x);

    // error[E0382]: borrow of moved value: `x`
    println!("x: {}", x);
}

fn add_one(mut n: Box<i32>) {
    *n += 1;
}
```

`Box::new()` 创建了一个 `Box<i32>` 来存储整数 5，此时变量 x 具有该盒子的所有权。当 x 退出代码块的作用域时，它所分配的内存资源将随之释放，上述操作由编译器自动完成。

调用 `add_one()` 时，变量 x 的所有权被转移(move)给了变量 n (所有权转移时，可变性也随之发生变化)。`add_one()`执行完成后，n 占用的内存将自动释放。

当 `println!` 再次使用已经没有所有权变量 x 时，编译器将会报错。

解决方法：

- 修改 `add_one()` 函数使其返回 Box，将所有权转移回来
- **引入所有权借用(borrowing)**



## 6.2 借用

在 Rust 中，所有权的借用通过引用 `&` 来实现：

```rust
fn main() {
    let mut x= 5;

    add_one(&mut x);

    println!("x: {}", x);
}

fn add_one(n: &mut i32) {
    *n += 1
}
```

调用 `add_one()` 时，变量 `x` 把它的所有权以**可变引用**借给了变量 n，函数完成后，n 又把所有权还给了 x。如果以不可变引用借出，则借出者只能读而不能改。

借用需要注意点：

- 变量、函数、闭包以结构体都可以成为借用者
- 一个资源只能有一个所有者，但可以有多个借用者
- 资源**以可变借出，所有者将不能再次访问资源，也不能再借给其他绑定**
- 资源**以不可变借出，所有者不能再改变资源，也不能再以可变形式借出，但可以以不变形式继续借出**



## 6.3 生存期

通过生存期(lifetime)来确定一个引用的作用域：

```rust
struct Foo<'a, 'b> {
    x: &'a i32,
    y: &'b i32,
}

fn test_lifetime() {
    let a = &5;
    let b = &8;
    let f = Foo{x: a, y: b};

    println!("{}", f.x + f.y);
}
```

结构体 Foo 有自己的生存期，需要给它的所包含的域治的新的生存期 `'a` 和`'b`，确保对 i32 的引用比 对 Foo 的引用具有更长的生存期，避免悬空指针(dangling pointer) 问题



Rust 预定义的 `'static` 具有和整个程序运行时相同的生存期，主要用于声明全局变量。常量(const) 也具有 `'static` 生存期，但它们会被内联到使用它们的地方。

```rust
const N: i32 = 5;

static NUML i32 = 5;
static NAME: &'static str = "Jack";
```

使用生存期时，类型标注不可省略，并且必须使用常量表达式初始化。

通过 `static mut` 绑定的变量，则只能再 unsafe 代码块中使用。



共享所有权，需要使用标准库的 `Rc<T>` 类型：

```rust
use std::rc::Rc;

struct Car {
    name: String,
}

struct Wheel {
    size: i32,
    owner: Rc<Car>,
}

fn main() {
    let car = Car{name: "DeLorean".to_string() };

    let car_owner = Rc::new(car);

    for _ in 0..4 {
        Wheel{size: 360, owner: car_owner.clone()};
    }
}
```

如果再并发中共享所有权，则需要使用线程安全的 `Arc<T>` 类型。

Rust 支持生存周期省略(lifetime elision)，它允许在特定情况下不写生存周期标记，此时会遵循三条规则：

- 每个被省略生存期标记的函数参数具有各不相同的生存期
- 如果只有一个输入生存期(input lifetime)，那么不管它是否省略，该生存期都会赋给函数返回值中所有被省略的生存期
- 如果有多个输入生存期，并且其中一个是 `&self` 或 `mut self` ，那么 self 的生存期会赋给所有被省略的输出生存期(output lifetime)



# 7. 编程范式

Rust 是一个多范式(multi-paradigm) 的编译型语言，支持结构化、命令式编程外，还支持如下范式

## 7.1 函数式编程

使用闭包(closure)创建匿名函数：

```rust
fn main() {
    let num = 5;
    let plus_num = |x: i32| x+num;

    println!("{}", plus_num(3));
}
```

其中，闭包 `plus_num` 借用了它作用域中 的 let 绑定 num。

如果要让闭包获得所有权，可使用 move 关键字：

```rust
fn main() {
    let mut num = 5;

    {
        let mut add_num = move |x: i32| num += x;
        add_num(3);
        println!("{num}") // 5
    }

    assert_eq!(num, 5)
}
```



高级函数(high order function)，允许把闭包作为参数来生成新的函数：

```rust
fn add_one(x: i32) -> i32 { x + 1 }

fn apply<F>(f: F, y: i32) -> i32
    where F: Fn(i32) -> i32 {
    f(y) * y
}

fn factory(x: i32) -> Box<dyn Fn(i32) -> i32> {
    Box::new(move |y| x+y)
}

fn main() {
    let transform: fn(i32) -> i32 = add_one;
    let f0 = add_one(2) * 2;
    let f1 = apply(add_one, 2);
    let f2 = apply(transform, 2);
    println!("{}, {}, {}", f0, f1, f2);

    let closure = |x: i32| x + 1;
    let c0 = closure(2) * 2;
    let c1 = apply(closure, 2);
    let c2 = apply(|x| x + 1, 2);
    println!("{}, {}, {}", c0, c1, c2);

    let box_fn = factory(1);
    let b0 = box_fn(2) * 2;
    let b1 = (*box_fn)(2) * 2;
    let b2 = (&box_fn)(2) * 2;
    println!("{}, {}, {}", b0, b1, b2);

    let add_num = &(*box_fn);
    let translate: &dyn Fn(i32) -> i32 = add_num;
    let z0 = add_num(2i32) * 2;
    let z1 = apply(add_num, 2);
    let z2 = apply(translate, 2);
    println!("{}, {}, {}", z0, z1, z2);
}
```



## 7.2 面向对象编程

Rust 通过 `impl` 关键字在 `struct`、`enum` 及 `trait` 对象上实现方法调用语法(method call syntax)。

关联函数(associated function)的第一个参数通常为 self，有三种变体：

- `self` 允许实现者移动和修改对象，对应的闭包特性为 `FnOnce`
- `&self` 既不允许实现者移动对象也不允许修改，对应的闭包特性为 `Fn`
- `&mut self` 允许实现者修改但不允许移动，对应的闭包特性为 `FnMut`

不含 self 参数的关联函数称为静态方法(static method)

```rust
struct Circle {
    x: f32,
    y: f32,
    radium: f32,
}

impl Circle {
    fn new(x: f32, y: f32, radium: f32) -> Circle {
        Circle {x, y, radium}
    }

    fn area(self) -> f32 {
        std::f32::consts::PI * self.radium * self.radium
    }
}

fn main() {
    let c = Circle::new(0.0, 0.0, 5.0);
    println!("{}", c.area())
}
```



为了描述类型可以实现的抽象接口(abstract interface)，Rust引入了特性 (trait) 来定义函数类型签名 (function type signature):

```rust
trait HasArea {
    fn area(&self) -> f64;
}

struct Circle {
    x: f64,
    y: f64,
    radium: f64,
}

impl HasArea for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radium * self.radium
    }
}

struct Square {
    x: f64,
    y: f64,
    side: f64,
}

impl HasArea for Square {
    fn area(&self) -> f64 {
        self.side * self.side
    }
}

fn print_area<T: HasArea>(shape: T) {
    println!("This shape has an area of {}", shape.area())
}

fn main() {
    let c = Circle{x: 0.0, y: 0.0, radium: 3.0};
    print_area(c);

    let s = Square{x: 0.0, y: 0.0, side: 5.0};
    print_area(s);
}
```

其中，函数 `print_area()` 中的泛函参数 T 被添加了一个名为 HasArea 的特性约束 (trait constraint)，用以确保任何实现了 HasArea 的类型将拥有一个 `.area()` 方法。

如果需要多个特性限定(multiple trait bounds)，可以使用 `+`:

```rust
fn foo<T: Clone, K: Clone + Debug>(x: T, y: K) {
    let _ = x.clone();
    let _ = y.clone();
    println!("{:?}", y)
}

fn bar<T, K>(x: T, y: K)
    where T: Clone,
          K: Clone + Debug {
    let _ = x.clone();
    let _ = y.clone();
    println!("{:?}", y)
}
```

其中第二个例子使用了更灵活的 where 从句，它允许限定的左侧可以是任意类型，而不仅仅是类型参数。

定义在特性中的方法称为默认方法(default method)，可以被该特性的实现覆盖。此外，特性之间也可以存在继承(inheritance)：

```rust
trait Foo {
    fn foo(&self);

    // default method
    fn bar(&self) { println!("we called bar") }
}

trait FooBar: Foo {
    fn foobar(&self);
}

struct Baz;

impl Foo for Baz {
    fn foo(&self) {
        println!("foo")
    }
}

impl FooBar for Baz {
    fn foobar(&self) {
        println!("foobar")
    }
}

fn main() {
    let baz = Baz{};

    baz.foo();
    baz.bar();
    baz.foobar()
}
```

如果两个不同特性的方法具有相同的名称，可以使用通用函数调用语法(universal function call syntax)：

```rust
// short-hand form
Trait::method(args);

// expanded form
<Type as Trait>::method(args);
```

实现特性的几条限制：

- 如果一个特性不在当前作用域内，它就不能被实现
- 不管是特性还是 impl，都只能在当前的包装箱内起作用
- 带有特性约束的泛型函数使用单态(monomorphization)，所以它是静态派发的(statically dispatched)

常见非常有用的标准库特性：

- `Drop` 提供了当一个值退出作用域执行代码的功能，它只有一个 `drop(&mut self)` 方法。
- `Borrow` 用于创建一个数据结构时把拥有和借用的值看作等同。
- `AsRef` 用于在泛型中包一个值转换为引用。
- `Deref<Target=T>` 用于把 `&U` 类型的值自动转换为 `&T` 类型
- `Interator` 用于在集合(collection) 和懒性值生成器(lazy value generator) 上实现迭代器
- `Sized` 用于标记运行时长度固定的类型，而不定长的切片和特性必须放在指针后面使其运行时长度已知，比如 `&[T]` 和 `Box<Trait>`



## 7.3 元编程

泛型(generics)也被称为参数多态(parametric polymorphism)，意味着对应给定参数可以有多种形式的函数或类型。

```rust
enum Option<T> {
    Some(T),
    None,
}

let x: option<i32> = Some(5);
let y: Option<f64> = Some(5.0f64);
```

其中 `<T>` 部分表明它是一个泛型数据类型。

泛型参数用于函数参数和结构体域：

```rust
// generic functions
fn make_pair<T, U>(a: T, b: U) -> (T, U) {
    (a, b)
}

let couple = make_pair("man", "female");

// generic structs
struct Point<T> {
    x: T,
    y: T,
}

let int_origin = Point { x: 0, y: 0 };
let float_origin = Point{ x: 0.0, y: 0.0 };
```



对于多态函数，存在两种派分(dispath)机制：

- 静态派分：类似C++的模板，Rust会生成适用于指定类型的特殊函数，然后在被调用的位置进行替换，好处是允许函数被内联调用，运行比较快，但是会导致代码膨胀(code bloat)
- 动态派分：类型Java或Go的 interface，Rust通过引入特性对象(trait object)来实现，在运行时查找虚表(vtable)来选择执行的方法。特性对象 `&Foo` 具有和特性 `Foo` 相同的名称，通过转换 (casting) 或者强制多态化 (coercing) 一个指向具体类型的指针来创建。



特性也可以接受泛型参数，但更好的处理方式是使用关联类型 (associated type)：

```rust
// use generic parameters
trait Graph<N, E> {
    fn has_edge(&self, &N, &N) -> bool;
    fn edges(&self, &N) -> Vec<E>;
}

fn distance<N, E, G: Graph<N, E>>(graph: &G, start &N, end: &N) -> u32 {
    
}

// use associated types
trait Graph {
    type N;
    type E;
    
    fn has_edge(&self, &Self::N, &Self::N) -> bool;
    fn edges(&self, &Self::N) -> Vec<Self::E>;
}

fn distance<G: Graph>(graph: &G, start: &G::N, end: &G::N) -> uint {
    
}

struct Node;

struct Edge;

struct SimpleGraph;

impl Graph for SimpleGraph {
    type N = Node;
    type E = Edge;
    
    fn has_edge(&self, n1: &Node, n2: &Node) -> bool {
        
    }
    
    fn edges(&self, n: &Node) -> Vec<Edge> {
        
    }
}

let graph = SimpleGraph;
let object = Box::new(graph) as Box<Graph<N=Node, E=Edge>>;
```



Rust 中的宏 (macro) 是在语法级别上的抽象，`vec!` 宏的实现：

```rust
macro_rules! vec {
    ( $( $x:expr ), * ) => {
        {
            let mut temp_vec = Vec::new();
            $(
            	temp_vec.push($x);
            )*
            temp_vec
        }
    };
}
```

解析：

- `=>`左边的 `$x:expr` 模式是一个匹配器 (matcher)， `$x` 是元变量  (metavariable)， `expr` 是片段指定符 (fragment specifier)。匹配器写在 `$(...)` 中，`*` 会匹配0或多个表达式，表达式之间的分隔符为逗号。
- `=>` 右边的外层大括号只是用来界定整个右侧结构的，也可以使用`()` 或  `[]`，左边的外层小括号也类似。扩展中的重复域匹配器中的重复会同步进行：每个匹配的`$x` 都会在宏扩展中产生一个单独的 `push` 语句。



## 7.4 并发计算

Rust 提供两个特性来处理并发(concurrency)：`Send` 和 `Sync`。

当一个 `T` 类型：

- 实现 `Send`，该类型的所有权可以在进程间安全地转移；
- 实现 `Sync`，该类型在多线程并发时能够确保内存安全；

标准库 `std::thread` 并发执行：

```rust
use std::thread;

fn main() {
    let handle = thread::spawn(|| {
        println!("Hello from a thread");
    });

    println!("{:?}", handle.join().unwrap())
}
```



解决可变状态的共享问题，通过所有权系统来帮助排除数据竞争 (data race)：

```rust
use std::sync::{Arc, mpsc, Mutex};
use std::thread;

fn main() {
    let data = Arc::new(Mutex::new(0u32));

    // Creates a shared channel that can be sent along from many threads
    // where tx is the sending half
    // and rx is the receiving half
    let (tx, rx) = mpsc::channel();

    for i in 0..10 {
        let (data, tx) = (data.clone(), tx.clone());

        thread::spawn(move || {
            let mut data = data.lock().unwrap();
            *data += i;

            tx.send(*data).unwrap();
        });
    }

    for _ in 0..10 {
        print!("{:?} ", rx.recv().unwrap());
    }
}
```

类型说明：

- `Arc<T>` 类型是一个原子引用计数指针 (atomic reference counted pointer) ，实现了`Sync`，可安全地跨线程共享。 
- `Mutex<T>`  类型提供了互斥锁 (mutex's lock)，同一时间只允许一个线程能修改它的值。
- `mpsc::channel()`  方法创建了一个通道 (channel)，来发送任何实现了 `Send` 的数据。
- `Arc<T>` 的 `clone()` 方法用来增加引用计数，而当离开作用域时，计数减少。



# 8. 高级主题

## 8.1 FFI

### 8.1.1 调用C库

在 Rust 中，通过外部函数接口（foreign function interface）可以直接调用C语言库

**Step 1**：Cargo.toml

```toml
...
build = "build.rs"

[dependencies]
libc = "0.2"

[build-dependencies]
cc = "1.0"
```



**Step 2**：build.rs

```rust
extern crate cc;

fn main() {
    cc::Build::new()
        .file("src/double.c")
        .compile("libdouble.a");
}
```



**Step 3**：src/double.c

```c
int double_input(int input) {
    return input * 2;
}
```



**Step 4**：src/main.rs

```rust
extern crate libc;
use libc::c_int;

extern {
    fn double_input(input: c_int) -> c_int;
}

fn main() {
    let input = 4;
    let output = unsafe{ double_input(input) };
    println!("{} * 2 = {}", input, output);
}

```



### 8.1.2 编译成C库

**Step 1**: Cargo.toml

增加：

```toml
[lib]
name = "fibonacci"
crate-type = ["dylib"]
```



**Step 2**: src/lib.rs

```rust
#[no_mangle]
pub extern fn fibonacci(n: i64) -> i64 {
    if n < 2 {
        return 1
    }

    return fibonacci(n-2) + fibonacci(n-1);
}
```



**Step 3**: src/main.py

```python
from ctypes import cdll
from sys import platform

if platform == 'darwin':
    prefix = 'lib'
    ext = 'dylib'
elif platform == 'win32':
    prefix = ''
    ext = 'dll'
else:
    prefix = 'lib'
    ext = 'so'

lib = cdll.LoadLibrary('target/debug/{}fibonacci.{}'.format(prefix, ext))
fibonacci = lib.fibonacci

num = 45
result = fibonacci(num)
print('fibonacci({}) = {}'.format(num, result))
```



**Step 4**: Makefile

```makefile
ifeq ($(shell uname),Darwin)
    EXT := dylib
else
    ifeq ($(OS),Windows_NT)
        EXT := dll
    else
        EXT := so
    endif
endif

all: target/debug/libfibonacci.$(EXT)
	python src/main.py

target/debug/libfibonacci.$(EXT): src/lib.rs Cargo.toml
	cargo build

clean:
	rm -rf target
```



执行测试：

```bash
> make all
cargo build
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
python src/main.py
fibonacci(45) = 1836311903
```







标准输入读取并转换：

```rust
// 读取
    io::stdin().read_line(&mut index).expect("Failed to read line.");

    // 转换为数字
    let index: usize = index.trim().parse().expect("Index entered was not a number.");
```













