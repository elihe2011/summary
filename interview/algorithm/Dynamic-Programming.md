# 1. 动态规划

动态规划(Dynamic Programming): 一般是求最值，比如求**最长**递增子序列，**最小**编辑距离等

动态规划的步骤：

- 核心：穷举求最值。困难在于写出正确的**状态转移方程式**
- 优化穷举过程：使用**备忘录**、**DP table**等进行优化

最优子结构：子问题间必须相互独立

**计算机解决问题其实没有任何奇技淫巧，它唯一的解决办法就是穷举**，穷举所有可能性。算法设计无非就是先思考“如何穷举”，然后再追求“如何聪明地穷举”。

备忘录、DP table 就是在追求“如何聪明地穷举”。用空间换时间的思路，是降低时间复杂度的不二法门。

状态转移方程：**明确 base case -> 明确「状态」-> 明确「选择」 -> 定义 dp 数组/函数的含义**。

动态规划问题框架：

```python
# 初始化 base case
dp[0][0][...] = base
# 进行状态转移
for 状态1 in 状态1的所有取值：
    for 状态2 in 状态2的所有取值：
        dp[状态1][状态2][...] = 求最值(选择1，选择2...)
```



# 2. 回文字符串

## 2.1 [最长回文子串](https://leetcode-cn.com/problems/longest-palindromic-substring/)

给你一个字符串 s，找到 s 中最长的回文子串。

```
输入：s = "babad"
输出："bab"
解释："aba" 同样是符合题意的答案。

输入：s = "cbbd"
输出："bb"
```

### 2.1.1 中心扩散法

**核心思想：<font color="red">从中间向两边扩散来判断回文串</font>**

```go
func longestPalindrome(s string) string {
	var res string

	for i := 0; i < len(s); i++ {
		// 以 s[i] 为中心
		s1 := palindrome(s, i, i)

		// 以 s[i], s[i+1] 为中心
		s2 := palindrome(s, i, i+1)

		// 获取最长回文字符串
		res = longest(res, s1, s2)
	}

	return res
}

func palindrome(s string, left, right int) string {
	for left >= 0 && right < len(s) && s[left] == s[right] {
		left--
		right++
	}

	return s[left+1 : right]
}

func longest(s1, s2, s3 string) string {
	n1, n2, n3 := len(s1), len(s2), len(s3)
	if n1 < n2 {
		s1 = s2
		n1 = n2
	}

	if n1 < n3 {
		s1 = s3
		n1 = n3
	}

	return s1
}
```

### 2.1.2 动态规划

**1. 定义 “状态”**：`dp[l][r]` 表示子串 `s[l, r]` 是否构成回文，如果构成，`dp[l][r]=true`

**2. 找到 “状态转移方程”**：

> 1. 当字符串只包含一个字母，它一定是回文串
>
> 2. 当字符串长度大于等于2时，如果 `s[l,r]` 是回文串，它的收缩串 `s[l+1, r-1]` 也应该是回文串。注意收缩式满足条件为`l+1<r-1`, 即`r-l>2`。当`r-l <=2` 时，也满足回文
>
>    综上，状态转移方程为 `dp[l][r] = s[l]==s[r] && (r-l <= 2 || dp[l+1][r-1])`

```go
func longestPalindrome(s string) string {
	n := len(s)
	if n <= 1 {
		return s
	}

	dp := make([][]bool, n)
	for i := 0; i < n; i++ {
		dp[i] = make([]bool, n)
	}

	res := string(s[0])
	maxLen := 1

	for r := 1; r < n; r++ {
		for l := 0; l < r; l++ {
			if s[l] == s[r] && (r-l <= 2 || dp[l+1][r-1]) {
				dp[l][r] = true
				curLen := r - l + 1
				if maxLen < curLen {
					maxLen = curLen
					res = s[l : r+1]
				}
			}
		}
	}

	return res
}
```