# 1. Clone trait

Clone是一个普通的 trait，它包含了一个方法：clone，该方法用于创建新的副本。

几乎所有类型都可以实现 Clone trait。只要能够定义如何创建一个新的副本，就可以实现 Clone trait.

为什么需要 Clone trait？

- Clone trait 允许显式地复制类型的值，但那些不能按位复制的类型非常有用，例如指针或引用类型
- Clone trait 还允许自定义复制行为，可以在 clone 方法中添加任何逻辑，以便在复制时执行特定的操作

**实现 Clone trait：**

```rust
// 自动实现
#[derive(Clone)]
struct Point {
    x: i32,
    y: i32,
}

// 手动实现
impl Clone for Point {
    fn clone(&self) -> Self {
        Self { x: self.x, y: self.y }
    }
}
```



# 2. Copy trait

Copy 时一个标记 trait，它没有任何方法，只用来标记一个类型可以按位复制。

当一个类型实现了 Copy trait 时，它的值可以在赋值、传参和返回值时自动复制。

什么类型可以实现 Copy trait？

- POD (Plain Old Data) 类型，即不包含任何指针和引用
- 类型的所有字段都实现了 Copy

**包含引用字段的类型，不能实现 Copy**：

```rust
struct Foo<'a> {
    x: &'a i32,
}

// error[E0204]: the trait `Copy` may not be implemented for this type
impl Copy for Foo<'_> {}
```

**所有实现了 Copy 的类型，都必须实现 Clone**：

```rust
#[derive(Copy, Clone)]
struct Point {
    x: i32,
    y: i32,
}
```

为什么需要 Copy trait？

- Copy trait 允许控制类型的复制行为，当一个类型实现了它时，其值可以在赋值、传参和返回值时自动复制。这样可以避免显示调用 clone 方法来复制值
- Copy 类型的值总是按位复制，它们复制开销很小，对提高程序性能非常有帮助



# 3. 总结

Copy 和 Clone trait 都用于控制类型的复制行为，它们之间有如下区别：

- Copy 是一个标记 trait，它表示一个类型可以按位赋值。当一个类型实现了 Copy trait 时，它的值可以在赋值、传参和返回值时自动复制
- Clone 时一个普通 trait，它包含一个方法 clone。当一个类型实现了 Clone trait 时，可以调用它的 clone 方法来显示创建一个新的副本。
- 实现了 Copy 的类型必须实现 Clone

示例代码：

```rust
#[derive(Copy, Clone)]
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p1 = Point { x: 1, y: 2 };
    let p2 = p1;          // 自动复制
    let p3 = p1.clone();  // 显式复制
}
```





























## 1.2 

