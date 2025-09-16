# 1. Borrow trait

Borrow trait 让集合支持**跨类型查找**，但又不丢失哈希、比较一致性，比如 `HashMap`、`BTreeMap` 的 key 查询时。

Borrow 定义在 `std::borrow::Borrow`：

```rust
pub trait Borrow<Borrowed>
where
	Borrowed: ?Sized,
{
    fn borrow(&self) -> &Borrowed;
}
```

- **泛型参数 `Borrowed`**：要借用成的目标类型，可以是一个具体类型 (如 `str`) 或动态大小类型 (如 `?Sized` 允许 `str`)
- **核心思想**：用于在 **逻辑等价** 的不同类型之间建立 “借用关系”，而不仅仅是物理上的引用。比如 `String` 和 `str`
  - `String` 拥有所有权
  - `str` 切片引用
  - `String` 实现了 `Borrow<str>`，这样 `&String`  可以“借用”成 `&str`

它和普通的 `AsRef` 很像，但设计目标不同：

| Trait    | 语义                                               | 场景                                           |
| -------- | -------------------------------------------------- | ---------------------------------------------- |
| `AsRef`  | 只要求可以无开销地转换成某个引用类型               | I/O API、通用函数参数                          |
| `Borrow` | 要保证**借用结果在`Eq`/`Hash`/`Ord` 等比较上等价** | 容器查找、键比较 (`HashMap`/`BTreeMap` 的 key) |



**等价性保证**，`Borrow` 有额外的约束：

如果 `a.borrow() == b.borrow()`，那么 `a` 和 `b` 在逻辑上必须等价 (`Eq` / `Hash` / `Ord` 一致)，这样才能安全用于集合查找



# 2. 实现原理

```rust
use std::collections::HashMap;

let mut map: HashMap<String, i32> = HashMap::new();
map.insert("hello".to_string(), 42);

// 用 &str 查找 String 类型的 key
assert_eq!(map.get("hello"), Some(&42));
```

为什么 `map.get("hello")` 能编译？

- `HashMap::get` 的签名如下：

  ```rust
  pub fn get<Q: ?Sized>(&self, k: &Q) -> Option<&V>
  where
  	K: Borrow<Q>,
  	Q: Hash + Eq,
  ```

- 这里 `K = String`，`Q = str`，在标准库中：

  ```rust
  impl Borrow<str> for String {
      fn borrow(&self) -> &str {
          self.as_str()
      }
  }
  ```

- 编译器发现：

  - `String: Borrow<str>`
  - `str: Hash+ Eq`

- 所以 `&str` 也可以用来查找 `String` key 的 `HashMap`



# 3. 使用示例

## 3.1 `String` 和 `str`

```rust
use std::borrow::Borrow;
use std::collections::HashMap;

fn main() {
    let mut map: HashMap<String, i32> = HashMap::new();
    map.insert("apple".to_string(), 5);
    
    // 直接用 &str 查找 String key
    let count = map.get("apple").unwrap();
    println!("count = {}", count);
    
    // 手动调用 Borrow
    let s: String = "hello".to_string();
    let slice: &str = s.borrow();
    println!("{}", slice);
}
```



调用关系链：

```rust
map.get("apple")          // 类型：&str

↓ （编译器匹配 HashMap::get 的泛型约束）
HashMap<K=String, V>::get<Q>(&self, k: &Q) -> Option<&V>
where
    K: Borrow<Q>,         // String 必须实现 Borrow<str>
    Q: Hash + Eq

↓
String::borrow(&self) -> &str
    // 标准库实现：
    impl Borrow<str> for String {
        fn borrow(&self) -> &str {
            self.as_str()
        }
    }

↓
HashMap 内部调用：
1. 对 key 进行 hash 计算：
   hash(k.borrow())   // 这里 k 是 &str
2. 根据 hash 值定位到桶
3. 桶里每个 key 也调用 key.borrow() -> &str 进行 Eq 比较

↓
返回匹配的 value 引用
```



关键点：

- `Borrow` 在 **查找参数** 和 **容器中存的key** 上都会被调用一次：

  - 查找参数 `k.borrow()` => 生成比较/哈希所需的引用类型
  - 容器中每个 `key.borrow()` => 确保比较双方类型一致

- `Hash` 和 `Eq` 都基于 `borrow()` 的返回类型来执行，这是它能保证跨类型查找结果一致的关键

- 这种设计使得：

  ```
  HashMap<String, V>   可以用 &str 查找
  HashSet<Vec<u8>>     可以用 &[u8] 查找
  BTreeMap<Box<K>>     可以用 &K 查找
  ```

  

## 3.2 自定义类型跨类型查找

```rust
use std::borrow::Borrow;
use std::collections::HashSet;

#[derive(Hash, Eq, PartialEq, Debug)]
struct UserId(String);

#[derive(Hash, Eq, PartialEq, Debug)]
struct Username(String);

// 让 UserId 借用成 str
impl Borrow<str> for UserId {
    fn borrow(&self) -> &str {
        &self.0
    }
}

fn main() {
    let mut users: HashSet<UserId> = HashSet::new();
    users.insert(UserId("alice".into()));
    users.insert(UserId("bob".into()));
    
    // 直接用 &str 查找
    assert!(users.contains("alice"));
    assert!(!users.contains("carol"));
}
```



## 3.3 自定义 `Borrow` 改变容器比较逻辑

```rust
use std::borrow::Borrow;
use std::collections::HashSet;

#[derive(Debug)]
struct CaseInsensitive(String);

impl Borrow<str> for CaseInsensitive {
    fn borrow(&self) -> &str {
        &self.0
    }
}

impl PartialEq for CaseInsensitive {
    fn eq(&self, other: &Self) -> bool {
        self.0.eq_ingore_ascii_case(&other.0)
    }
}

impl Eq for CaseInsensitive {}

impl std::hash::Hash for CaseInsensitive {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.0.to_lowercase().hash(state);
    }
}

fn main() {
    let mut set: HashSet<CaseInsensitive> = HashSet::new();
    set.insert(CaseInsensitive("Hello".into()));
    
    assert!(set.contains("hello"));
}
```



# 4. 总结

- `Borrow` 用于跨类型借用，尤其是集合查找时让 `&T` 能当作 `&U` 用
- 它要求借用后的类型在 `Eq` / `Hash` / `Ord` 等比较上保持一致
- 场景内置实现：
  - `String: Borrow<str>`
  - `Vec<T>: Borrow<[T]`
  - `Box<T>: Borrow<T>`
- 自定义类型可以实现 `Borrow`，从而让集合支持不同但等价的 key 查找









































