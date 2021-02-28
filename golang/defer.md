@[TOC](Golang defer小结)


# 1. 概念

defer： 延迟调用

- FILO 先进后出
- 即使函数发生panic错误，也会执行
- 支持匿名函数调用
- 用于资源清理、文件关闭、解锁以及记录时间等操作
- 与匿名函数配合，可在return后修改函数的计算结果

```go
func main() {
	for i := 0; i < 3; i++ {
		defer fmt.Println(i)   // 2 1 0
	}

	for i := 0; i < 3; i++ {
		defer func() {
			fmt.Println(i)     // 3 3 3
		}()
	}
}
```



# 2. 循环

延迟调用在函数结束时调用，如果将其放到循环中，会造成资源浪费

```go
func main() {
	for i := 0; i < 1000; i++ {
		path := fmt.Sprintf("%04d.txt", i)
		f, err := os.Open(path)
		if err != nil {
			log.Println(err)
			continue
		}

		defer f.Close()

		// do something
	}
}
```

优化：

```go
func main() {
	do := func(i int) {
		path := fmt.Sprintf("%04d.txt", i)

		f, err := os.Open(path)
		if err != nil {
			log.Println(err)
			return
		}

		defer f.Close()

		// do something
	}

	for i := 0; i < 1000; i++ {
		do(i)
	}
}
```



# 3. 闭包

```go
func main() {
	var fns = [3]func(){}

	for i := 0; i < 3; i++ {
		// 4th, defer i = 2, 1, 0
		defer fmt.Println("defer i =", i)

		// 3rd, closure_without_arg_defer i = 3, 3, 3
		defer func() {
			fmt.Println("closure_without_arg_defer i =", i)
		}()

		// 2nd, closure_with_arg_defer i = 2, 1, 0
		defer func(i int) {
			fmt.Println("closure_with_arg_defer i =", i)
		}(i)

		fns[i] = func() {
			fmt.Println("closure i =", i)
		}
	}

	// 1st, but always "closure i = 3"
	for _, fn := range fns {
		fn()
	}
}
```



# 4. 性能

相比直接用CALL汇编指令调用函数，延迟调用则须花费更大代价。这其中包括注册、调用等操作，还有额外的缓存开销。

```go
var m sync.Mutex

func call() {
	m.Lock()
	m.Unlock()
}

func deferCall() {
	m.Lock()
	defer m.Unlock()
}

func BenchmarkCall(b *testing.B) {
	for i := 0; i < b.N; i++ {
		call()
	}
}

func BenchmarkDeferCall(b *testing.B) {
	for i := 0; i < b.N; i++ {
		deferCall()
	}
}
```

```bash
$ go test -bench=. -v
BenchmarkCall
BenchmarkCall-4         94623559                12.5 ns/op
BenchmarkDeferCall
BenchmarkDeferCall-4    70848210                16.0 ns/op
```



# 5. 复杂表达式

只延迟紧跟 defer 的函数，并将该函数参数拷贝值入栈存起来

```go
func calc(idx string, a, b int) int {
	ret := a + b
	fmt.Println(idx, a, b, ret)
	return ret
}

func main() {
	a, b := 1, 2

	defer calc("1", a, calc("10", a, b))

	a = 0

	defer calc("2", a, calc("20", a, b))

	b = 1
}

// Output:
// 10 1 2 3
// 20 0 2 2
// 2  0 2 2
// 1  1 3 4
```



defer 后有多个表达式，只保留最后需要执行的那一个

```go
type Slice []int

func NewSlice() Slice {
	return make([]int, 0)
}

func (s *Slice) Add(i int) *Slice {
	*s = append(*s, i)
	//fmt.Println(*s)
	return s
}

func test(s *Slice) {
	defer s.Add(1).Add(2)

	s.Add(3)

	fmt.Println(*s) // [1, 3]
}

func main() {
	s := NewSlice()

	test(&s)

	fmt.Println(s) // [1, 3, 2]
}
```



# 6. 函数返回值

**Golang**中**defer**、**return**、返回值之间执行**顺序**坑：

1. 多个**defer**的执行**顺序**为“后进先出”；
2. **defer**、**return**、返回值三者的执行逻辑应该是：**return**最先执行，**return**负责将结果写入返回值中；接着**defer**开始执行一些收尾工作；最后函数携带当前返回值退出。

```go
func func1(i int) (t int) {
	t = i
	defer func() {
		t += 3
	}()

	return t
}

func func2(i int) int {
	t := i
	defer func() {
		t += 3
	}()

	return t
}

func func3(i int) (t int) {
	defer func() {
		t += i
	}()

	// t 指向的对象
	return 2
}

func main() {
	fmt.Println(func1(1)) // 4
	fmt.Println(func2(1)) // 1
	fmt.Println(func3(1)) // 3
}
```

其他类似示例：

```go
// 1
func f1() (r int) {
	defer func() {
		r++
	}()
	return 0
}

// 1
func f2() (r int) {
	i := 1
	defer func() {
		i++
	}()

	return i
}

// 2
func f3() (r int) {
	defer func(r int) {
		r++
	}(r)

	return 2
}

// 3
func f4() (r int) {
	i := 1
	defer func() {
		r = i + 2
	}()

	return i
}
```

