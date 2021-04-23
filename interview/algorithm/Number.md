# 1. [最大交换](https://leetcode-cn.com/problems/maximum-swap/)

LeetCode 670 

给定一个非负整数，你至多可以交换一次数字中的任意两位。返回你能得到的最大值。

```txt
示例 1 :
输入: 2736
输出: 7236
解释: 交换数字2和数字7。

示例 2 :
输入: 9973
输出: 9973
解释: 不需要交换。
```

算法思想：

- 先观察，如果是纯降序，直接输出。

- 找到第一个非降序的index
- 在index后的子串中从后往前找到最大值max
- 在index前的子串中从前往后找到小于max的值，并交换

```go
func maximumSwap(num int) int {
	arr := []byte(strconv.Itoa(num))
	n := len(arr)

	var maxIndex int
	var max byte

	// 找到第一个非降序index
	var i int
	for i = 0; i < n-1; i++ {
		if arr[i] < arr[i+1] {
			maxIndex = i
			max = arr[i]
			break
		}
	}

	// 在index之后的子串中，从后往前找到最大值
	for j := n - 1; j >= i; j-- {
		if arr[j] > max {
			maxIndex = j
			max = arr[j]
		}
	}

	// 在index之前的子串中，找到比max小的值并交换
	for j := 0; j <= i; j++ {
		if arr[j] < max {
			arr[j], arr[maxIndex] = max, arr[j]
			num, _ = strconv.Atoi(string(arr))
			break
		}
	}

	return num
}

func TestMaximumSwap(t *testing.T) {
	cases := []struct {
		input, output int
	}{
		{1, 1},
		{2736, 7236},
		{9973, 9973},
		{9326, 9623},
		{1993, 9913},
		{10909091, 90909011},
	}

	for _, c := range cases {
		actual := maximumSwap(c.input)
		if actual != c.output {
			t.Errorf("expected %d, but got %d", c.output, actual)
		}
	}

	t.Log("OK")
}
```

