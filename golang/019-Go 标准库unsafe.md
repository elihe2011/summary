# 1. unsafe

Go是强类型语言，不允许不同类型的指针互相转换。但它提供unsafe包作为中间媒介，快速实现类型转换，但该转换是不安全的。



## 1.1 指针类型

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/unsafe_pointer.png)



**`*T`**：

- 不能进行数学运算
- 不同类型的指针，不能相互转换
- 不同类型的指针不能使用 == 或 != 比较
- 不同类型的指针变量不能相互赋值



**unsafe.Pointer**:

```go
type ArbitraryType int
type Pointer *ArbitraryType
```



**uintptr**: Go的内置类型，能存储指针的整型，与普通指针区别如下

```go
type uintptr uintptr
```

- 普通指针不可以参与计算，但`uintptr`可以。
- 普通指针和`uintptr`之间必选进行强制转换。
- GC 不会把`uintptr`当成指针，由`uintptr`变量表示的地址处的数据也可能被GC回收。



## 1.2 主要方法

```go
type ArbitraryType int
type Pointer *ArbitraryType

// 返回类型所占内存大小
func Sizeof（variable ArbitraryType）uintptr  

// 返回类型的对齐值, 等价于reflect.TypeOf(x).Align()
func Alignof（variable ArbitraryType）uintptr

// struct结构体中的字段相对于结构体的内存位置偏移量。结构体的第一个字段的偏移量都是0.
// 等价于reflect.TypeOf(u1).Field(i).Offset
func Offsetof（selector ArbitraryType）uintptr
```



# 2. 指针转换

## 2.1 int32指针指向int64数据

```go
func main() {
	var n int64 = 5
	var p1 = &n
	var p2 = (*int32)(unsafe.Pointer(p1))

	// 类型虽然不一样，但指向同一个地址
	fmt.Printf("p1=%v, p2=%v\n", p1, p2)

	*p2 = 10
	fmt.Printf("n=%v, *p1=%v, *p2=%v\n", n, *p1, *p2)

	// *p2 越界
	*p1 = math.MaxInt32 + 1
	fmt.Printf("n=%v, *p1=%v, *p2=%v\n", n, *p1, *p2)
}
```



## 2.2  遍历数组元素

```go
func main() {
	a := [...]int{4, 7, 2, 9, 5}
	p := &a[0]
	fmt.Printf("%p: %v\n", p, *p)

	for i := 1; i < len(a); i++ {
		ptr := uintptr(unsafe.Pointer(p)) + unsafe.Sizeof(a[0])
		p = (*int)(unsafe.Pointer(ptr))
		fmt.Printf("%p: %v\n", p, *p)
	}
}
```



# 3. 类型对齐值

```go
func main() {
	var b bool
	var i int
	var i64 int64
	var f float32
	var f64 float64

	var s string
	var m map[int]string  // 固定8
	var a []int

	var p *int32

	fmt.Println(unsafe.Alignof(b))   // 1
	fmt.Println(unsafe.Alignof(i))   // 8
	fmt.Println(unsafe.Alignof(i64)) // 8
	fmt.Println(unsafe.Alignof(f))   // 4
	fmt.Println(unsafe.Alignof(f64)) // 8
	fmt.Println(unsafe.Alignof(s))   // 8
	fmt.Println(unsafe.Alignof(m))   // 8
	fmt.Println(unsafe.Alignof(a))   // 8
	fmt.Println(unsafe.Alignof(p))   // 8
}
```



# 4. 修改私有成员

结构体(struct)，可以通过offset函数获取成员的偏移量，进而获取成员的地址。读写该地址的内存，就可以达到改变成员值的目的

结构体内存分配：会被分配一块连续的内存，结构体的地址也代表了第一个成员的地址。

```go
type User struct {
	name string
	age  int
}

func main() {
	user := User{"eli", 29}

	name := (*string)(unsafe.Pointer(&user))
	*name = "rania"

	age := (*int)(unsafe.Pointer(uintptr(unsafe.Pointer(&user)) + unsafe.Offsetof(user.age)))
	*age = 20

	fmt.Println(user)
}
```



# 5. 获取slice的长度

```go
// runtime/slice.go
type slice struct {
  array unsafe.Pointer  // offset=8
  len int
  cap int
}

func makeslice(et *_type, len, cap int) slice
```


```go
func main() {
	s := make([]int, 5, 10)
	fmt.Printf("%p\n", &s)

	Len := (*int)(unsafe.Pointer(uintptr(unsafe.Pointer(&s)) + uintptr(8)))
	fmt.Printf("Len=%d, len(s)=%d\n", *Len, len(s))

	Cap := (*int)(unsafe.Pointer(uintptr(unsafe.Pointer(&s)) + uintptr(16)))
	fmt.Printf("Cap=%d, cap(s)=%d\n", *Cap, cap(s))
}
```



# 6. 获取map长度

```go
type hmap struct {
  count int
  flags uint8
  B uint8
  noverflow uint16
  hash0 uint32
  
  buckets unsafe.Pointer
  oldbuckets unsafe.Pointer
  nevacuate uintptr
  
  extra *mapextra
}

// 注意返回的是指针
func makemap(t *maptype, hint int64, h *hmap, bucket unsafe.Pointer) *hmap
```


```go
func main() {
	mp := make(map[string]int)
	mp["a"] = 21
	mp["z"] = 45

	count := **(**int)(unsafe.Pointer(&mp)) // 二级指针
	fmt.Println(count, len(mp)) // 2 2
}
```



# 7. string和[]byte的零拷贝转换

slice和string的底层数据结构：

```go
type StringHeader struct {
  Data uintptr
  Len int
}

type SliceHeader struct {
  Data uintptr
  Len int
  Cap int
}

func string2bytes(s string) []byte {
	stringHeader := (*reflect.StringHeader)(unsafe.Pointer(&s))

	bh := reflect.SliceHeader{
		Data: stringHeader.Data,
		Len:  stringHeader.Len,
		Cap:  stringHeader.Len,
	}

	return *(*[]byte)(unsafe.Pointer(&bh))
}

func bytes2string(b []byte) string {
	sliceHeader := (*reflect.SliceHeader)(unsafe.Pointer(&b))

	sh := reflect.StringHeader{
		Data: sliceHeader.Data,
		Len:  sliceHeader.Len,
	}

	return *(*string)(unsafe.Pointer(&sh))
}
```

