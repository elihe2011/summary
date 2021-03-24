# 1. 动态规划基本技巧

## 1.1 [斐波那契数](https://leetcode-cn.com/problems/fibonacci-number/)

```go
func fib(n int) int {
	if n < 1 {
		return 0
	} else if n < 3 {
		return 1
	} else {
		return fib(n-1) + fib(n-2)
	}
}

func fibMemo(n int) int {
	if n < 1 {
		return 0
	}

	memo := make(map[int]int, n+1)
	return helper(memo, n)
}

func helper(memo map[int]int, n int) int {
	if n < 3 {
		return 1
	}

	if memo[n] != 0 {
		return memo[n]
	}

	memo[n] = helper(memo, n-1) + helper(memo, n-2)
	return memo[n]
}

func fibDP(n int) int {
	if n < 1 {
		return 0
	}

	dp := make([]int, n+1)
	dp[1], dp[2] = 1, 1

	for i := 3; i < n+1; i++ {
		dp[i] = dp[i-1] + dp[i-2]
	}

	return dp[n]
}

func fibFinal(n int) int {
	if n < 1 {
		return 0
	}

	if n < 3 {
		return 1
	}

	prev, curr := 1, 1
	for i := 3; i < n+1; i++ {
		prev, curr = curr, prev+curr
	}
	return curr
}
```

## 1.2 [零钱兑换](https://leetcode-cn.com/problems/coin-change/)

```txt
给定不同面额的硬币 coins 和一个总金额 amount。编写一个函数来计算可以凑成总金额所需的最少的硬币个数。如果没有任何一种硬币组合能组成总金额，返回 -1。
你可以认为每种硬币的数量是无限的。

输入：coins = [1, 2, 5], amount = 11
输出：3 
解释：11 = 5 + 5 + 1
```

**如何列出正确的状态转移方程**？

1、**确定 base case**，显然是目标金额 `amount` 为 0 时返回 0。

2、**确定「状态」，也就是原问题和子问题中会变化的变量**。由于硬币数量无限，硬币的面额也是题目给定的，只有目标金额会不断地向 base case 靠近，所以唯一的「状态」就是目标金额 `amount`。

3、**确定「选择」，也就是导致「状态」产生变化的行为**。目标金额为什么变化呢，因为你在选择硬币，你每选择一枚硬币，就相当于减少了目标金额。所以说所有硬币的面值，就是你的「选择」。

4、**明确** **`dp`** **函数/数组的定义**。我们这里讲的是自顶向下的解法，所以会有一个递归的 `dp` 函数，一般来说函数的参数就是状态转移中会变化的量，也就是上面说到的「状态」；函数的返回值就是题目要求我们计算的量。就本题来说，状态只有一个，即「目标金额」，题目要求我们计算凑出目标金额所需的最少硬币数量。所以我们可以这样定义 `dp` 函数：

`dp(n)` 的定义：输入一个目标金额 `n`，返回凑出目标金额 `n` 的最少硬币数量。

$$
dp(n)=
\begin{cases}
0, n=0\\
-1, n<0\\
min\lbrace dp(n-coin)+1 \lvert coin \in coins  \rbrace, n>0\\
\end{cases}
$$

```go
func coinChange(coins []int, amount int) int {
	var dp func(int) int
	dp = func(n int) int {
		if n < 0 {
			return -1
		}
		if n == 0 {
			return 0
		}

		min := amount + 1
		for _, coin := range coins {
			subproblem := dp(n - coin)
			if subproblem == -1 {
				continue
			}

			if min > subproblem+1 {
				min = subproblem + 1
			}
		}

		if min == amount+1 {
			return -1
		}

		return min
	}

	return dp(amount)
}

var gCoins []int
var gMax int
var memo map[int]int

func coinChangeMemo(coins []int, amount int) int {
	if amount == 0 {
		return 0
	}

    gCoins = coins
    gMax = amount + 1
	memo = make(map[int]int, amount+1)
	
	return dp(amount)
}

func dp(amount int) int {
	if memo[amount] != 0 {
		return memo[amount]
	}

	if amount == 0 {
		return 0
	}

	min := gMax
	for _, coin := range gCoins {
		if amount < coin {
			continue
		}

		subprolem := dp(amount - coin)
		if subprolem == -1 {
			continue
		}

		if min > subprolem+1 {
			min = subprolem + 1
		}
	}

	if min == gMax {
		memo[amount] = -1
	} else {
		memo[amount] = min
	}

	return memo[amount]
}

func coinChangeDP(coins []int, amount int) int {
	dp := make([]int, amount+1)
	for i := 1; i < len(dp); i++ {
		dp[i] = amount + 1
	}

    // 找到 [0, amount] 中所有最小组合
	for i := 0; i < len(dp); i++ {
        // 各自的最小值
		for _, coin := range coins {
			if i < coin {
				continue
			}
			if dp[i] > dp[i-coin]+1 {
				dp[i] = dp[i-coin] + 1
			}
		}
	}

	if dp[amount] == amount+1 {
		return -1
	}

	return dp[amount]
}
```

## 1.3 [最长回文子序列](https://leetcode-cn.com/problems/longest-palindromic-subsequence/)

```txt
给定一个字符串 s ，找到其中最长的回文子序列，并返回该序列的长度。可以假设 s 的最大长度为 1000 。

输入: "bbbab"
输出: 4
```

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/longest-palindromic.png)

```go
func longestPalindromeSubseq(s string) int {
	n := len(s)
	dp := make([][]int, n)

	for i := 0; i < n; i++ {
		dp[i] = make([]int, n)
		dp[i][i] = 1
	}

	for i := n - 2; i >= 0; i-- {
		for j := i + 1; j < n; j++ {
			if s[i] == s[j] {
				dp[i][j] = dp[i+1][j-1] + 2
			} else {
				if dp[i+1][j] > dp[i][j-1] {
					dp[i][j] = dp[i+1][j]
				} else {
					dp[i][j] = dp[i][j-1]
				}
			}
		}
	}

	return dp[0][n-1]
}

func longestPalindromeSubseq2(s string) int {
	n := len(s)
	dp := make([]int, n)
	for i := 0; i < n; i++ {
		dp[i] = 1
	}

	for i := n - 2; i >= 0; i-- {
		pre := 0
		for j := i + 1; j < n; j++ {
			temp := dp[j]
			if s[i] == s[j] {
				dp[j] = pre + 2
			} else {
				if dp[j] < dp[j-1] {
					dp[j] = dp[j-1]
				}
			}
			pre = temp
		}
	}

	return dp[n-1]
}
```

# 2. 子序列类型问题

## 2.1 [编辑距离](https://leetcode-cn.com/problems/edit-distance/)

```txt
给你两个单词 word1 和 word2，请你计算出将 word1 转换成 word2 所使用的最少操作数 。
你可以对一个单词进行如下三种操作：
- 插入一个字符
- 删除一个字符
- 替换一个字符

输入：word1 = "horse", word2 = "ros"
输出：3
解释：
horse -> rorse (将 'h' 替换为 'r')
rorse -> rose (删除 'r')
rose -> ros (删除 'e')
```

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/dp-table.jpg)

状态转移的四种变化：

```python
if s1[i] == s2[j]:
    啥都别做（skip）
    i, j 同时向前移动
else:
    三选一：
        插入（insert）
        删除（delete）
        替换（replace）
```

```go
func minDistance(s1, s2 string) int {
	var dp func(int, int) int

	dp = func(i, j int) int {
		if i == -1 {
			return j + 1
		}
		if j == -1 {
			return i + 1
		}

		// 自上而下递归
		if s1[i] == s2[j] {
			// 相等，直接前移去继续比较
			return dp(i-1, j-1)
		} else {
			// 插入：在s1[i]插入s2[j]一样的字符, 此时s2[j]被匹配了，前移j，继续与i匹配
			a := dp(i, j-1) + 1

			// 删除：删除s1[i]，前移i，继续与j匹配
			b := dp(i-1, j) + 1

			// 替换：s1[i]替换为s2[j]，同时前移i, j继续比较
			c := dp(i-1, j-1) + 1

			return min(a, b, c)
		}
	}

	return dp(len(s1)-1, len(s2)-1)
}

func min(a, b, c int) int {
	res := a
	if res > b {
		res = b
	}
	if res > c {
		res = c
	}
	return res
}

func minDistance2(s1, s2 string) int {
	m := len(s1)
	n := len(s2)

	// 二维数组dp[0][0] 默认为 “”
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, n+1)
	}

	// base case
	for i := 1; i <= m; i++ {
		dp[i][0] = i
	}
	for j := 1; j <= n; j++ {
		dp[0][j] = j
	}

	// 自下而上求解
	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			if s1[i-1] == s2[j-1] {
				dp[i][j] = dp[i-1][j-1]
			} else {
				a := dp[i][j-1] + 1
				b := dp[i-1][j] + 1
				c := dp[i-1][j-1] + 1
				dp[i][j] = min(a, b, c)
			}
		}
	}

	return dp[m][n]
}
```

## 2.2 [最长递增子序列(LIS)](https://leetcode-cn.com/problems/longest-increasing-subsequence/)

```txt
给你一个整数数组 nums ，找到其中最长严格递增子序列的长度。
子序列是由数组派生而来的序列，删除（或不删除）数组中的元素而不改变其余元素的顺序。例如，[3,6,2,7] 是数组 [0,3,1,6,2,2,7] 的子序列。
 
示例 1：
输入：nums = [10,9,2,5,3,7,101,18]
输出：4
解释：最长递增子序列是 [2,3,7,101]，因此长度为 4
```

```go
func lengthOfLIS(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	}

	dp := make([]int, n)
	for i := 0; i < n; i++ {
		dp[i] = 1 // 相对自己的长度均为1
	}

	maxLen := 1
	for i := 1; i < n; i++ {
		for j := 0; j < i; j++ {
			if nums[i] > nums[j] {
				dp[i] = max(dp[i], dp[j]+1)
			}
		}
		maxLen = max(maxLen, dp[i])
	}

	return maxLen
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
```





## 2.3 [俄罗斯套娃信封问题](https://leetcode-cn.com/problems/russian-doll-envelopes/)

```txt
给定一些标记了宽度和高度的信封，宽度和高度以整数对形式 (w, h) 出现。当另一个信封的宽度和高度都比这个信封大的时候，这个信封就可以放进另一个信封里，如同俄罗斯套娃一样。
请计算最多能有多少个信封能组成一组“俄罗斯套娃”信封（即可以把一个信封放到另一个信封里面）。
说明:不允许旋转信封。

示例:
输入: envelopes = [[5,4],[6,4],[6,7],[2,3]]
输出: 3 
解释: 最多信封的个数为 3, 组合为: [2,3] => [5,4] => [6,7]。
```

解法：先将其按w排序，然后对h列进行获取最长递增序列操作

```go
func maxEnvelopes(envelopes [][]int) int {
	n := len(envelopes)
	if n == 0 {
		return 0
	}

	sort.Slice(envelopes, func(i, j int) bool {
		// w 相同时，按 h 倒序排列，以阻止 w 相同选取多个
		if envelopes[i][0] == envelopes[j][0] {
			return envelopes[i][1] > envelopes[j][1]
		}
		return envelopes[i][0] < envelopes[j][0]
	})

	fmt.Println(envelopes)

	heights := make([]int, n)
	for i := 0; i < n; i++ {
		heights[i] = envelopes[i][1]
	}

	return lengthOfLIS(heights)
}
```

## 2.4 [最大子序和](https://leetcode-cn.com/problems/maximum-subarray/)

```txt
给定一个整数数组 nums ，找到一个具有最大和的连续子数组（子数组最少包含一个元素），返回其最大和。

示例:
输入: [-2,1,-3,4,-1,2,1,-5,4]
输出: 6
解释: 连续子数组 [4,-1,2,1] 的和最大，为 6。
```

```go
func maxSubArray(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	}

	dp := make([]int, n)
	dp[0] = nums[0]

	maxSum := dp[0]
	for i := 1; i < n; i++ {
		dp[i] = max(nums[i], nums[i]+dp[i-1])
		maxSum = max(maxSum, dp[i])
	}

	return maxSum
}
```

## 2.5 [最长公共子序列(LCS)](https://leetcode-cn.com/problems/longest-common-subsequence/)

```txt
给定两个字符串 text1 和 text2，返回这两个字符串的最长公共子序列的长度。
一个字符串的 子序列 是指这样一个新的字符串：它是由原字符串在不改变字符的相对顺序的情况下删除某些字符（也可以不删除任何字符）后组成的新字符串。
例如，"ace" 是 "abcde" 的子序列，但 "aec" 不是 "abcde" 的子序列。两个字符串的「公共子序列」是这两个字符串所共同拥有的子序列。
若这两个字符串没有公共子序列，则返回 0。

输入：text1 = "abcde", text2 = "ace" 
输出：3  
解释：最长公共子序列是 "ace"，它的长度为 3。
```

```go
func longestCommonSubsequence(s1, s2 string) int {
	m, n := len(s1), len(s2)
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, n+1)
	}

	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			if s1[i-1] == s1[j-1] {
				// 相同时，取
				dp[i][j] = dp[i-1][j-1] + 1
			} else {
				dp[i][j] = max(dp[i-1][j], dp[i][j-1])
			}
		}
	}

	return dp[m][n]
}
```

## 2.6 [两个字符串的删除操作](https://leetcode-cn.com/problems/delete-operation-for-two-strings/)

```txt
给定两个单词 word1 和 word2，找到使得 word1 和 word2 相同所需的最小步数，每步可以删除任意一个字符串中的一个字符。

输入: "sea", "eat"
输出: 2
解释: 第一步将"sea"变为"ea"，第二步将"eat"变为"ea"
```

方法1：使用LCS找到相同的，然后两个字符串之和减最长相同的2倍

```go
func minDistance(word1 string, word2 string) int {
    m, n := len(word1), len(word2)
    dp := make([][]int, m+1)
    for i := 0; i <= m; i++ {
        dp[i] = make([]int, n+1)
    }

    for i := 0; i <= m; i++ {
        for j := 0; j <= n; j++ {
            if i == 0 || j == 0 {
                continue
            }
            if word1[i-1] == word2[j-1] {
                dp[i][j] = dp[i-1][j-1] + 1
            } else {
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
            }
        }
    }

    return m + n - 2*dp[m][n]
}
```

方法2：通过编辑距离的方式（参考2.1），但没有交换操作

```go
func minDistance(word1 string, word2 string) int {
    m, n := len(word1), len(word2)
    dp := make([][]int, m+1)
    for i := 0; i <= m; i++ {
        dp[i] = make([]int, n+1)
    }

    for i := 0; i <= m; i++ {
        for j := 0; j <= n; j++ {
            if i == 0 || j == 0 {
                dp[i][j] = i + j
                continue
            }

            if word1[i-1] == word2[j-1] {
                dp[i][j] = dp[i-1][j-1]
            } else {
                dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1])
            }
        }
    }

    return dp[m][n]
}
```

## 2.7 [两个字符串的最小ASCII删除和](https://leetcode-cn.com/problems/minimum-ascii-delete-sum-for-two-strings/)

```txt
给定两个字符串s1, s2，找到使两个字符串相等所需删除字符的ASCII值的最小和。

输入: s1 = "sea", s2 = "eat"
输出: 231
解释: 在 "sea" 中删除 "s" 并将 "s" 的值(115)加入总和。
在 "eat" 中删除 "t" 并将 116 加入总和。
结束时，两个字符串相等，115 + 116 = 231 就是符合条件的最小和。
```

解法：先查找最长公共字符串，然后用两个字符串的ASCII和值减去该公共字符串ASCII值得两倍，即为需要删除的字符ASCII和值


```go
func minimumDeleteSum(s1 string, s2 string) int {
	m, n := len(s1), len(s2)
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, n+1)
	}

	var sum int
	for i := range s1 {
		sum += int(s1[i])
	}
	for i := range s2 {
		sum += int(s2[i])
	}

	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			if s1[i-1] == s2[j-1] {
				dp[i][j] = dp[i-1][j-1] + int(s1[i-1])
			} else {
				dp[i][j] = max(dp[i][j-1], dp[i-1][j])
			}
		}
	}

	return sum - 2*dp[m][n]
}
```

## 2.8 [最长回文子序列](https://leetcode-cn.com/problems/longest-palindromic-subsequence/)

同1.3，但使用LCS方式解答

```go
func longestPalindromeSubseq(s string) int {
	m := len(s)
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, m+1)
	}

	bs := []byte(s)
	for i, j := 0, m-1; i < j; i, j = i+1, j-1 {
		bs[i], bs[j] = bs[j], bs[i]
	}

	for i := 1; i <= m; i++ {
		for j := 1; j <= m; j++ {
			if s[i-1] == bs[j-1] {
				dp[i][j] = dp[i-1][j-1] + 1
			} else {
				dp[i][j] = max(dp[i][j-1], dp[i-1][j])
			}
		}
	}
	return dp[m][m]
}
```

# 3. 背包类型问题

 ## 3.1 0-1 背包 （knapsack）

有N件物品和一个最多能被重量为W 的背包。第i件物品的重量是weight[i]，得到的价值是value[i] 。每件物品只能用一次，求解将哪些物品装入背包里物品价值总和最大。

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/knapsack.jpg" width="400" height="300" align="left" />

`dp[i][j]`数组：从下标`[0, i]`的物品中取任意值，放进容量为j的背包，价值总和最大的是多少

递推公式：

- `dp[i-1][j]`: 背包容量为`j`，里面不放物品`i`的最大价值
- `dp[i-1][j-weight[i]]`: 背包容量为`j-weight[i]`，里面不放物品`i`的最大价值；此时如果放物品`i`的最大价值为`dp[i-1][j-weight[i]] + value[i]`
- 递推公式：`max(dp[i-1][j], dp[i-1][j-weight[i]] + value[i])`

初始化：

```go
// 倒序，确保物品0只被放入一次
for j := W; j >= weight[0]; j-- {
    dp[0][j] = dp[0][j-weight[0]] + value[0]
}
```

遍历顺序：

```go
for i := 1; i < len(weight); i++ {
    for j := 0; j <= W; j++ {
        if j < weight[i] {
            // 剩余容量承载不下物品i
            dp[i][j] = dp[i-1][j]
        } else {
            dp[i][j] = max(dp[i-1][j], dp[i-1][j-weight[i]]+value)
        }
    }
}
```

### 3.1.1 [分割等和子集](https://leetcode-cn.com/problems/partition-equal-subset-sum/)

```txt
给定一个只包含正整数的非空数组。是否可以将这个数组分割成两个子集，使得两个子集的元素和相等。
注意:
每个数组中的元素不会超过 100
数组的大小不会超过 200

输入: [1, 5, 11, 5]
输出: true
解释: 数组可以分割成 [1, 5, 5] 和 [11].
```

解法：动态规划
- 设置状态: `dp[i][j]`，`i`为nums数组的下标，`j`为从nums中选出数之和
- 状态转移方程：
  - 不选择`nums[i]`: `dp[i][j] = dp[i-1][j]`
  - 选择`nums[i]`: 
    - `nums[i] == j, dp[i][j]=true`
    - `nums[i] < j, dp[i][j] = dp[i-1][j-nums[i]]`
- 初始化：`dp[i][j] = false`


```go
func canPartition(nums []int) bool {
	m := len(nums)

	var sum int
	for i := 0; i < m; i++ {
		sum += nums[i]
	}

	if sum%2 != 0 {
		return false
	}

	n := sum / 2
	dp := make([][]bool, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]bool, n+1)
		dp[i][0] = true // base case
	}

	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			if j < nums[i-1] {
				// 容量不足
				dp[i][j] = dp[i-1][j]
			} else {
				dp[i][j] = dp[i-1][j] || dp[i-1][j-nums[i-1]]
			}
		}
	}

	return dp[m][n]
}
```

### 3.1.2 [一和零](https://leetcode-cn.com/problems/ones-and-zeroes/)

```txt
给你一个二进制字符串数组 strs 和两个整数 m 和 n 。
请你找出并返回 strs 的最大子集的大小，该子集中 最多 有 m 个 0 和 n 个 1 。
如果 x 的所有元素也是 y 的元素，集合 x 是集合 y 的 子集 。

输入：strs = ["10", "0001", "111001", "1", "0"], m = 5, n = 3
输出：4
解释：最多有 5 个 0 和 3 个 1 的最大子集是 {"10","0001","1","0"} ，因此答案是 4 。
其他满足题意但较小的子集包括 {"0001","1"} 和 {"10","1","0"} 。{"111001"} 不满足题意，因为它含 4 个 1 ，大于 n 的值 3 。
```

```go
func findMaxForm(strs []string, m int, n int) int {
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, n+1)
	}

	for _, s := range strs {
		cnt := count(s)
		for i := m; i >= cnt[0]; i-- {
			for j := n; j >= cnt[1]; j-- {
				dp[i][j] = max(dp[i][j], dp[i-cnt[0]][j-cnt[1]]+1)
			}
		}
	}

	return dp[m][n]
}

func count(s string) []int {
	cnt := make([]int, 2)
	for _, c := range s {
		cnt[c-'0']++
	}
	return cnt
}
```

### 3.1.3 [目标和](https://leetcode-cn.com/problems/target-sum/)

```txt
给定一个非负整数数组，a1, a2, ..., an, 和一个目标数，S。现在你有两个符号 + 和 -。对于数组中的任意一个整数，你都可以从 + 或 -中选择一个符号添加在前面。
返回可以使最终数组和为目标数 S 的所有添加符号的方法数。

输入：nums: [1, 1, 1, 1, 1], S: 3
输出：5
解释：
-1+1+1+1+1 = 3
+1-1+1+1+1 = 3
+1+1-1+1+1 = 3
+1+1+1-1+1 = 3
+1+1+1+1-1 = 3
```

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/knapsack-target-sum.png" width="600" height="300" align="left" />

```go
func findTargetSumWays(nums []int, S int) int {
	m := len(nums)
	var sum int
	for i := 0; i < m; i++ {
		sum += nums[i]
	}
    if sum < 0 {
		sum = -sum
	}

	// 目标值，必须在区间[-sum, sum]
	if S > sum || S < -sum {
		return 0
	}

	dp := make([][]int, m)
	for i := 0; i < m; i++ {
		dp[i] = make([]int, 2*sum+1)
	}

	// base case
	if nums[0] == 0 {
		dp[0][sum] = 2
	} else {
		dp[0][sum+nums[0]] = 1
		dp[0][sum-nums[0]] = 1
	}

	for i := 1; i < m; i++ {
		for j := 0; j <= 2*sum; j++ {
			left, right := 0, 0
			if j-nums[i] >= 0 {
				left = j - nums[i]
			}
			if j+nums[i] <= 2*sum {
				right = j + nums[i]
			}
			dp[i][j] = dp[i-1][left] + dp[i-1][right]
		}
	}

	return dp[m-1][sum+S]
}
```

## 3.2 完全背包

### 3.2.1 [零钱兑换 II](https://leetcode-cn.com/problems/coin-change-2/)

```txt
给定不同面额的硬币和一个总金额。写出函数来计算可以凑成总金额的硬币组合数。假设每一种面额的硬币有无限个。 

输入: amount = 5, coins = [1, 2, 5]
输出: 4
解释: 有四种方式可以凑成总金额:
5=5
5=2+2+1
5=2+1+1+1
5=1+1+1+1+1
```

```go
func change(amount int, coins []int) int {
	m := len(coins)
	dp := make([][]int, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]int, amount+1)
		dp[i][0] = 1
	}

	for i := 1; i <= m; i++ {
		for j := 1; j <= amount; j++ {
			if j < coins[i-1] {
				dp[i][j] = dp[i-1][j]
			} else {
				dp[i][j] = dp[i-1][j] + dp[i][j-coins[i-1]]
			}
		}
	}

	return dp[m][amount]
}
```



# 4. 贪心类型问题

贪心算法：动态规划算法的一个特例，它需要满足更多的条件，效率比动态规划高

贪心选择性质：每一步都做出一个局部最优选择，最终的结果就是全局最优

贪心算法区间调度`Interval Scheduling`，计算最多有几个互不相交的区间

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/greedy-interval-schedule.gif)

```java
public int intervalSchedule(int[][] intvs) {
    if intvs.length == 0 return 0;
    
    // 按 end升序排列
    Arrays.sort(intvs, new Comparator<int[]>() {
        public int compare(int[] a, int[] b) {
            return a[1] - b[1];
        }
    });
    
    // 至少一个区间不相交
    int count = 1;
    
    // 排序后，第一个区间就是 x
    int x_end = intvs[0][1];
    for (int[] interval : intvs) {
        int start = interval[0];
        if (start >= x_end) {
            // 找到下一个选择区间
            count++;
            x_end = interval[1]    
        }
    }
    return count; 
}
```

## 4.1 区间调度问题

### 4.1.1 [无重叠区间](https://leetcode-cn.com/problems/non-overlapping-intervals/)

```txt
给定一个区间的集合，找到需要移除区间的最小数量，使剩余区间互不重叠。
注意:
可以认为区间的终点总是大于它的起点。
区间 [1,2] 和 [2,3] 的边界相互“接触”，但没有相互重叠。

输入: [ [1,2], [2,3], [3,4], [1,3] ]
输出: 1
解释: 移除 [1,3] 后，剩下的区间没有重叠。
```

```go
func eraseOverlapIntervals(intervals [][]int) int {
	return len(intervals) - intervalSchedule(intervals)
}

func intervalSchedule(intervals [][]int) int {
	if len(intervals) == 0 {
		return 0
	}

	sort.Slice(intervals, func(i, j int) bool {
		return intervals[i][1] < intervals[j][1]
	})
	fmt.Println(intervals)

	// 至少一个区间不相交
	count := 1

	// end值
	xEnd := intervals[0][1]

	for i := 1; i < len(intervals); i++ {
		start := intervals[i][0]
		if xEnd <= start {
			count++
			xEnd = intervals[i][1]
		}
	}

	return count
}

func main() {
	intervals := [][]int{{1, 2}, {2, 3}, {3, 4}, {1, 3}}
	fmt.Println(eraseOverlapIntervals(intervals))
}
```

### 4.1.2 [用最少数量的箭引爆气球](https://leetcode-cn.com/problems/minimum-number-of-arrows-to-burst-balloons/)

```txt
在二维空间中有许多球形的气球。对于每个气球，提供的输入是水平方向上，气球直径的开始和结束坐标。由于它是水平的，所以纵坐标并不重要，因此只要知道开始和结束的横坐标就足够了。开始坐标总是小于结束坐标。

一支弓箭可以沿着 x 轴从不同点完全垂直地射出。在坐标 x 处射出一支箭，若有一个气球的直径的开始和结束坐标为 xstart，xend， 且满足  xstart ≤ x ≤ xend，则该气球会被引爆。可以射出的弓箭的数量没有限制。 弓箭一旦被射出之后，可以无限地前进。我们想找到使得所有气球全部被引爆，所需的弓箭的最小数量。

给你一个数组 points ，其中 points [i] = [xstart,xend] ，返回引爆所有气球所必须射出的最小弓箭数。

输入：points = [[10,16],[2,8],[1,6],[7,12]]
输出：2
解释：对于该样例，x = 6 可以射爆 [2,8],[1,6] 两个气球，以及 x = 11 射爆另外两个气球
```

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/greedy-shot-arrows.jpg)

```go
func findMinArrowShots(points [][]int) int {
	n := len(points)
	if n == 0 {
		return 0
	}

	sort.Slice(points, func(i, j int) bool {
		return points[i][1] < points[j][1]
	})

	count := 1
	x := points[0][1]
	for i := 1; i < n; i++ {
		if x < points[i][0] {
			count++
			x = points[i][1]
		}
	}

	return count
}

func main() {
	points := [][]int{{10, 16}, {2, 8}, {1, 6}, {7, 12}}
	fmt.Println(findMinArrowShots(points))
}
```

## 4.2 跳跃游戏

### 4.2.1 [跳跃游戏](https://leetcode-cn.com/problems/jump-game/)

```txt
给定一个非负整数数组，你最初位于数组的第一个位置。
数组中的每个元素代表你在该位置可以跳跃的最大长度。
判断你是否能够到达最后一个位置。

输入: [2,3,1,1,4]
输出: true
解释: 我们可以先跳 1 步，从位置 0 到达 位置 1, 然后再从位置 1 跳 3 步到达最后一个位置。
```

```go
func canJump(nums []int) bool {
    // 能够达到的最远位置
    var farthest int 

    for i := 0; i < len(nums); i++ {
        if i > farthest {
            // 无法到达当前位置
            return false
        }
        farthest = max(farthest, i+nums[i])
    }

    return true
}
```

### 4.2.2 [跳跃游戏 II](https://leetcode-cn.com/problems/jump-game-ii/)

```txt
给定一个非负整数数组，你最初位于数组的第一个位置。
数组中的每个元素代表你在该位置可以跳跃的最大长度。
你的目标是使用最少的跳跃次数到达数组的最后一个位置。

输入: [2,3,1,1,4]
输出: 2
解释: 跳到最后一个位置的最小跳跃数是 2。
     从下标为 0 跳到下标为 1 的位置，跳 1 步，然后跳 3 步到达数组的最后一个位置。
```

方法一：动态规划，时间复杂度 O(n^2)

```go
var memo []int

func jump(nums []int) int {
	n := len(nums)
	memo = make([]int, n)

	// 初始化，假定每一项都要走n步
	for i := 0; i < n; i++ {
		memo[i] = n
	}
	return dp(nums, 0)
}

func dp(nums []int, p int) int {
	n := len(nums)

	// base case, 已到达末尾
	if p >= len(nums)-1 {
		return 0
	}

	// 子问题已计算过
	if memo[p] != n {
		return memo[p]
	}

	// 穷举选择跳 x 步
	steps := nums[p]
	for i := 1; i <= steps; i++ {
		// 子问题结果
		subProblem := dp(nums, p+i)
		memo[p] = min(memo[p], subProblem+1)
	}

	return memo[p]
}
```

方法二：贪心选择

贪心选择性质：不需要【递归地】计算出所有选择的具体结果然后比较求最值，只需要做出那个最有【潜力】，看起来最优的选择即可

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/greedy-jump-game-2.png" width="600" height="400" align="left" />

```go
func jump(nums []int) int {
	n := len(nums)
	var farthest int // 当前步骤所走的最大值
	var end int      // 当前覆盖的边界值
	var jumps int

	for i := 0; i < n-1; i++ {
		farthest = max(farthest, nums[i]+i)
		// 到达上一个覆盖边界，更新覆盖边界
		if end == i {
			jumps++
			end = farthest
		}
		fmt.Printf("farthest=%d, end=%d, jumps=%d\n", farthest, end, jumps)
	}

	return jumps
}
```

# 5. 其他问题

## 5.1 [正则表达式匹配](https://leetcode-cn.com/problems/regular-expression-matching/)

```txt
给你一个字符串 s 和一个字符规律 p，请你来实现一个支持 '.' 和 '*' 的正则表达式匹配。
'.' 匹配任意单个字符
'*' 匹配零个或多个前面的那一个元素
所谓匹配，是要涵盖 整个 字符串 s的，而不是部分字符串。

输入：s = "aa" p = "a"
输出：false
解释："a" 无法匹配 "aa" 整个字符串。
```

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/regular-express.png)

状态转移公式：

```js
const p = pattern.charAt(col - 1);
const prev = pattern.charAt(col - 2);

if (p === '.' || p === t) {
  table[row][col] = table[row - 1][col - 1];
} else if (p === '*') {
  if (table[row][col - 2] === true) {
    table[row][col] = true
  } else if (prev === '.' || prev === t) {
    table[row][col] = table[row - 1][col];
  }
} else {
  table[row][col] = false; 
}
```

```go
func isMatch(s string, p string) bool {
	m, n := len(s), len(p)
	dp := make([][]bool, m+1)
	for i := 0; i <= m; i++ {
		dp[i] = make([]bool, n+1)
	}

	// base case
	dp[0][0] = true
	for j := 1; j <= n; j++ {
		ch := p[j-1]
		if j == 1 {
			if ch == '*' {
				dp[0][j] = true
			}
		} else {
			if ch == '*' {
				dp[0][j] = dp[0][j-2]
			}
		}
	}

	for i := 1; i <= m; i++ {
		ch := s[i-1]
		for j := 1; j <= n; j++ {
			cp := p[j-1]
			if cp == '.' || cp == ch {
				dp[i][j] = dp[i-1][j-1]
			} else if cp == '*' {
				if j > 1 {
					if dp[i][j-2] {
						dp[i][j] = true
					} else {
						prev := p[j-2]
						if prev == '.' || prev == ch {
							dp[i][j] = dp[i-1][j]
						}
					}
				}
			}
		}
	}

	return dp[m][n]
}

func main() {
	cases := [][]string{{"aa", "a"}, {"aa", "a*"}, {"ab", ".*"}, {"aab", "c*a*b"}, {"mississippi", "mis*is*p*."}}
	results := []bool{false, true, true, true, false}

	for i := 0; i < len(cases); i++ {
		if isMatch(cases[i][0], cases[i][1]) != results[i] {
			fmt.Println("NO PASS")
		}
	}
	fmt.Println("done")
}
```

## 5.2 [鸡蛋掉落](https://leetcode-cn.com/problems/super-egg-drop/)

```txt
你将获得 K 个鸡蛋，并可以使用一栋从 1 到 N  共有 N 层楼的建筑。
每个蛋的功能都是一样的，如果一个蛋碎了，你就不能再把它掉下去。
你知道存在楼层 F ，满足 0 <= F <= N 任何从高于 F 的楼层落下的鸡蛋都会碎，从 F 楼层或比它低的楼层落下的鸡蛋都不会破。
每次移动，你可以取一个鸡蛋（如果你有完整的鸡蛋）并把它从任一楼层 X 扔下（满足 1 <= X <= N）。
你的目标是确切地知道 F 的值是多少。
无论 F 的初始值如何，你确定 F 的值的最小移动次数是多少？

输入：K = 1, N = 2
输出：2
解释：
鸡蛋从 1 楼掉落。如果它碎了，我们肯定知道 F = 0 。
否则，鸡蛋从 2 楼掉落。如果它碎了，我们肯定知道 F = 1 。
如果它没碎，那么我们肯定知道 F = 2 。
因此，在最坏的情况下我们需要移动 2 次以确定 F 是多少。
```

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/egg-drop.png)

状态转移：

```js
if (eggs > floors) {
    table[eggs][floors] = table[eggs - 1][floor];
} else {
    let min = floors;
    for (let floor = 1; f <= floors; floor += 1) {
        const max = Math.max(
            table[eggs - 1][floor - 1], // egg breaks
            table[eggs][floors - floor] // egg didn't break
        );
        min = Math.min(min, max);
    }
    table[eggs][floors] = 1 + min;
}
```

动态规划：运行超时

```go
func superEggDrop(K int, N int) int {
	dp := make([][]int, K+1)
	for i := 0; i <= K; i++ {
		dp[i] = make([]int, N+1)
	}

	// base case：一个鸡蛋
	for j := 0; j <= N; j++ {
		dp[1][j] = j
	}

	// 从两个蛋开始
	for eggs := 2; eggs <= K; eggs++ {
		for floors := 1; floors <= N; floors++ {
			// 最少坠落次数
			minDrops := N * N

			for floor := 1; floor <= floors; floor++ {
				broken := dp[eggs-1][floor-1]
				intact := dp[eggs][floors-floor]
				minDrops = min(minDrops, max(broken, intact)+1)
			}

			dp[eggs][floors] = minDrops

		}
	}

	fmt.Println(dp)
	return dp[K][N]
}
```

优化版本：

```go
func superEggDrop(K int, N int) int {
	// only one egg
	dp := make([]int, N+1)
	for n := 0; n <= N; n++ {
		dp[n] = n
	}

	// two or more eggs
	for k := 2; k <= K; k++ {
		dp2 := make([]int, N+1)
		x := 1 // start from floor 1
		for n := 1; n <= N; n++ {
			// start calculate from bottom
			// NOTICE: max(dp[x-1], dp2[n-x]) > max(dp[x], dp2[n-x-1])
			for x < n && max(dp[x-1], dp2[n-x]) > max(dp[x], dp2[n-x-1]) {
				x++
			}

			dp2[n] = 1 + max(dp[x-1], dp2[n-x])
		}

		dp = dp2
	}

	return dp[N]
}
```

## 5.3 [戳气球](https://leetcode-cn.com/problems/burst-balloons/)

```txt
有 n 个气球，编号为0 到 n - 1，每个气球上都标有一个数字，这些数字存在数组 nums 中。
现在要求你戳破所有的气球。戳破第 i 个气球，你可以获得 nums[i - 1] * nums[i] * nums[i + 1] 枚硬币。 这里的 i - 1 和 i + 1 代表和 i 相邻的两个气球的序号。如果 i - 1或 i + 1 超出了数组的边界，那么就当它是一个数字为 1 的气球。
求所能获得硬币的最大数量。

示例 1：
输入：nums = [3,1,5,8]
输出：167
解释：
nums = [3,1,5,8] --> [3,5,8] --> [3,8] --> [8] --> []
coins =  3*1*5    +   3*5*8   +  1*3*8  + 1*8*1 = 167
```

状态转移方程：`dp[i][j] = dp[i][k] + val[i]*val[k]*val[j] + dp[k][j]`

```go
func maxCoins(nums []int) int {
	N := len(nums)

	// 超出了数组边界，各增加一个数字为1的球
	balls := make([]int, N+2)
	balls[0], balls[N+1] = 1, 1
	for i := 1; i < N+1; i++ {
		balls[i] = nums[i-1]
	}

	dp := make([][]int, N+2)
	for i := 0; i < N+2; i++ {
		dp[i] = make([]int, N+2)
	}

	for n := 2; n < len(balls); n++ {
		for i := 0; i < len(balls)-n; i++ {
			j := i + n
			maximum := 0

			// 在区间(i, j)内戳破气球
			for k := i + 1; k < j; k++ {
				sum := dp[i][k] + balls[i]*balls[k]*balls[j] + dp[k][j]
				maximum = max(maximum, sum)
			}
			dp[i][j] = maximum
		}
	}

	return dp[0][N+1]
}
```

## 5.4 [石子游戏](https://leetcode-cn.com/problems/stone-game/) （博弈问题）

```txt
输入：[5,3,4,5]
输出：true
解释：
亚历克斯先开始，只能拿前 5 颗或后 5 颗石子 。
假设他取了前 5 颗，这一行就变成了 [3,4,5] 。
如果李拿走前 3 颗，那么剩下的是 [4,5]，亚历克斯拿走后 5 颗赢得 10 分。
如果李拿走后 5 颗，那么剩下的是 [3,4]，亚历克斯拿走后 4 颗赢得 9 分。
这表明，取前 5 颗石子对亚历克斯来说是一个胜利的举动，所以我们返回 true 。
```

状态状态方程：

```python
T[i][j].fir = max(T[i+1][j].sec + val[i], T[i][j-1].sec + val[j])
T[i][j].sec = T[i+1][j].fir or T[i][j-1].fir
```

```go
func stoneGame(piles []int) bool {
	N := len(piles)
	dp := make([][]*Pair, N)
	for i := 0; i < N; i++ {
		dp[i] = make([]*Pair, N)
		for j := 0; j < N; j++ {
			if i == j {
				// base case
				dp[i][j] = &Pair{piles[i], 0}
			} else if i < j {
				dp[i][j] = new(Pair)
			}
		}

	}

	for n := 2; n <= N; n++ {
		for i := 0; i <= N-n; i++ {
			j := n + i - 1

			// 先手选择
			left := piles[i] + dp[i+1][j].sec
			right := piles[j] + dp[i][j-1].sec

			if left > right {
				dp[i][j].fir = left
				dp[i][j].sec = dp[i+1][j].fir
			} else {
				dp[i][j].fir = right
				dp[i][j].sec = dp[i][j-1].sec
			}
		}
	}

	return dp[0][N-1].fir > dp[0][N-1].sec
}
```

方法二：记录先手的相对分数

- 状态`dp[i][j]`: 先手可获得的相对分数

- 转移方程：`dp[i][j] = max(nums[i]-dp[i+1][j], nums[j]-dp[i][j-1])`

```go
func stoneGame(piles []int) bool {
	n := len(piles)
	dp := make([][]int, n)
	for i := 0; i < n; i++ {
		dp[i] = make([]int, n)
		dp[i][i] = piles[i] // base case
	}

	for j := 1; j < n; j++ {
		for i := j - 1; i >= 0; i-- {
			dp[i][j] = max(piles[i]-dp[i+1][j], piles[j]-dp[i][j-1])
		}
	}

	return dp[0][n-1] > 0
}
```

## 5.5 四键键盘

```txt
假设你有一个特殊的键盘包含下面的按键：
Key 1: (A)：在屏幕上打印一个 'A'。
Key 2: (Ctrl-A)：选中整个屏幕。
Key 3: (Ctrl-C)：复制选中区域到缓冲区。
Key 4: (Ctrl-V)：将缓冲区内容输出到上次输入的结束位置，并显示在屏幕上。
现在，你只可以按键 N 次（使用上述四种按键），请问屏幕上最多可以显示几个 'A’呢？

输入: N = 7
输出: 9
解释: 
我们最多可以在屏幕上显示九个'A'通过如下顺序按键：
A, A, A, Ctrl A, Ctrl C, Ctrl V, Ctrl V
```

```go
func maxA(N int) int {
	dp := make([]int, N+1)

	for i := 1; i <= N; i++ {
		// 按A键 或 Ctrl+A键
		dp[i] = max(dp[i], dp[i-1]+1)

		// 按Ctrl+C 和 Ctrl+V 键
		for j := 2; j < i; j++ {
			// 连续粘贴 i-j 次
			dp[i] = max(dp[i], dp[j-2]*(i-j+1))
		}
	}

	return dp[N]
}

func main() {
	N := 7
	fmt.Println(maxA(N))
}
```



## 5.6 股票买卖

神奇的代码：

```cpp
int maxProfit(vector<int>& prices) {
    if(prices.empty()) return 0;
    int s1=-prices[0],s2=INT_MIN,s3=INT_MIN,s4=INT_MIN;

    for(int i=1;i<prices.size();++i) {            
        s1 = max(s1, -prices[i]);
        s2 = max(s2, s1+prices[i]);
        s3 = max(s3, s2-prices[i]);
        s4 = max(s4, s3+prices[i]);
    }
    return max(0,s4);
}
```

![x](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dynamic-programming/buy-and-sell-stock.png)

**每天都有三种「选择」**：买入(buy)、卖出(sell)、无操作(rest)

状态转移方程：

```python
# n 为天数，大 K 为最多交易数
for 0 <= i < n:  
    for 1 <= k <= K:
        for s in {0, 1}:
            dp[i][k][s] = max(buy, sell, rest)

# 今天未持有股票的两种可能：
# 1. 昨天就未持有股票，今天选择rest
# 2. 昨天持有股票，但今天选择sell
dp[i][k][0] = max(dp[i-1][k][0], dp[i-1][k][1]+prices[i])

# 今天持有股票的两种情况：
# 1. 昨天就已持有股票，今天选择rest
# 2. 昨天未持有股票，今天选择buy
dp[i][k][1] = max(dp[i-1][k][1], dp[i-1][k-1][0]-prices[i])

# base code
dp[-1][k][0] = 0         # 第0天，利润为0
dp[-1][k][1] = -infinity # 第0天，不可能持有股票，利润负无穷

dp[i][0][0] = 0         # 未交易，利润为0
dp[i][0][1] = -infinity # 未交易，不可能持有股票，利润负无穷
```



### 5.6.1 [买卖股票的最佳时机](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock/)

```txt
给定一个数组，它的第 i 个元素是一支给定股票第 i 天的价格。
如果你最多只允许完成一笔交易（即买入和卖出一支股票一次），设计一个算法来计算你所能获取的最大利润。
注意：你不能在买入股票前卖出股票。

输入: [7,1,5,3,6,4]
输出: 5
解释: 在第 2 天（股票价格 = 1）的时候买入，在第 5 天（股票价格 = 6）的时候卖出，最大利润 = 6-1 = 5 。
     注意利润不能是 7-1 = 6, 因为卖出价格需要大于买入价格；同时，你不能在买入前卖出股票。
```

解法一：动态规划 

```go
bp := make([][]int, N)

// base case
bp[0][0] = 0
bp[0][1] = -prices[0]

// 状态转移方程 （交易次数k=1）
dp[i][1][0] = max(dp[i-1][1][0], dp[i-1][1][1]+prices[i])
dp[i][1][1] = max(dp[i-1][1][1], dp[i-1][1-1][0]-prices[i])

// 简化后
dp[i][0] = max(dp[i-1][0], dp[i-1][1]+prices[i])
dp[i][1] = max(dp[i-1][1], 0-prices[i])
```

```go
func maxProfit(prices []int) int {
	n := len(prices)
	if n == 0 {
		return 0
	}

	dp := make([][]int, n)
	for i := 0; i < n; i++ {
		dp[i] = make([]int, 2) // 存储两种状态： 0-未持有 1-持有
	}

	// base case
	dp[0][0] = 0
	dp[0][1] = -prices[0]

	for i := 1; i < n; i++ {
		dp[i][0] = max(dp[i-1][0], dp[i-1][1]+prices[i])
		dp[i][1] = max(dp[i-1][1], 0-prices[i])
	}

	return dp[n-1][0]
}
```

方法二：新状态只与相邻状态有关，不需要使用二维数组维护状态

```go
func maxProfit_k_1(prices []int) int {
	dp_i_0 := 0
	dp_i_1 := -prices[0]

	for i := 1; i < len(prices); i++ {
		dp_i_0 = max(dp_i_0, dp_i_1+prices[i])
		dp_i_1 = max(dp_i_1, 0-prices[i])
	}

	return dp_i_0
}
```

### 5.6.2 [买卖股票的最佳时机 II](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-ii/)

```txt
输入: [7,1,5,3,6,4]
输出: 7
解释: 在第 2 天（股票价格 = 1）的时候买入，在第 3 天（股票价格 = 5）的时候卖出, 这笔交易所能获得利润 = 5-1 = 4 。
     随后，在第 4 天（股票价格 = 3）的时候买入，在第 5 天（股票价格 = 6）的时候卖出, 这笔交易所能获得利润 = 6-3 = 3 。
```

转移方程分析：

```go
dp[0][k][0] = 0        
dp[0][k][1] = -infinity 
dp[i][0][0] = 0         
dp[i][0][1] = -infinity 
dp[i][k][0] = max(dp[i-1][k][0], dp[i-1][k][1]+prices[i])
dp[i][k][1] = max(dp[i-1][k][1], dp[i-1][k-1][0]-prices[i])

// k 趋近 Infinity, k与k-1无差别，上述方程可简化为
dp[0][0] = 0        
dp[0][1] = -prices[0]

dp[i][0] = max(dp[i-1][0], dp[i-1][1]+prices[i-1])
dp[i][1] = max(dp[i-1][1], dp[i-1][0]-prices[i-1])
```

```go
func maxProfit_k_inf(prices []int) int {
	dp_i_0 := 0
	dp_i_1 := -prices[0]

	for i := 1; i < len(prices); i++ {
		temp := dp_i_0 // 前一天的未持有利润
		dp_i_0 = max(dp_i_0, dp_i_1+prices[i])
		dp_i_1 = max(dp_i_1, temp-prices[i])
	}

	return dp_i_0
}
```

### 5.6.3 [买卖股票的最佳时机 III](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-iii/)

```txt
给定一个数组，它的第 i 个元素是一支给定的股票在第 i 天的价格。
设计一个算法来计算你所能获取的最大利润。你最多可以完成 两笔 交易。
注意：你不能同时参与多笔交易（你必须在再次购买前出售掉之前的股票）。

输入：prices = [3,3,5,0,0,3,1,4]
输出：6
解释：在第 4 天（股票价格 = 0）的时候买入，在第 6 天（股票价格 = 3）的时候卖出，这笔交易所能获得利润 = 3-0 = 3 。
     随后，在第 7 天（股票价格 = 1）的时候买入，在第 8 天 （股票价格 = 4）的时候卖出，这笔交易所能获得利润 = 4-1 = 3 。
```

```go
func maxProfit_k_2(prices []int) int {
	n := len(prices)
	K := 2

	dp := make([][][]int, n)
	for i := 0; i < n; i++ {
		dp[i] = make([][]int, K+1)
		for k := 0; k <= K; k++ {
			dp[i][k] = make([]int, 2)
			if k == 0 {
				// base case
				dp[i][0][0] = 0
				dp[i][0][1] = -2<<31 + 1
			}
		}
	}

	for i := 0; i < n; i++ {
		for k := K; k >= 1; k-- {
			if i == 0 {
				// base case
				dp[i][k][0] = 0
				dp[i][k][1] = -prices[0]
			} else {
				dp[i][k][0] = max(dp[i-1][k][0], dp[i-1][k][1]+prices[i])
				dp[i][k][1] = max(dp[i-1][k][1], dp[i-1][k-1][0]-prices[i])
			}
		}
	}

	return dp[n-1][K][0]
}
```

简化版：定义四个变量代替如下转换

```go
dp[i][2][0] = max(dp[i-1][2][0], dp[i-1][2][1]+prices[i])
dp[i][2][1] = max(dp[i-1][2][1], dp[i-1][1][0]-prices[i])
dp[i][1][0] = max(dp[i-1][1][0], dp[i-1][1][1]+prices[i])
dp[i][1][1] = max(dp[i-1][1][1], dp[i-1][0][0]-prices[i])
```

```go
func maxProfit5(prices []int) int {
	dp_i_1_0, dp_i_1_1 := 0, -2<<31+1
	dp_i_2_0, dp_i_2_1 := 0, -2<<31+1

	for i := 0; i < len(prices); i++ {
		dp_i_2_0 = max(dp_i_2_0, dp_i_2_1+prices[i])
		dp_i_2_1 = max(dp_i_2_1, dp_i_1_0-prices[i])
		dp_i_1_0 = max(dp_i_1_0, dp_i_1_1+prices[i])
		dp_i_1_1 = max(dp_i_1_1, 0-prices[i])
	}

	return dp_i_2_0
}
```

### 5.6.4 [买卖股票的最佳时机 IV](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-iv/)

```txt
给定一个整数数组 prices ，它的第 i 个元素 prices[i] 是一支给定的股票在第 i 天的价格。
设计一个算法来计算你所能获取的最大利润。你最多可以完成 k 笔交易。
注意：你不能同时参与多笔交易（你必须在再次购买前出售掉之前的股票）。

示例 1：
输入：k = 2, prices = [2,4,1]
输出：2
解释：在第 1 天 (股票价格 = 2) 的时候买入，在第 2 天 (股票价格 = 4) 的时候卖出，这笔交易所能获得利润 = 4-2 = 2 。
```

**注意**: 一次交易由买入和卖出构成，至少需要两天。所以说有效的限制 k 应该不超过 n/2，如果超过，就没有约束作用了，相当于 k = +infinity。

```go
func maxProfit_k_any(K int, prices []int) int {
	n := len(prices)
	if K > n/2 {
		return maxProfit_k_inf(prices)
	}

	dp := make([][][]int, n)
	for i := 0; i < n; i++ {
		dp[i] = make([][]int, K+1)
		for k := 0; k <= K; k++ {
			dp[i][k] = make([]int, 2)
			if k == 0 {
				dp[i][0][0] = 0
				dp[i][0][1] = -2<<31 + 1
			}
		}
	}

	for i := 0; i < n; i++ {
		for k := K; k >= 1; k-- {
			if i == 0 {
				dp[i][k][0] = 0
				dp[i][k][1] = -prices[i]
			} else {
				dp[i][k][0] = max(dp[i-1][k][0], dp[i-1][k][1]+prices[i])
				dp[i][k][1] = max(dp[i-1][k][1], dp[i-1][k-1][0]-prices[i])
			}
		}
	}

	return dp[n-1][K][0]
}
```

### 5.6.5 [最佳买卖股票时机含冷冻期](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-with-cooldown/)

```txt
给定一个整数数组，其中第 i 个元素代表了第 i 天的股票价格 。​
设计一个算法计算出最大利润。在满足以下约束条件下，你可以尽可能地完成更多的交易（多次买卖一支股票）:
你不能同时参与多笔交易（你必须在再次购买前出售掉之前的股票）。
卖出股票后，你无法在第二天买入股票 (即冷冻期为 1 天)。

输入: [1,2,3,0,2]
输出: 3 
解释: 对应的交易状态为: [买入, 卖出, 冷冻期, 买入, 卖出]
```

解析：每次 sell 之后要等一天才能继续交易，第 i 天选择 buy 的时候，要从 i-2 的状态转移，而不是 i-1

```go
dp[i][0] = max(dp[i-1][0], dp[i-1][1] + prices[i])
dp[i][1] = max(dp[i-1][1], dp[i-2][0] - prices[i])
```

```go
func maxProfit_with_cool(prices []int) int {
	dp_i_0, dp_i_1 := 0, -2<<31+1

	dp_pre_0 := 0
	for i := 0; i < len(prices); i++ {
		temp := dp_i_0
		dp_i_0 = max(dp_i_0, dp_i_1+prices[i])
		dp_i_1 = max(dp_i_1, dp_pre_0-prices[i])
		dp_pre_0 = temp
	}

	return dp_i_0
}
```

### 5.6.6 [买卖股票的最佳时机含手续费](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-with-transaction-fee/)

```txt
给定一个整数数组 prices，其中第 i 个元素代表了第 i 天的股票价格 ；非负整数 fee 代表了交易股票的手续费用。
你可以无限次地完成交易，但是你每笔交易都需要付手续费。如果你已经购买了一个股票，在卖出它之前你就不能再继续购买股票了。
返回获得利润的最大值。
注意：这里的一笔交易指买入持有并卖出股票的整个过程，每笔交易你只需要为支付一次手续费。

输入: prices = [1, 3, 2, 8, 4, 9], fee = 2
输出: 8
解释: 能够达到的最大利润:  
在此处买入 prices[0] = 1
在此处卖出 prices[3] = 8
在此处买入 prices[4] = 4
在此处卖出 prices[5] = 9
总利润: ((8 - 1) - 2) + ((9 - 4) - 2) = 8.
```

```go
func maxProfit_with_fee(prices []int, fee int) int {
	dp_i_0, dp_i_1 := 0, -2<<31+1

	for i := 0; i < len(prices); i++ {
		temp := dp_i_0
		dp_i_0 = max(dp_i_0, dp_i_1+prices[i]-fee)
		dp_i_1 = max(dp_i_1, temp-prices[i])
	}

	return dp_i_0
}
```

## 5.7 打家劫舍 （House Robber）

### 5.7.1 [打家劫舍](https://leetcode-cn.com/problems/house-robber/)

```txt
你是一个专业的小偷，计划偷窃沿街的房屋。每间房内都藏有一定的现金，影响你偷窃的唯一制约因素就是相邻的房屋装有相互连通的防盗系统，如果两间相邻的房屋在同一晚上被小偷闯入，系统会自动报警。
给定一个代表每个房屋存放金额的非负整数数组，计算你 不触动警报装置的情况下 ，一夜之内能够偷窃到的最高金额。

输入：[1,2,3,1]
输出：4
解释：偷窃 1 号房屋 (金额 = 1) ，然后偷窃 3 号房屋 (金额 = 3)。
     偷窃到的最高金额 = 1 + 3 = 4 。
```

状态转移方程：

```txt
小偷当前能够抢到的钱最大值：dp[i] = max(dp[i-1], dp[i-2]+nums[i])

base case:
dp[-1] = 0
dp[0] = nums[0]
dp[1] = max(dp[0], dp[-1]+nums[1]) = nums[1]
```

```go
func robber_skip(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	} else if n == 1 {
		return nums[0]
	}

	dp := make([]int, n)
	dp[0] = nums[0]
	dp[1] = max(nums[0], nums[1])

	for i := 2; i < n; i++ {
		dp[i] = max(dp[i-1], dp[i-2]+nums[i])
	}

	return dp[n-1]
}
```

简化空间复杂度：

```go
func robber_skip_scroll_array(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	} else if n == 1 {
		return nums[0]
	}

	dp0 := nums[0]
	dp1 := max(nums[0], nums[1])

	for i := 2; i < n; i++ {
		temp := dp1
		dp1 = max(dp1, dp0+nums[i])
		dp0 = temp
	}
	return dp1
}
```

### 5.7.2 [打家劫舍 II](https://leetcode-cn.com/problems/house-robber-ii/)

```txt
你是一个专业的小偷，计划偷窃沿街的房屋，每间房内都藏有一定的现金。这个地方所有的房屋都 围成一圈 ，这意味着第一个房屋和最后一个房屋是紧挨着的。同时，相邻的房屋装有相互连通的防盗系统，如果两间相邻的房屋在同一晚上被小偷闯入，系统会自动报警 。
给定一个代表每个房屋存放金额的非负整数数组，计算你 在不触动警报装置的情况下 ，能够偷窃到的最高金额。

输入：nums = [2,3,2]
输出：3
解释：你不能先偷窃 1 号房屋（金额 = 2），然后偷窃 3 号房屋（金额 = 2）, 因为他们是相邻的。
```

思路：将连续的环形房屋，拆分成两个不连续房屋`nums[1:]`和`nums[:n-1]`，然后求最大值

```go
func robber_cycle(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	} else if n == 1 {
		return nums[0]
	}

	return max(robber(nums[1:]), robber(nums[:n-1]))
}

func robber(nums []int) int {
	n := len(nums)
	if n == 0 {
		return 0
	} else if n == 1 {
		return nums[0]
	}

	cur, pre := 0, 0
	for i := 0; i < n; i++ {
		cur, pre = max(cur, pre+nums[i]), cur
	}

	return cur
}
```

### 5.7.3 [打家劫舍 III](https://leetcode-cn.com/problems/house-robber-iii/)

```txt
在上次打劫完一条街道之后和一圈房屋后，小偷又发现了一个新的可行窃的地区。这个地区只有一个入口，我们称之为“根”。 除了“根”之外，每栋房子有且只有一个“父“房子与之相连。一番侦察之后，聪明的小偷意识到“这个地方的所有房屋的排列类似于一棵二叉树”。 如果两个直接相连的房子在同一天晚上被打劫，房屋将自动报警。
计算在不触动警报的情况下，小偷一晚能够盗取的最高金额。

输入: [3,2,3,null,3,null,1]
     3
    / \
   2   3
    \   \ 
     3   1
输出: 7 
解释: 小偷一晚能够盗取的最高金额 = 3 + 3 + 1 = 7.
```

```go
var memo map[*TreeNode]int

func robber_tree(root *TreeNode) int {
	memo = make(map[*TreeNode]int)
	return DFS(root)
}

func DFS(node *TreeNode) int {
	if node == nil {
		return 0
	}

	val, ok := memo[node]
	if ok {
		return val
	}

	// 抢
	selected := node.Val
	if node.Left != nil {
		selected += DFS(node.Left.Left) + DFS(node.Left.Right)
	}
	if node.Right != nil {
		selected += DFS(node.Right.Left) + DFS(node.Right.Right)
	}

	// 不抢
	notSelected := DFS(node.Left) + DFS(node.Right)

	memo[node] = max(selected, notSelected)
	return memo[node]
}
```

自下而上，优化空间复杂度：

```go
func rob(root *TreeNode) int {
    val := dfs(root)
    return max(val[0], val[1])
}

func dfs(node *TreeNode) []int {
    if node == nil {
        return []int{0, 0}
    }

    left, right := dfs(node.Left), dfs(node.Right)

    selected := node.Val + left[1] + right[1]
    notSelected := max(left[0], left[1]) + max(right[0], right[1])
    return []int{selected, notSelected}
}
```

## 5.8 KMP 字符串匹配

字符串匹配暴力解法：

缺点：高时间复杂度 O(MN)，有相同字符时，存在无用的浪费操作

```go
func search(pat, txt string) int {
	M, N := len(pat), len(txt)
	if M > N {
		return -1
	}

	for i := 0; i < N; i++ {
		var j int
		for j = 0; j < M; j++ {
			if pat[j] != txt[i+j] {
				break
			}
		}

		// pattern 匹配到
		if j == M {
			return i
		}
	}

	return -1
}
```



KMP 算法（Knuth-Morris-Pratt）是一个著名的字符串匹配算法

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/kmp/kmp-1.png)

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/kmp/kmp-2.png)

1. 获取前缀表

```go
func prefixTable(pattern string) []int {
	n := len(pattern)
	next := make([]int, n)

	var k int // 前后缀相同时，相同部分的长度
	for i := 1; i < n; i++ {
		if pattern[i] == pattern[k] {
			k++
			next[i] = k
		} else {
			if k > 0 {
				k = 0 // 从头开始
				i--   // 位置保持不变
			}
		}
	}

	// 移位操作
	for i := n - 1; i >= 1; i-- {
		next[i] = next[i-1]
	}
	next[0] = -1

	return next
}
```

2. kmp 求解

```go
func kpm(text, pattern string) int {
	m, n := len(text), len(pattern)
	if m == 0 {
		return -1
	}
	if n == 0 {
		return 0
	}

	next := find(pattern)

	var i int // text 指针
	var j int // pattern 指针

	for i < m {
		// j 到达 pattern的尾部
		if j == n-1 && text[i] == pattern[j] {
			return i - j // 找到
			//j = next[j]  // 寻找后续的匹配
		}

		if text[i] == pattern[j] {
			// 相等时，右移动
			i++
			j++
		} else {
			// 不等，pattern前缀表重置位置
			j = next[j]

			// pattern 移到了表头时
			if j == -1 {
				i++
				j++
			}
		}
	}

	return -1
}
```



### 5.8.1 [实现 strStr()](https://leetcode-cn.com/problems/implement-strstr/)

```txt
实现 strStr() 函数。
给定一个 haystack 字符串和一个 needle 字符串，在 haystack 字符串中找出 needle 字符串出现的第一个位置 (从0开始)。如果不存在，则返回  -1。

输入: haystack = "hello", needle = "ll"
输出: 2
```



## 5.9 构造回文的最小插入次数

二维数组dp，`dp[i][j]` ：对字符串 `s[i..j]`，最少需要进行 `dp[i][j]` 次插入才能变成回文串。

```go
// base case 
dp[0][0] = 0 // 单个字符本身就回文

// 状态转移方程
if s[i] == s[j] {
	dp[i][j] = dp[i+1][j-1]
} else {
    // 左右补充：abc -> acbca，但当存在重复字符串时，acc -> accca，不满足最小
    dp[i][j] = dp[i+1][j-1] + 2
    // 更正为, 
    dp[i][j] = min(dp[i][j-1], dp[i+1][j]) + 1
}
```

### 5.9.1 [让字符串成为回文串的最少插入次数](https://leetcode-cn.com/problems/minimum-insertion-steps-to-make-a-string-palindrome/)

```txt
给你一个字符串 s ，每一次操作你都可以在字符串的任意位置插入任意字符。
请你返回让 s 成为回文串的 最少操作次数 。
「回文串」是正读和反读都相同的字符串。

输入：s = "mbadm"
输出：2
解释：字符串可变为 "mbdadbm" 或者 "mdbabdm" 。
```

```go
func minInsertion(s string) int {
	n := len(s)
	dp := make([][]int, n)
	for i := 0; i < n; i++ {
		dp[i] = make([]int, n)
	}

	// 自下而上遍历
	for i := n - 2; i >= 0; i-- {
		for j := i + 1; j < n; j++ {
			if s[i] == s[j] {
				dp[i][j] = dp[i+1][j-1]
			} else {
				dp[i][j] = min(dp[i+1][j], dp[i][j-1]) + 1
			}
		}
	}

	return dp[0][n-1]
}
```







