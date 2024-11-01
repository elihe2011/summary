# 1. defer & panic

```go
func main() {
     defer_call()
 }

func defer_call() {
    defer func() { fmt.Println("打印前") }()
    defer func() { fmt.Println("打印中") }()
    defer func() { fmt.Println("打印后") }()
    panic("触发异常")
}
```

输出：

```ASN.1
打印后
打印中
打印前
panic: 触发异常
```

解析：defer 的执行顺序是后进先出。**当出现 panic 语句的时候，会先按照 defer 的后进先出的顺序执行，最后才会执行panic**



#### 关于channel，下面语法正确的是()

- A. var ch chan int
- B. ch := make(chan int)
- C. <- ch
- D. ch <-

参考答案及解析：ABC。A、B都是声明 channel；C 读取 channel；写 channel 是必须带上值，所以 D 错误。



#### 下面这段代码输出什么？

```go
type person struct {  
    name string
}

func main() {  
    var m map[person]int
    p := person{"mike"}
    fmt.Println(m[p])
}
```

- A.0
- B.1
- C. Compilation error

参考答案及解析：A。打印一个 map 中不存在的值时，返回元素类型的零值。这个例子中，m 的类型是 map[person]int，因为 m 中不存在 p，所以打印 int 类型的零值，即 0。



#### 下面这段代码输出什么？

```go
func hello(num ...int) {  
    num[0] = 18
}

func main() {  
    i := []int{5, 6, 7}
    hello(i...)
    fmt.Println(i[0])
}
```

- A.18
- B.5
- C. Compilation error

参考答案及解析：18。知识点：可变函数。



#### 下面这段代码输出什么？

```go
package main

import (  
    "fmt"
)

func main() {  
    a := [5]int{1, 2, 3, 4, 5}
    t := a[3:4:4]
    fmt.Println(t[0])
}
```

- A.3
- B.4
- C.compilation error

参考答案及解析：B。知识点：操作符 [i,j]。基于数组（切片）可以使用操作符 [i,j] 创建新的切片，从索引 i，到索引 j 结束，截取已有数组（切片）的任意部分，返回新的切片，新切片的值包含原数组（切片）的 i 索引的值，但是不包含 j 索引的值。i、j 都是可选的，i 如果省略，默认是 0，j 如果省略，默认是原数组（切片）的长度。i、j 都不能超过这个长度值。

假如底层数组的大小为 k，截取之后获得的切片的长度和容量的计算方法：长度：j-i，容量：k-i。

截取操作符还可以有第三个参数，形如 [i,j,k]，第三个参数 k 用来限制新切片的容量，但不能超过原数组（切片）的底层数组大小。截取获得的切片的长度和容量分别是：j-i、k-i。

所以例子中，切片 t 为 [4]，长度和容量都是 1。



```go
a[low : high]

a[low : high : max]
```

简单切片表达式：`input[low : high]`

`len = high - low`，`cap = len(input) - low`

```go
func main() {
	a := [10]int{1, 2, 3, 4, 5, 6, 7, 8, 9, 0}
	t := a[2:6]
	fmt.Println(t[0], t[1])     // 3 4
	fmt.Println(len(t), cap(t)) // 4 8
}
```



完全切片表达式：`input[low : high: max]`，其中 `high <= max <= cap(input)`

`len = high - low`，`cap = max - low`

```go
func main() {
	a := [10]int{1, 2, 3, 4, 5, 6, 7, 8, 9, 0}
	t := a[2:6:7]
	fmt.Println(t[0], t[1])     // 3 4
	fmt.Println(len(t), cap(t)) // 4 5
}
```

注意：完全切片表达式，不支持string