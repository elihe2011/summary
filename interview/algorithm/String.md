# 1. [字符串相乘](https://leetcode-cn.com/problems/multiply-strings/)

给定两个以字符串形式表示的非负整数 num1 和 num2，返回 num1 和 num2 的乘积，它们的乘积也表示为字符串形式。

输入: num1 = "123", num2 = "456"
输出: "56088"

解题分析：**用两个指针** **`i，j`** **在** **`num1`** **和** **`num2`** **上游走，计算乘积，同时将乘积叠加到** **`res`** **的正确位置**

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/string/multiply-strings.gif" width="400" height="600" align="left" />

实现：

```go
func multiply(num1 string, num2 string) string {
	n1, n2 := len(num1), len(num2)

	res := make([]byte, n1+n2)

	for i := n1 - 1; i >= 0; i-- {
		for j := n2 - 1; j >= 0; j-- {
			mul := (num1[i] - '0') * (num2[j] - '0')

			// 乘积索引位
			p1 := i + j // 进位
			p2 := i + j + 1

			sum := mul + res[p2]
			res[p2] = sum % 10
			res[p1] += sum / 10
		}
	}

	// 去除数组中的前缀 0
	var i int
	for i < len(res) && res[i] == 0 {
		i++
	}

	return toString(res[i:])
}

func toString(arr []byte) string {
	if len(arr) == 0 {
		return "0"
	}
	
	for i := 0; i < len(arr); i++ {
		arr[i] += '0'
	}

	return string(arr)
}
```



# 2. 基本计算器

[224.基本计算器（困难）](https://leetcode-cn.com/problems/basic-calculator)

[227.基本计算器II（中等）](https://leetcode-cn.com/problems/basic-calculator-ii)

[772.基本计算器III（困难）](https://leetcode-cn.com/problems/basic-calculator-iii)

## 2.1 解题思路

将其转化为逆波兰表达式 (Reverse Polish Notation)，然后再进行计算

**1. 整理表达式，去除正负数差别**

**2. 逆波兰表达式转换算法**

​	1) 从左至右扫描中缀表达式

​	2) 若读取到操作数，则判断该操作数类型，并将其加入后缀表达式中

​	3) 若读取到括号

​		a. 左括号"("：将其直接存入运算符堆栈

​		b. 右括号")"：将运算符栈中的运算符依次加到后缀表达式中，直到"("为止

​	4) 若读取到运算符

​		a. 若运算符栈为空，直接入栈

​		b. 若运算符栈的栈顶为括号，直接入栈

​		c. 栈顶运算符优先级高于或等于当前的运算符，那么栈顶运算符出栈，追加到后缀表达式中

​		d. 当前运算符入栈

**3. 后缀表达式计算**

## 2.2 具体实现

```go
// 中缀表达调整
func adjustInfix(s string) string {
	var res []byte

	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "-") || strings.HasPrefix(s, "+") {
		res = append(res, '0')
	}

	for i := 0; i < len(s); i++ {
		res = append(res, s[i])
		if s[i] == '(' && i+1 < len(s) {
			if s[i+1] == '+' || s[i+1] == '-' {
				res = append(res, '0')
			}
		}
	}

	return string(res)
}

// 逆波兰表达转换
func transToRPN(s string) []string {
	var postfix []string

	opStack := stack{}

	for i := 0; i < len(s); {
		switch {
		case isDigit(s[i]):
			// 操作数，放入后缀表达式
			var nums []byte
			for i < len(s) {
				if !isDigit(s[i]) {
					break
				}
				nums = append(nums, s[i])
				i++
			}

			postfix = append(postfix, string(nums))

		case s[i] == '(':
			// 左括号，入栈
			opStack.push(s[i])
			i++

		case s[i] == ')':
			// 右括号，出栈，直到遇到左括号
			for !opStack.empty() {
				top := opStack.pop().(byte)
				if top == '(' {
					break
				}
				postfix = append(postfix, string([]byte{top}))
			}
			i++

		case isOP(s[i]):
			// 空栈，直接入栈
			if opStack.empty() {
				opStack.push(s[i])
				i++
				continue
			}

			// 栈顶为'('，直接入栈
			top := opStack.peek().(byte)
			if top == '(' {
				opStack.push(s[i])
				i++
				continue
			}

			// 栈顶操作符优先级大于等于当前操作符，出栈放入后缀表达式
			for !opStack.empty() {
				top := opStack.peek().(byte)
				if priority(top) >= priority(s[i]) {
					postfix = append(postfix, string([]byte{top}))
					opStack.pop()
				} else {
					break
				}
			}

			opStack.push(s[i])
			i++
		default:
			i++
		}
	}

	// 栈中还有操作符
	for !opStack.empty() {
		top := opStack.pop().(byte)
		postfix = append(postfix, string([]byte{top}))
	}

	return postfix
}

func isDigit(ch byte) bool {
	return ch >= '0' && ch <= '9'
}

func isOP(ch byte) bool {
	return ch == '+' || ch == '-' || ch == '*' || ch == '/'
}

func priority(ch byte) int {
	switch ch {
	case '+', '-':
		return 0
	case '*', '/':
		return 1
	default:
		return -1
	}
}

// 后缀表达式计算
func evalRPN(postfix []string) int {
	var numStack = &stack{}

	for _, v := range postfix {
		switch v {
		case "+", "-", "*", "/":
			s1 := numStack.pop().(string)
			s2 := numStack.pop().(string)
			n1, _ := strconv.Atoi(s1)
			n2, _ := strconv.Atoi(s2)

			var res int
			switch v {
			case "+":
				res = n2 + n1
			case "-":
				res = n2 - n1
			case "*":
				res = n2 * n1
			case "/":
				res = n2 / n1
			}

			numStack.push(strconv.Itoa(res))

		default:
			numStack.push(v)
		}
	}

	res, _ := strconv.Atoi(numStack.pop().(string))

	return res
}
```

## 2.3 测试

```go
func TestTransToRPN(t *testing.T) {
	//middleExpress := "9 + (3 - 1) * 3 + 10 / 2"
	//expectedPostExpress := "931-3*102/++"
	infix := "1-(+1+1)"
	expectedPostExpress := "101+1+-"

	infix = adjustInfix(infix)
	fmt.Println(infix)

	actual := transToRPN(infix)
	var actualPostExpress string
	for i := 0; i < len(actual); i++ {
		actualPostExpress += actual[i]
	}

	if expectedPostExpress != actualPostExpress {
		t.Fatalf("expected %s, but got %v", expectedPostExpress, actualPostExpress)
	}

	t.Log("Done")
}

func TestEvalRPN(t *testing.T) {
	infix := []string{"9", "3", "1", "-", "3", "*", "10", "2", "/", "+", "+"}
	expected := 20

	actual := evalRPN(infix)
	if actual != expected {
		t.Fatalf("expected %v, but got %v", expected, actual)
	}

	t.Log("Done")
}
```



