# 1. Sized 约束

在 Rust 中，绝大多数类型在编译期必须又固定的大小 (Sized)

```rust
u32   // 4 bytes
i64   // 8 bytes

struct Point { x: i32, y: i32 }   // 8 bytes
```

编译器需要知道类型的大小，才能在栈上分配空间。

编译器会字段给泛型类型加上 `Sized` 约束，普通泛型 `T` 默认要求是  `Sized` 类型：

```rust
fn foo<T>(x: T) {}

// 编译器自动增加 Sized 约束
fn foo<T: Sized>(x: T) {}
```



# 2. 非 Sized 类型

动态大小类型 (DST, Dynamically Sized Type) 在编译期大小不确定，因此不是 `Sized`：

- `str`  长度只在运行时确定
- `[T]` 切片，长度不定
- trait 对象，如 `dyn MyTrait`，背后大小不定

这些类型不能直接放在栈上，必须通过引用或智能指针使用：

```rust
let s: str;          // 编译错误，大小未知
let s: &str;         // 通用引用间接使用
```



# 3. `?Sized`

`?Sized` 允许这个类型可能是 `Sized`，也可能不是 `Sized`

它常用在**泛型参数**上，让函数或结构体支持处理 DST：

```rust
fn foo<T: ?Sized>(x: &T) {}
```

根据 `T` 的具体类型来确定：

- Sized (如 `i32`、`String`)，`&T` 是正常引用
- `str`、`[u8]` 或 `dyn Trait`，`&T` 是胖指针 (带元数据)



# 4. Borrow 中使用 `?Sized`

```rust
pub trait Borrow<Borrowed>
where
	Borrowed: ?Sized,
{
    fn borrow(&self) -> &Borrowed;
}
```

原因：

- 借用的目标类型 (`Borrowed`) 可能是切片 `[T]`、`str` 或 `dyn Trait`

- 如果不加 `?Sized`，`Borrowed` 默认加上 `Sized` 约束，将不能实现：

  ```rust
  impl Borrow<str> for String {}
  impl<T> Borrow<[T]> for Vec<T> {}
  ```

  





























