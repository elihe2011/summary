@[TOC](Golang 标准库 reflect)



# 1. 概念

## 1.1 什么是反射

反射：在运行时，**动态获取对象的类型和内存结构**

反射操作所需要的全部信息都源自接口变量，接口变量除了存储自身类型外，还会保存实际对象的类型数据

将任何传入的对象转换为接口类型：

```go
func TypeOf(o interface{}) Type
func ValueOf(o interface{}) Value
```

## 1.2 反射的三大定律

1. 反射可以将 **“接口类型变量”** 转换为 **“反射类型对象”** (Reflection goes from interface value to reflection object.)

2. 反射可以将 **“反射类型对象”** 转换为 **“接口类型变量”** (Reflection goes from reflection object to interface value.)

3. 如果要修改 **“反射类型对象”** 其类型必须是 **可写的** (To modify a reflection object, the value must be settable.)


### 1.2.1 第一定律

**“接口变量”** => **“反射对象”**

- reflect.TypeOf(i): 获取接口值的类型 (*reflect.rtype)
- reflect.ValueOf(i): 获取接口值的值  (reflect.Value)

![reflect_1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/reflect_1.png)


### 1.2.2 第二定律

**“反射对象”** => **“接口变量”** 

![reflect_2](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/reflect_2.png)

**注意：只有Value才能逆向转换，Type则不行**

```go
func (v Value) Interface() (i interface{}) {
	return valueInterface(v, true)
}
```

**第一和第二定律综合：**

![reflect_1_2](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/reflect_1_2.png)


### 1.2.3 第三定律

要修改反射对象，其值必须可写的。

- 非指针变量创建的反射对象，不可写
- CanSet()返回true，为可写对象
- 不可写对象，无法进行写操作
- 可写对象，使用Elem()函数返回指针指向的数据

```go
func main() {
	s := "abc"

	v1 := reflect.ValueOf(s)
	fmt.Println(v1.CanSet()) // false

	v2 := reflect.ValueOf(&s)
	fmt.Println(v2.CanSet()) // false

	v3 := v2.Elem()          // 只有引用类型，才有Elem()方法
	fmt.Println(v3.CanSet()) // true
}
```

可写对象的相关方法：

```go
Set(x Value)
SetBool(x bool)
SetBytes(x []byte)
setRunes(x []rune)
SetComplex(x complex128)
SetFloat(x float64)
SetInt(x int64)
SetLen(n int)
SetCap(n int)
SetMapIndex(key Value, elem Value)
SetUint(x uint64)
SetPointer(x unsafe.Pointer)
SetString(x string)
```


# 2. 类型(Type)

```go
func TypeOf(i interface{}) Type {
  eface := *(*emptyInterface)(unsafe.Pointer(&i))
  return toType(eface.typ)
}
```

**reflect.Type**: 以接口的形式存在

```go
type Type interface {
    Align() int
    FieldAlign() int
    Method(int) Method
    MethodByName(string) (Method, bool)
    NumMethod() int
    Name() string
    PkgPath() string
    Size() uintptr
    String() string
    Kind() Kind
    Implements(u Type) bool
    AssignableTo(u Type) bool
    ConvertibleTo(u Type) bool
    Comparable() bool
    Bits() int
    ChanDir() ChanDir
    IsVariadic() bool
    Elem() Type
    Field(i int) StructField
    FieldByIndex(index []int) StructField
    FieldByName(name string) (StructField, bool)
    FieldByNameFunc(match func(string) bool) (StructField, bool)
    In(i int) Type
    Key() Type
    Len() int
    NumField() int
    NumIn() int
    NumOut() int
    Out(i int) Type
    common() *rtype
    uncommon() *uncommonType
}
```

## 2.1 Type和Kind的区别

- Type: 真实类型（静态类型） `t.Name()`
- Kind: 基础类型（底层类型） `t.Kind()`

```go
func main() {
	type X int

	var a X = 10

	t1 := reflect.TypeOf(a)
	fmt.Println(t1, t1.Name(), t1.Kind()) // main.X X int

	t2 := reflect.TypeOf(&a)
	fmt.Println(t2, t2.Name(), t2.Kind()) // *main.X "" ptr

	t3 := t2.Elem()
	fmt.Println(t3, t3.Name(), t3.Kind()) // main.X X int
  
	// 基类型 和 指针类型
	fmt.Println(t1 == t3) // true
}
```

## 2.2 方法 `Type.Elem()`

返回引用类型 (指针、数组、切片、字典值 或 通道) 的基类型

```go
func main() {
	a := [...]byte{1, 2, 3}
	s := []int{1, 2, 3}
	m := make(map[int]string)
	c := make(chan bool)

	ta := reflect.TypeOf(a)
	ts := reflect.TypeOf(s)
	tm := reflect.TypeOf(m)
	tc := reflect.TypeOf(c)

	fmt.Println(ta, ta.Elem()) // [3]uint8        uint8
	fmt.Println(ts, ts.Elem()) // []int           int
	fmt.Println(tm, tm.Elem()) // map[int]string  string
	fmt.Println(tc, tc.Elem()) // chan bool       bool
}
```

## 2.3 辅助判断方法

Implements(), ConvertibleTo(), AssignableTo() 

```go
func main() {
	type X int

	var a X
	t := reflect.TypeOf(a)
	fmt.Println(t) // main.X

	ts := reflect.TypeOf((*fmt.Stringer)(nil)).Elem()
	fmt.Println(ts) // fmt.Stringer

	ti := reflect.TypeOf(10)
	fmt.Println(ti) // int

	fmt.Println(t.Implements(ts)) // false
	//fmt.Println(t.Implements(ti)) // panic: reflect: non-interface type passed to Type.Implements

	fmt.Println(t.ConvertibleTo(ts)) // false
	fmt.Println(t.ConvertibleTo(ti)) // true

	fmt.Println(t.AssignableTo(ts)) // false
	fmt.Println(t.AssignableTo(ti)) // false
}
```

## 2.4 结构体

获取结构体内容: Field(), FieldByIndex(), FieldByName(), FieldByNameFunc() 

```go
type StructField struct {
  Name string
  PkgPath string

  Type      Type      // field type
  Tag       StructTag // field tag string
  Offset    uintptr   // offset within struct, in bytes
  Index     []int     // index sequence for Type.FieldByIndex
  Anonymous bool      // is an embedded field  
}
```

```go
func main() {
	user := struct {
		Name string `json:"name"`
		Age  byte   `json:"age"`
	}{"daniel", 21}

	t := reflect.TypeOf(user)

	for i := 0; i < t.NumField(); i++ {
		tf := t.Field(i)
		fmt.Println(tf.Name, tf.Type, tf.Tag) // Name string json:"name"
	}

	if tf, ok := t.FieldByName("Age"); ok {
		fmt.Println(tf.Type, tf.Tag.Get("json")) // uint8 age
	}
}
```



# 3. 值(Value)

**reflect.Value**: 以结构体形式存在

```go
type Value struct {
    typ *rtype
    ptr unsafe.Pointer
    flag
}

func (v Value) Addr() Value
func (v Value) Bool() bool
func (v Value) Bytes() []byte
func (v Value) Call(in []Value) []Value
func (v Value) CallSlice(in []Value) []Value
func (v Value) CanAddr() bool
func (v Value) CanInterface() bool
func (v Value) CanSet() bool
func (v Value) Cap() int
func (v Value) Close()
func (v Value) Complex() complex128
func (v Value) Convert(t Type) Value
func (v Value) Elem() Value
func (v Value) Field(i int) Value
func (v Value) FieldByIndex(index []int) Value
func (v Value) FieldByName(name string) Value
func (v Value) FieldByNameFunc(match func(string) bool) Value
func (v Value) Float() float64
func (v Value) Index(i int) Value
func (v Value) Int() int64
func (v Value) Interface() (i interface})
func (v Value) InterfaceData() [2]uintptr
func (v Value) IsNil() bool
func (v Value) IsValid() bool
func (v Value) IsZero() bool
func (v Value) Kind() Kind
func (v Value) Len() int
func (v Value) MapIndex(key Value) Value
func (v Value) MapKeys() []Value
func (v Value) MapRange() *MapIter
func (v Value) Method(i int) Value
func (v Value) MethodByName(name string) Value
func (v Value) NumField() int
func (v Value) NumMethod() int
func (v Value) OverflowComplex(x complex128) bool
func (v Value) OverflowFloat(x float64) bool
func (v Value) OverflowInt(x int64) bool
func (v Value) OverflowUint(x uint64) bool
func (v Value) Pointer() uintptr
func (v Value) Recv() (x Value, ok bool)
func (v Value) Send(x Value)
func (v Value) Set(x Value)
func (v Value) SetBool(x bool)
func (v Value) SetBytes(x []byte)
func (v Value) SetCap(n int)
func (v Value) SetComplex(x complex128)
func (v Value) SetFloat(x float64)
func (v Value) SetInt(x int64)
func (v Value) SetLen(n int)
func (v Value) SetMapIndex(key, elem Value)
func (v Value) SetPointer(x unsafe.Pointer)
func (v Value) SetString(x string)
func (v Value) SetUint(x uint64)
func (v Value) Slice(i, j int) Value
func (v Value) Slice3(i, j, k int) Value
func (v Value) String() string
func (v Value) TryRecv() (x Value, ok bool)
func (v Value) TrySend(x Value) bool
func (v Value) Type() Type
func (v Value) Uint() uint64
func (v Value) UnsafeAddr() uintptr
func (v Value) assignTo(context string, dst *rtype, target unsafe.Pointer) Value
func (v Value) call(op string, in []Value) []Value
func (v Value) pointer() unsafe.Pointer
func (v Value) recv(nb bool) (val Value, ok bool)
func (v Value) runes() []rune
func (v Value) send(x Value, nb bool) (selected bool)
func (v Value) setRunes(x []rune)
```


## 3.1 通过反射，修改内容

接口变量会复制对象，是unaddressable的；要想修改目标对象，必须使用指针；传入的值必选是pointer-interface

```go
func main() {
	x := 10

	v1 := reflect.ValueOf(x)
	fmt.Println(v1.CanAddr(), v1.CanSet()) // false, false
	fmt.Println(v1.Kind() == reflect.Ptr)  // false

	v2 := reflect.ValueOf(&x)
	fmt.Println(v2.CanAddr(), v2.CanSet())               // false, false
	fmt.Println(v2.Kind() == reflect.Ptr)                // true
	fmt.Println(v2.Elem().CanAddr(), v2.Elem().CanSet()) // true, true

	v2.Elem().SetInt(5)
	fmt.Println(x) // 5
}
```

## 3.2 通道对象设置

```go
func main() {
	ch := make(chan int, 4)
	v := reflect.ValueOf(ch)

	if v.TrySend(reflect.ValueOf(10)) {
		fmt.Println(v.TryRecv()) // 10 true
	}
}
```

## 3.3 空接口判断

```go
func main() {
	var a interface{} = nil
	var b interface{} = (*interface{})(nil)

	va := reflect.ValueOf(a)
	vb := reflect.ValueOf(b)

	fmt.Println(a == nil, b == nil)         // true false
	fmt.Println(va.IsValid(), vb.IsValid()) // false true

	if vb.IsValid() {
		fmt.Println(vb.IsNil(), vb.IsZero()) // true true
	}
}
```




## 3.4 结构体

```go
type User struct {
	Id   int
	Name string
	Age  byte
}

func (u User) Hello() {
	fmt.Println("Hello,", u.Name)
}

func (u User) Say(msg string) {
	fmt.Println(u.Name, "say", msg)
}

func Info(o interface{}) {
	t := reflect.TypeOf(o)
	v := reflect.ValueOf(o)
	if v.Kind() == reflect.Ptr {
		t = t.Elem()
		v = v.Elem()
	}

	// Field()
	fmt.Println("fields:")
	for i := 0; i < v.NumField(); i++ {
		tf := t.Field(i)
		vf := v.Field(i)
		fmt.Printf("%6s: %v %v\n", tf.Name, tf.Type, vf.Interface())
	}

	// FieldByIndex()
	tf1 := t.FieldByIndex([]int{1})
	vf1 := v.FieldByIndex([]int{1})
	fmt.Println(tf1.Name, vf1.String())

	// FieldByName()
	tf2, ok := t.FieldByName("Age")
	if ok {
		vf2 := v.FieldByName("Age")
		fmt.Println(tf2.Name, vf2.Uint())
	}

	// Type.Method(), 注意：只对接收者为User的方法有效，*User的方法不行
	fmt.Println("methods:")
	for i := 0; i < t.NumMethod(); i++ {
		m := t.Method(i)
		fmt.Printf("%6s: %v\n", m.Name, m.Type)
	}

	// Value.MethodByName()
	m := v.MethodByName("Say")
	args := []reflect.Value{reflect.ValueOf("Hi")}
	m.Call(args)
}

func Set(o interface{}) {
	v := reflect.ValueOf(o)

	if v.Kind() != reflect.Ptr {
		fmt.Println("Not a pointer interface")
		return
	}

	v = v.Elem()

	if !v.CanSet() {
		fmt.Println("Can not be set")
		return
	}

	vf := v.FieldByName("Age")

	if !vf.IsValid() {
		fmt.Println("Field not exist")
		return
	}

	if vf.Kind() == reflect.Uint8 {
		vf.SetUint(25)
	}

	fmt.Println(o)
}

func main() {
	u := User{1, "Iren", 20}

	Info(&u)

	Set(&u)
}
```

## 3.5 结构体匿名字段或嵌入字段

反射匿名或嵌入字段：匿名字段当独立字段处理

```go
type User struct {
	Id   int
	Name string
	Age  byte
}

type Manager struct {
	User
	Title string
}

func main() {
	m := Manager{User: User{1, "Jack", 21}, Title: "CEO"}
	t := reflect.TypeOf(m)

	fmt.Printf("%#v\n", t.Field(0)) // {Name:"User", ..., Anonymous:true}
	fmt.Printf("%#v\n", t.Field(1)) // {Name:"Title", ..., Anonymous:false}

	fmt.Printf("%#v\n", t.FieldByIndex([]int{0}))    // Same as t.Field(0),{Name:"User", ..., Anonymous:true}
	fmt.Printf("%#v\n", t.FieldByIndex([]int{0, 1})) // {Name:"Name", ..., Anonymous:false}

	field, ok := t.FieldByName("Title")
	if ok {
		fmt.Printf("%#v\n", field) // {Name:"Title", ..., Anonymous:false}
	}

	field, ok = t.FieldByName("Id")
	if ok {
		fmt.Printf("%#v\n", field) // {Name:"Id", ..., Anonymous:false}
	}
}
```




# 4. 总结

## 4.1 调用方法

```go
type X struct{}

func (X) Add(x, y int) int {
	return x + y
}

func main() {
	var a X

	v := reflect.ValueOf(a)
	m := v.MethodByName("Add")

	args := []reflect.Value{
		reflect.ValueOf(5),
		reflect.ValueOf(7),
	}

	result := m.Call(args)
	for _, val := range result {
		fmt.Println(val)
	}
}
```

## 4.2 调用变参方法

```go
func main() {
	var a X

	v := reflect.ValueOf(a)
	m := v.MethodByName("Format")

	args := []reflect.Value{
		reflect.ValueOf("%s = %d"),
		reflect.ValueOf("x"),
		reflect.ValueOf(9),
	}
	result := m.Call(args)
	fmt.Println(result) // [x = 9]

	args = []reflect.Value{
		reflect.ValueOf("%d + %d = %d"),
		reflect.ValueOf([]interface{}{1, 2, 1 + 2}),
	}
	result = m.CallSlice(args)
	fmt.Println(result) // [1 + 2 = 3]
}
```

## 4.3 构建类型 (MakeXXX())

反射库提供了内置函数 make() 和 new() 的对应操作，例如 MakeFunc()。可用它实现通用模板，适应不同数据类型。

```go
func main() {
	var intAdd func(x, y int) int
	var strAdd func(x, y string) string

	makeAdd(&intAdd)
	makeAdd(&strAdd)

	fmt.Println(intAdd(8, 9))
	fmt.Println(strAdd("Hi", "sara"))
}

func makeAdd(o interface{}) {
	fn := reflect.ValueOf(o).Elem()

	v := reflect.MakeFunc(fn.Type(), add)
	fn.Set(v)
}

func add(args []reflect.Value) (results []reflect.Value) {
	if len(args) == 0 {
		return nil
	}

	var ret reflect.Value

	switch args[0].Kind() {
	case reflect.Int:
		sum := 0
		for _, n := range args {
			sum += int(n.Int())
		}
		ret = reflect.ValueOf(sum)
	case reflect.String:
		ss := make([]string, 0, len(args))
		for _, s := range args {
			ss = append(ss, s.String())
		}
		ret = reflect.ValueOf(strings.Join(ss, " "))
	}

	results = append(results, ret)
	return
}
```


## 4.4. 复合体反射

```go
func walk(x interface{}, fn func(string)) {
	val := getValue(x)

	walkValue := func(value reflect.Value) {
		walk(value.Interface(), fn)
	}

	switch val.Kind() {
	case reflect.String:
		fn(val.String())
	case reflect.Struct:
		for i := 0; i < val.NumField(); i++ {
			walkValue(val.Field(i))
		}
	case reflect.Slice, reflect.Array:
		for i := 0; i < val.Len(); i++ {
			walkValue(val.Index(i))
		}
	case reflect.Map:
		for _, key := range val.MapKeys() {
			walkValue(val.MapIndex(key))
		}
	}
}

func getValue(x interface{}) reflect.Value {
	val := reflect.ValueOf(x)

	if val.Kind() == reflect.Ptr {
		val = val.Elem()
	}

	return val
}

func TestWalk(t *testing.T) {
	cases := []struct {
		Name     string
		Input    interface{}
		Expected []string
	}{
		{
			"test struct",
			struct {
				Name string
			}{"Daniel"},
			[]string{"Daniel"},
		},
		{
			"test map",
			map[int]string{1: "a"},
			[]string{"a"},
		},
	}

	for _, test := range cases {
		t.Run(test.Name, func(t *testing.T) {
			var got []string
			walk(test.Input, func(s string) {
				got = append(got, s)
			})

			if !reflect.DeepEqual(got, test.Expected) {
				t.Fatalf("expected: %v, but got %v\n", test.Expected, got)
			}
		})
	}
}
```

