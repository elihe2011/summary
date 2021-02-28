### 1. 两数之和

#### 1.1 题目

给定一个整数数组 nums 和一个目标值 target，请你在该数组中找出和为目标值的那 两个 整数，并返回他们的数组下标。

你可以假设每种输入只会对应一个答案。但是，你不能重复利用这个数组中同样的元素。

示例:

给定 nums = [2, 7, 11, 15], target = 9

因为 nums[0] + nums[1] = 2 + 7 = 9
所以返回 [0, 1]
链接：https://leetcode-cn.com/problems/two-sum

#### 1.2 思路

1.创建map映射，记录nums[i]到i的映射
2.遍历目标数组，判断map中是否包含key为差值target-nums[i]的元素
3.如果包含，则返回map[target-nums[i]]与i；如果map中不包含，则插入map[nums[i]] = i

#### 1.3 复杂度分析

时间复杂度 O(N)

空间复杂度 O(N)

#### 1.4 代码

```go
// 时间复杂度 O(N^2)
func twoSum(nums []int, target int) []int {
	for i := 0; i < len(nums); i++ {
		for j := i + 1; j < len(nums); j++ {
			if nums[i]+nums[j] == target {
				return []int{i, j}
			}
		}
	}

	return []int{-1, -1}
}
```

```go
func twoSum(nums []int, target int) []int {
	m := make(map[int]int, len(nums))

	for i, v := range nums {
		if j, ok := m[target-v]; ok {
			// 找到
			return []int{i, j}
		} else {
			// 未找到，先存入map
			m[v] = i
		}
	}

	return []int{-1, -1}
}
```



### 2. 两数相加

#### 2.1  题目

给出两个 非空 的链表用来表示两个非负的整数。其中，它们各自的位数是按照 逆序 的方式存储的，并且它们的每个节点只能存储 一位 数字。

如果，我们将这两个数相加起来，则会返回一个新的链表来表示它们的和。

您可以假设除了数字 0 之外，这两个数都不会以 0 开头。


示例：

输入：(2 -> 4 -> 3) + (5 -> 6 -> 4)
输出：7 -> 0 -> 8
原因：342 + 465 = 807

链接：https://leetcode-cn.com/problems/add-two-numbers

#### 2.2 思路

1.设置哑节点(如果不设置哑节点，要计算初始化表头的值)；进位carry初始化为0

2.用两个指针遍历两个链表，两个链表按位相加v1 + v2 + carry，如果有进位，则carry为1

3.两个链表长度不同时，如果短链表的指针已经走到末尾，则设置该值为0，否则为该节点的Val

4.当两个指针都走到链表末尾，退出循环

5.不要忘了判断最后的进位！如果carry=1，需要在追加Val=1的节点

6.最后返回哑节点.Next

#### 2.3  复杂度分析

时间复杂度 O(m+n)

空间复杂度 O(m+n)

m 和 n 分别表示两个链表的长度

#### 2.4 代码

```go
type ListNode struct {
	Val  int
	Next *ListNode
}

func addTwoNumbers(l1 *ListNode, l2 *ListNode) *ListNode {
	var dummyHead ListNode

	// 拷贝指针值，防止原有指针指向的位置发生改变
	p1, p2, p3 := l1, l2, &dummyHead

	// 进位值
	carry := 0

	for p1 != nil || p2 != nil {
		v1, v2 := 0, 0

		if p1 != nil {
			v1 = p1.Val
			p1 = p1.Next
		}

		if p2 != nil {
			v2 = p2.Val
			p2 = p2.Next
		}

		sum := v1 + v2 + carry
		carry = sum / 10

		p3.Next = &ListNode{Val: sum % 10}
		p3 = p3.Next
	}

	// 处理最后的进位
	if carry != 0 {
		p3.Next = &ListNode{Val: carry}
	}

	return dummyHead.Next
}

func main() {
	l1 := &ListNode{
		Val: 2,
		Next: &ListNode{
			Val: 4,
			Next: &ListNode{
				Val: 3,
			}}}
	l2 := &ListNode{
		Val: 5,
		Next: &ListNode{
			Val: 6,
			Next: &ListNode{
				Val: 4,
			}}}

	l := addTwoNumbers(l1, l2)
	for l != nil {
		fmt.Print(l.Val, " ")
		l = l.Next
	}

	fmt.Println()
}
```

### 3. 无重复字符的最长子串
#### 3.1 题目
给定一个字符串，请你找出其中不含有重复字符的 最长子串 的长度。
示例 1:
输入: "abcabcbb"
输出: 3
解释: 因为无重复字符的最长子串是 "abc"，所以其长度为 3。

示例 2:
输入: "bbbbb"
输出: 1
解释: 因为无重复字符的最长子串是 "b"，所以其长度为 1。

示例 3:
输入: "pwwkew"
输出: 3
解释: 因为无重复字符的最长子串是 "wke"，所以其长度为 3。
     请注意，你的答案必须是 子串 的长度，"pwke" 是一个子序列，不是子串。

链接：https://leetcode-cn.com/problems/longest-substring-without-repeating-characters

#### 3.2 解题思路
用map记录字符串中元素的值与索引的映射

用ret表示最大的子字串长度

用start表示滑动窗口的开始位置，map中如果已存在当前字符，start的位置更新为该字符保存的位置+1

遍历字符串，随时计算最大字符串ret=max(ret, i-start+1)，更新map，增加新的字符或更新下标

#### 3.3 复杂度分析
时间复杂度O(n)

空间复杂度O(m),m为s中不重复元素数量

#### 3.4 代码

```go
func lengthOfLongestSubstring(s string) int {
	m := map[byte]int{}
	ret := 0

	// 窗口开始位置
	start := 0

	// 遍历字符串
	for i := 0; i < len(s); i++ {
		c := s[i]

		// 如果 c 已经出现过，则可能需要调整窗口的位置
		// 窗口开始位置变为该字符位置加1
		if v, ok := m[c]; ok {
			start = max(start, v+1)
		}

		// 检查当前的窗口宽度是否大于之前的
		ret = max(ret, i-start+1)

		// 更新字符的下标位置
		m[c] = i
	}

	return ret
}

func max(x, y int) int {
	if x > y {
		return x
	}
	return y
}

func main() {
	ss := []string{"aabaab!bb"}
	for _, s := range ss {
		fmt.Println(lengthOfLongestSubstring(s))
	}
}
```

### 4. 寻找两个有序数组的中位数
#### 4.1 题目
给定两个大小为 m 和 n 的有序数组 nums1 和 nums2。

请你找出这两个有序数组的中位数，并且要求算法的时间复杂度为 O(log(m + n))。

你可以假设 nums1 和 nums2 不会同时为空。

示例 1:

nums1 = [1, 3]
nums2 = [2]

则中位数是 2.0


示例 2:

nums1 = [1, 2]
nums2 = [3, 4]

则中位数是 (2 + 3)/2 = 2.5

链接：https://leetcode-cn.com/problems/median-of-two-sorted-arrays

#### 4.2 解题思路
将题目转化为求两个有序数组第k小的数。每次删掉前k/2个数，更新k

参考https://leetcode-cn.com/problems/median-of-two-sorted-arrays/solution/xiang-xi-tong-su-de-si-lu-fen-xi-duo-jie-fa-by-w-2/中的解法三

#### 4.3 复杂度分析
时间复杂度O(log(m + n))

空间复杂度O(1) 虽然用了递归，但是是尾递归，所以仍为O(1)

#### 4.4 代码

```go
func findMedianSortedArrays(nums1 []int, nums2 []int) float64 {
	sumLen := len(nums1) + len(nums2)

	if sumLen%2 == 1 {
		return findKth(nums1, nums2, (sumLen+1)/2)
	} else {
		return (findKth(nums1, nums2, sumLen/2) + findKth(nums1, nums2, sumLen/2+1)) * 0.5
	}
}

func findKth(nums1, nums2 []int, k int) float64 {
	len1 := len(nums1)
	len2 := len(nums2)

	// 确保nums1的长度不大于nums2
	if len1 > len2 {
		return findKth(nums2, nums1, k)
	}

	// nums1 中没有元素，直接返回nums2的中值
	if len1 == 0 {
		return float64(nums2[k-1])
	}

	// k==1 时，只要返回两个数组第一个元素的最小值即可
	if k == 1 {
		return float64(min(nums1[0], nums2[0]))
	}

	// 取每个数组的折中值，并比较
	pos1 := min(len1, k/2) - 1 // nums1 中的元素数量可能少于k/2
	pos2 := k/2 - 1

	if nums1[pos1] < nums2[pos2] {
		// nums1 的中值过小，去掉前半部分，向中间靠拢
		return findKth(nums1[pos1+1:], nums2, k-pos1-1)
	} else {
		// nums2 的中值过小，去掉前半部分，向中间靠拢
		return findKth(nums1, nums2[pos2+1:], k-pos2-1)
	}
}

func min(x, y int) int {
	if x > y {
		return y
	}

	return x
}

func main() {
	//x := 3
	//y := x >> 1
	//fmt.Println(y)

	nums1 := []int{2}
	nums2 := []int{1, 3}

	fmt.Println(findMedianSortedArrays(nums1, nums2))
}
```

### 5. 最长回文子串
#### 5.1 题目
给定一个字符串 s，找到 s 中最长的回文子串。你可以假设 s 的最大长度为 1000。

示例 1：

输入: "babad"
输出: "bab"
注意: "aba" 也是一个有效答案。

示例 2：

输入: "cbbd"
输出: "bb"

链接：https://leetcode-cn.com/problems/longest-palindromic-substring

#### 5.2 解题思路
长度为奇数的回文串以中间元素为对称轴，长度为偶数的回文串以两个中间元素的中心为对称轴.
使用动态规划来做，
1.定义状态，二维数组`dp[i][j]` 表示子串 `s[i, j]` 是否为回文子串。
2.状态转移方程 `dp[i][j] = (s[i] == s[j]) and dp[i + 1][j - 1]`
3.边界条件
　　3.1 `dp[i][i] = true`(由此扩展奇数长度的回文子串)
　　3.2 `dp[i][i+1] = s[i] == s[i+1]`(由此扩展偶数长度的回文子串)
4.当`dp[i][j] = true`时，更新`maxStart = i,maxLen = j-i+1`

#### 5.3 复杂度分析
时间复杂度O(n2)

空间复杂度O(n2)

#### 5.4 代码

```go
func longestPalindrome(s string) string {
	if len(s) <= 1 {
		return s
	}

	// 最长回文子串起始位置和长度
	maxStart, maxLen := 0, 1

	sLen := len(s)

	// 二维数组dp[i][j]表示区间[i,j]的子串是否为回文子串
	dp := make([][]bool, sLen)
	for i := range dp {
		dp[i] = make([]bool, sLen)
	}

	for i := 0; i < sLen-1; i++ {
		// 单个元素构成的子串是回文串
		dp[i][i] = true

		// 相同的两个元素构成的串是回文串
		if s[i] == s[i+1] {
			dp[i][i+1] = true

			// 更新起始位置和长度
			maxStart = i
			maxLen = 2
		}
	}

	// 最后一个子串构成与自己的回文串
	dp[sLen-1][sLen-1] = true

	// 长度大于2的回文串
	for ln := 3; ln <= sLen && maxLen >= ln-2; ln++ {
		for start := 0; start <= sLen-ln; start++ {
			end := start + ln - 1
			if s[start] == s[end] && dp[start+1][end-1] == true {
				maxLen = ln
				maxStart = start
				dp[start][end] = true
			}
		}
	}

	return s[maxStart : maxStart+maxLen]
}
```

方法2: 中心扩展算法

复杂度分析

时间复杂度：O(n^2)O(n 2)，其中 nn 是字符串的长度。长度为 11 和 22 的回文中心分别有 nn 和 n-1n−1 个，每个回文中心最多会向外扩展 O(n)O(n) 次。

空间复杂度：O(1)O(1)。
链接：https://leetcode-cn.com/problems/longest-palindromic-substring/solution/zui-chang-hui-wen-zi-chuan-by-leetcode-solution/

```go
func longestPalindrome(s string) string {
	if len(s) <= 1 {
		return s
	}

	start, end := 0, 0

	for i := 0; i < len(s); i++ {
		left1, right1 := expandAroundCenter(s, i, i)
		left2, right2 := expandAroundCenter(s, i, i+1)

		if right1-left1 > end-start {
			start, end = left1, right1
		}

		if right2-left2 > end-start {
			start, end = left2, right2
		}
	}

	return s[start : end+1]
}

func expandAroundCenter(s string, left, right int) (int, int) {
	for ; left >= 0 && right < len(s) && s[left] == s[right]; left, right = left-1, right+1 {
	}
	return left + 1, right - 1
}
```

### 6. Z 字形变换
#### 6.1 题目
将一个给定字符串根据给定的行数，以从上往下、从左到右进行 Z 字形排列。

比如输入字符串为 "LEETCODEISHIRING" 行数为 3 时，排列如下：

```
L     C     I     R
E  T  O  E  S  I  I  G
E     D     H     N
```

之后，你的输出需要从左往右逐行读取，产生出一个新的字符串，比如："LCIRETOESIIGEDHN"。

请你实现这个将字符串进行指定行数变换的函数：

string convert(string s, int numRows);

示例 1:

输入: s = "LEETCODEISHIRING", numRows = 3
输出: "LCIRETOESIIGEDHN"

示例 2:

输入: s = "LEETCODEISHIRING", numRows = 4
输出: "LDREOEIIECIHNTSG"
解释:
```
L        D       R
E     O  E    I  I
E  C     I  H    N
T        S       G
```

链接：https://leetcode-cn.com/problems/zigzag-conversion


#### 6.2 解题思路
用[]bytes.Buffer来记录每一行的元素，最后将[]bytes.Buffer拼接起来。

遍历整个字符串，将每个字符添加到相应的bytes.Buffer中，注意当前行 为0或者numRows-1时，移动的方向发生改变。


#### 6.3 复杂度分析
时间复杂度： O(n)

空间复杂度： O(n)

#### 6.4 代码
```go
func convert(s string, numRows int) string {
	if len(s) < 1 || numRows == 1 {
		return s
	}

	// 创建bytes.Buffer切片，用于存储
	bufs := make([]bytes.Buffer, numRows)

	// 走向标识，1-往下 -1-往上
	flag := -1

	// 在哪一行
	row := 0

	for i := 0; i < len(s); i++ {
		// 第一和最后一行，走向逆转
		if row == 0 || row == numRows-1 {
			flag = -flag
		}

		bufs[row].WriteByte(s[i])

		row += flag
	}

	// 将结果拼接成字符串
	var result bytes.Buffer
	for _, v := range bufs {
		result.Write(v.Bytes())
	}

	return result.String()
}

func main() {
	s := "LEETCODEISHIRING"

	fmt.Println(convert(s, 3) == "LCIRETOESIIGEDHN")
	fmt.Println(convert(s, 4) == "LDREOEIIECIHNTSG")
}
```

### 7. 整数反转
#### 7.1 题目
给出一个 32 位的有符号整数，你需要将这个整数中每位上的数字进行反转。

示例 1:

输入: 123
输出: 321

 示例 2:

输入: -123
输出: -321

示例 3:

输入: 120
输出: 21

注意:

假设我们的环境只能存储得下 32 位的有符号整数，则其数值范围为 [−231,  231 − 1]。请根据这个假设，如果反转后整数溢出那么就返回 0。

链接：https://leetcode-cn.com/problems/reverse-integer

#### 7.2 解题思路
整数的反转简单，难点在于如何判断是否溢出。用ans保存反转的结果，当(ans * 10) / 10 != ans时说明溢出，返回0。

这里要注意的是！ans使用int32而不是int，将输入x转为int32。这是因为打印strconv.IntSize可得，leetcode编译的int为64位，而不是32位！

#### 7.3 复杂度分析
时间复杂度：O(n)

空间复杂度：O(1)

#### 7.4 代码
```go
func reverse(x int) int {
	var result int32
	num := int32(x)

	for num != 0 {
		// 越界
		if result*10/10 != result {
			return 0
		}

		result = result*10 + num%10

		num = num / 10
	}

	return int(result)
}

func main() {
	a := []int{123, -123, 120}

	for _, n := range a {
		fmt.Println(reverse(n))
	}
}
```

### 9. 回文数
#### 9.1 题目
判断一个整数是否是回文数。回文数是指正序（从左向右）和倒序（从右向左）读都是一样的整数。

示例 1:

输入: 121
输出: true

示例 2:

输入: -121
输出: false
解释: 从左向右读, 为 -121 。 从右向左读, 为 121- 。因此它不是一个回文数。

示例 3:

输入: 10
输出: false
解释: 从右向左读, 为 01 。因此它不是一个回文数。

进阶:

你能不将整数转为字符串来解决这个问题吗？

链接：https://leetcode-cn.com/problems/palindrome-number

#### 9.2 解题思路
1.首先判断特殊情况，易得x==0为true,x<0为false。

2.对于正整数x，可以反转一半的数字得到rev，如abcde反转一半为edc，比较edc/10与ab是否相等；如abcdef反转一半为fed，比较fed与abc是否相等。即判断x == rev || x == rev / 10

与数字完全反转相比，反转一半数字的好处是省时间+防溢出。

3.特别需要注意x!=0 && x%10==0，如x=10时，反转一半的数字得到rev=0，x=1/10=0，x==rev所以在反转一半的正整数之前，要处理这种特殊情况。

#### 9.3 复杂度分析
时间复杂度：O(log10​(n))

空间复杂度：O(1)

#### 9.4 代码
```go
// 字符串解法
func isPalindrome(x int) bool {
	if x < 0 {
		return false
	}

	s := strconv.Itoa(x)

	for i, j := 0, len(s)-1; i < j; {
		if s[i] != s[j] {
			return false
		}

		i++
		j--
	}

	return true
}
```

```go
// 对半折比较
func isPalindrome(x int) bool {
	if x == 0 {
		return true
	}

	if x < 0 || x%10 == 0 {
		return false
	}

	var num int

	// 对半比较
	for x > num {
		num = num*10 + x%10
		x = x / 10
	}

	if x == num || x == num/10 {
		return true
	}

	return false
}

func main() {
	a := []int{121, -121, 10}

	for _, n := range a {
		fmt.Println(isPalindrome(n))
	}
}
```

### 11. 盛最多水的容器
#### 11.1 题目
给你 n 个非负整数 a1，a2，...，an，每个数代表坐标中的一个点 (i, ai) 。在坐标内画 n 条垂直线，垂直线 i 的两个端点分别为 (i, ai) 和 (i, 0)。找出其中的两条线，使得它们与 x 轴共同构成的容器可以容纳最多的水。

说明：你不能倾斜容器，且 n 的值至少为 2。

 ![11](https://aliyun-lc-upload.oss-cn-hangzhou.aliyuncs.com/aliyun-lc-upload/uploads/2018/07/25/question_11.jpg)

图中垂直线代表输入数组 [1,8,6,2,5,4,8,3,7]。在此情况下，容器能够容纳水（表示为蓝色部分）的最大值为 49。

 

示例：

输入：[1,8,6,2,5,4,8,3,7]
输出：49

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/container-with-most-water
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 11.2 解题思路
容器盛水的面积 = 底边长 * 两条垂直线最短的长度

该题为求最大面积

当两条垂直线位于容器两端，底边长最大，并不意味着面积最大，因为两条垂直线不在两端。虽然底边长变小，但只要两条垂直线最短的长度足够大，依然可以面积最大。

用双指针分别指向数组第一个元素和最后一个元素，求相应的面积，并与之前的最大值比较。

指针往中间移动，底边长变小，只有短木板高变大，才有可能面积变大，因此移动短木板的指针，这样原来的长木板才可能变成移动后的短木板。

#### 11.3 复杂度分析
时间复杂度：O(n)

空间复杂度：O(1)

#### 11.4 代码
```go
func maxArea(height []int) int {
	var result int

	// 通过左右双指针标记
	for left, right := 0, len(height)-1; left < right; {
		area := 0

		if height[left] < height[right] {
			// 以 left 的为高度求面积
			area = height[left] * (right - left)

			left++
		} else {
			// 以 right 的高度求面积
			area = height[right] * (right - left)

			right--
		}

		if result < area {
			result = area
		}
	}

	return result
}

func main() {
	a := []int{1, 8, 6, 2, 5, 4, 8, 3, 7}

	fmt.Println(maxArea(a))
}
```

### 15. 三数之和
#### 15.1 题目
给你一个包含 n 个整数的数组 nums，判断 nums 中是否存在三个元素 a，b，c ，使得 a + b + c = 0 ？请你找出所有满足条件且不重复的三元组。

注意：答案中不可以包含重复的三元组。


示例：

给定数组 nums = [-1, 0, 1, 2, -1, -4]，

满足要求的三元组集合为：
[
  [-1, 0, 1],
  [-1, -1, 2]
]

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/3sum
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 15.2 解题思路
  排序 + 双指针


 1.nums从小到大排序，i,j,k分别代表元素a,b,c的索引

 2.先固定i,i的范围是区间[0, len(nums)-2)，注意要对a去重，如果nums[i] == nums[i-1]将可能出现三元组重复

 3.固定i后，取j = i+1,k =len(nums)-1，j和k在j<k的情况下（j>i和j<k已经保证j和k在移动过程中不会数组越界）作为双指针进行遍历，判断a+b+c

   3.1如果a+b+c==0,则添加三元组,然后j++、k--，并且注意对b,c去重，原因同2中的a

   3.2如果a+b+c>0,则k--

   3.3如果a+b+c<0,则j++

4.注意题目没有说明nums范围,因此需要特殊处理nums == nil 和len(nums)<3，返回nil或者[][]int{}都可以

#### 15.3 复杂度分析
时间复杂度：O(n2)

空间复杂度：不算返回的三元组为O(1)

#### 15.4 代码
```go
func threeSum(nums []int) [][]int {
	var result [][]int

	if nums == nil || len(nums) < 3 {
		return result
	}

	// 先排序
	sort.Ints(nums)

	for i := 0; i < len(nums)-2; i++ {
		// 第一个数必须是负数
		if nums[i] > 0 {
			break
		}

		// 相同的数值，只能选择一个，去重
		if i > 0 && nums[i] == nums[i-1] {
			continue
		}

		// 第二个数 和 第三个数
		j := i + 1
		k := len(nums) - 1

		for j < k {
			sum := nums[i] + nums[j] + nums[k]

			if sum == 0 {
				// 找到
				result = append(result, []int{nums[i], nums[j], nums[k]})

				// j 去重
				for j < k && nums[j] == nums[j+1] {
					j++
				}

				// k 去重
				for j < k && nums[k] == nums[k-1] {
					k--
				}

				// 收缩 j 和 k 的范围
				j++
				k--
			} else if sum > 0 {
				// 过大，收缩 k
				k--
			} else {
				j++
			}
		}
	}

	return result
}

func main() {
	//a := []int{-1, 0, 1, 2, -1, -4}
	a := []int{-2, 0, 3, -1, 4, 0, 3, 4, 1, 1, 1, -3, -5, 4, 0}
	fmt.Println(threeSum(a))
}
```



### 31. 下一个排列

#### 31.1 题目
实现获取下一个排列的函数，算法需要将给定数字序列重新排列成字典序中下一个更大的排列。

如果不存在下一个更大的排列，则将数字重新排列成最小的排列（即升序排列）。

必须原地修改，只允许使用额外常数空间。

以下是一些例子，输入位于左侧列，其相应输出位于右侧列。
1,2,3 → 1,3,2
3,2,1 → 1,2,3
1,1,5 → 1,5,1

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/next-permutation
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 31.2 解题思路
先找出最大的索引 k 满足 nums[k] < nums[k+1]，如果不存在，就翻转整个数组；
再找出另一个最大索引 l 满足 nums[l] > nums[k]；
交换 nums[l] 和 nums[k]；
最后翻转 nums[k+1:]。

#### 31.3 代码

```go
func nextPermutation(nums []int) {
	if len(nums) <= 1 {
		return
	}

	// 从右往左找到第一个 nums[i] > nums[i-1]
	i := len(nums) - 1
	for i > 0 && nums[i] <= nums[i-1] {
		i--
	}

	// 如果已经不存在下一个更大的排序，则反转成为最小的排序
	if i == 0 {
		reverse(nums)
		return
	}

	// 如果存在下一个更大的排列，由于nums[i]>nums[i-1], nums[i:]为降序排列
	// 所以nums[i:]从后往前寻找第一个比nums[i-1]大的数，进行交换
	for j := len(nums) - 1; j >= i; j-- {
		if nums[i-1] < nums[j] {
			nums[i-1], nums[j] = nums[j], nums[i-1]

			// 交换后，反转依旧按降序排列的nums[i:]即可
			reverse(nums[i:])
			return
		}
	}
}

func reverse(nums []int) {
	for i, j := 0, len(nums)-1; i < j; {
		nums[i], nums[j] = nums[j], nums[i]
		i++
		j--
	}
}
```

### 289. 生命游戏
#### 289.1 题目
根据 百度百科 ，生命游戏，简称为生命，是英国数学家约翰·何顿·康威在 1970 年发明的细胞自动机。

给定一个包含 m × n 个格子的面板，每一个格子都可以看成是一个细胞。每个细胞都具有一个初始状态：1 即为活细胞（live），或 0 即为死细胞（dead）。每个细胞与其八个相邻位置（水平，垂直，对角线）的细胞都遵循以下四条生存定律：


    如果活细胞周围八个位置的活细胞数少于两个，则该位置活细胞死亡；
    如果活细胞周围八个位置有两个或三个活细胞，则该位置活细胞仍然存活；
    如果活细胞周围八个位置有超过三个活细胞，则该位置活细胞死亡；
    如果死细胞周围正好有三个活细胞，则该位置死细胞复活；


根据当前状态，写一个函数来计算面板上所有细胞的下一个（一次更新后的）状态。下一个状态是通过将上述规则同时应用于当前状态下的每个细胞所形成的，其中细胞的出生和死亡是同时发生的。

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/game-of-life
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 289.2 解题思路
直接遍历数组，根据条件修改状态即可。

只需要注意两点

1.可以将周围的8个位置的偏移量用二维数组列出,然后循环获取周围的位置，也方便进行数组越界检查。

2.在遍历细胞数组的时候，如果直接更改某个位置的状态，会导致后面的位置错误判断活细胞个数。因此可以复制数组；也可以在原数组中用没有出现过的状态值来进行修改，再遍历一遍数组替换为0或1。

#### 289.3 复杂度分析

时间复杂度：O(mn)
空间复杂度：O(1)

#### 289.4 代码
```go
func gameOfLife(board [][]int) {
	if board == nil || len(board) == 0 {
		return
	}

	// 坐标偏移量
	offset := [][]int{{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}}

	// 数组的 行数 和 列数
	row, col := len(board), len(board[0])

	for i := 0; i < row; i++ {
		for j := 0; j < col; j++ {
			// 周围活细胞总数
			liveCnt := 0

			// 遍历当前细胞的周围细胞
			for k := 0; k < len(offset); k++ {
				X, Y := i+offset[k][0], j+offset[k][1]
				// 坐标不能越界
				if X >= 0 && X < row && Y >= 0 && Y < col {
					// 坐标的值为1 或 -1时为活细胞
					if board[X][Y] == 1 || board[X][Y] == -1 {
						liveCnt++
					}
				}
			}

			// 修改当前细胞的状态
			if board[i][j] == 1 {
				// 活细胞，周围的活细胞数小于2 或者 大于3，改为死细胞
				if liveCnt < 2 || liveCnt > 3 {
					board[i][j] = -1
				}
			} else {
				// 死细胞, 周围的活细胞数等于3，改为活细胞
				if liveCnt == 3 {
					board[i][j] = 2
				}
			}
		}
	}

	// 再次遍历，将存储活细胞和死细胞的临时值(-1,2)改为(0,1)
	for i := 0; i < row; i++ {
		for j := 0; j < col; j++ {
			if board[i][j] == -1 {
				board[i][j] = 0
			} else if board[i][j] == 2 {
				board[i][j] = 1
			}
		}
	}
}
```



### 406. 根据身高重建队列
#### 406.1 题目
 假设有打乱顺序的一群人站成一个队列。 每个人由一个整数对(h, k)表示，其中h是这个人的身高，k是排在这个人前面且身高大于或等于h的人数。 编写一个算法来重建这个队列。

注意：
总人数少于1100人。

示例

输入:
[[7,0], [4,4], [7,1], [5,0], [6,1], [5,2]]

输出:
[[5,0], [7,0], [5,2], [6,1], [4,4], [7,1]]

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/queue-reconstruction-by-height
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 406.2 解题思路

个子高的人看不到前面比自己矮的人，所以先按照身高降序，这样再把矮个子放到高个子前面，不影响高个子的前面有多少个比他高（或相等）的人数。

1.对people按照身高降序排序，身高相同，则按k升序排序

2.创建ans切片保存结果，ans[0] = people[0]

3.从people[1]开始遍历，将people[i]放到ans中people[i][1]的位置，即放到相应的k。如果该位置已经有元素,则从该元素开始往后移动一位，然后把people[i]插入

（这样做仍然能保持满足条件，是因为按照身高降序，插入的新元素的身高比原位置的元素要小（或相等，又由于身高相等时，按照k升序排序，所以也满足））

#### 406.3 复杂度分析
时间复杂度：O（N2）

空间复杂度：O（N）

#### 406.4 代码
```go
func reconstructQueue(people [][]int) [][]int {
	if people == nil || len(people) <= 1 {
		return people
	}

	// 按身高降序排序，身高相同，则按k升序排序
	sort.Slice(people, func(i, j int) bool {
		if people[i][0] == people[j][0] {
			// 升序
			return people[i][1] < people[j][1]
		}
		// 降序
		return people[i][0] > people[j][0]
	})

	fmt.Println(people)

	// 返回值
	result := make([][]int, len(people))
	for i := 0; i < len(people); i++ {
		result[i] = make([]int, 2)
	}

	// 根据k的值，插到相应的位置上
	result[0] = people[0]
	for i := 1; i < len(people); i++ {
		// 目标位置
		pos := people[i][1]

		// 移动位置
		for j := i; j > pos; j-- {
			result[j] = result[j-1]
		}
		result[pos] = people[i]
	}

	return result
}
```

更简单的解法：

思考：
先按照个子从高到低排序，如果个子一样，则按照k从小到大排列，这样就得到了一个方便后面插入的队列
before: [[7,0] [4,4] [7,1] [5,0] [6,1] [5,2]]
after : [[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]

得到了预处理的队列，然后遍历这个队列，按照k值来插入到队列的index位置
比如现在遍历到了[6 1], k = 1, 那么就插入到 index = 1 的位置
变成：[[7 0] [6 1] [7 1] [5 0] [5 2] [4 4]]
以此类推。。。

步骤分解：

```
原始输入：
[[7,0] [4,4] [7,1] [5,0] [6,1] [5,2]]

sort处理：
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]

遍历people：
===== i=0
   ↓：p[0] 应该在index=0的位置
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]] ok

===== i=1
         ↓：p[1]应该在index=1的位置
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]] ok

===== i=2
               ↓：p[2]应该在index=1的位置
[[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]
[[7 0] [6 1] [7 1] [5 0] [5 2] [4 4]] ok

===== i=3
                     ↓：p[3]应该在index=0的位置
[[7 0] [6 1] [7 1] [5 0] [5 2] [4 4]]
[[5 0] [7 0] [6 1] [7 1] [5 2] [4 4]] ok

===== i=4
                           ↓：p[4]应该在index=2的位置
[[5 0] [7 0] [6 1] [7 1] [5 2] [4 4]]
[[5 0] [7 0] [5 2] [6 1] [7 1] [4 4]] ok

===== i=5
                                 ↓：p[5]应该在index=4的位置
[[5 0] [7 0] [5 2] [6 1] [7 1] [4 4]]
[[5 0] [7 0] [5 2] [6 1] [4 4] [7 1]] ok

最终结果：
[[5 0] [7 0] [5 2] [6 1] [4 4] [7 1]]
````

链接：https://leetcode-cn.com/problems/queue-reconstruction-by-height/solution/gojie-fa-xiang-xi-zhu-shi-xian-pai-xu-zai-cha-ru-s/

```go
func reconstructQueue(people [][]int) [][]int {
	if people == nil || len(people) <= 1 {
		return people
	}

	// 按身高降序排序，身高相同，则按k升序排序
	sort.Slice(people, func(i, j int) bool {
		if people[i][0] == people[j][0] {
			// 升序
			return people[i][1] < people[j][1]
		}
		// 降序
		return people[i][0] > people[j][0]
	})

	fmt.Println(people)

	for from, p := range people {
		to := p[1]
		copy(people[to+1:from+1], people[to:from])
		people[to] = p
	}

	return people
}

func main() {
	a := [][]int{
		{7, 0},
		{4, 4},
		{7, 1},
		{5, 0},
		{6, 1},
		{5, 2},
	}

	fmt.Println(reconstructQueue(a))
}
```

### 687. 最长同值路径
#### 687.1 题目
给定一个二叉树，找到最长的路径，这个路径中的每个节点具有相同值。 这条路径可以经过也可以不经过根节点。

注意：两个节点之间的路径长度由它们之间的边数表示。

示例 1:

输入:

              5
             / \
            4   5
           / \   \
          1   1   5
输出:

2
示例 2:

输入:

              1
             / \
            4   5
           / \   \
          4   4   5
输出:

2
注意: 给定的二叉树不超过10000个结点。 树的高度不超过1000。



来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/longest-univalue-path
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 687.2 解题思路
1.后序遍历二叉树，设置最大值变量

2.以某节点为根节点，如果它的左(右)孩子存在且值与该节点相同，那么该节点的最长同源路径+=以左（右)孩子为根节点的的最长同源路径+1，否则+=0。

3.遍历的过程中，如果当前节点为根节点的最长同源路径>最大值，则更新最大值

4.注意节点向其根节点返回的是其左孩子和右孩子到该节点最长同源路径的最大值，而不是和（路径不能出现分叉）。

#### 687.3 复杂度分析
时间复杂度：O(n) n是树中节点个数

空间复杂度：O(h) h是树的高度

#### 687.4 代码
```go
var result int

func longestUnivaluePath(root *TreeNode) int {
	result = 0
	longestPath(root)
	return result
}

func longestPath(root *TreeNode) int {
	if root == nil {
		return 0
	}

	// 左子树的最长相同路径
	leftLen := longestPath(root.Left)

	// 右子树的最长相同路径
	rightLen := longestPath(root.Right)

	// 如果root.Val == root.Left.Val，则左子树的最长同源路径为leftLen+1, 否则为0
	if root.Left != nil && root.Left.Val == root.Val {
		leftLen++
	} else {
		leftLen = 0
	}

	// 同上，求右子树的最长同源路径
	if root.Right != nil && root.Right.Val == root.Val {
		rightLen++
	} else {
		rightLen = 0
	}

	// 最长同源路径为左右子树的最长同源路径之和
	result = max(result, leftLen+rightLen)

	// 返回节点的最大值
	return max(leftLen, rightLen)
}

func max(x, y int) int {
	if x > y {
		return x
	}
	return y
}

func main() {
	//root := &TreeNode{
	//	Val: 5,
	//	Left: &TreeNode{
	//		Val:   4,
	//		Left:  &TreeNode{Val: 1},
	//		Right: &TreeNode{Val: 1},
	//	},
	//	Right: &TreeNode{
	//		Val:   5,
	//		Right: &TreeNode{Val: 5},
	//	},
	//}
	root := &TreeNode{Val: 1}

	fmt.Println(longestUnivaluePath(root))
}
```



### 1145. 二叉树着色游戏
#### 1145.1 题目
有两位极客玩家参与了一场「二叉树着色」的游戏。游戏中，给出二叉树的根节点 root，树上总共有 n 个节点，且 n 为奇数，其中每个节点上的值从 1 到 n 各不相同。

游戏从「一号」玩家开始（「一号」玩家为红色，「二号」玩家为蓝色），最开始时，

「一号」玩家从 [1, n] 中取一个值 x（1 <= x <= n）；

「二号」玩家也从 [1, n] 中取一个值 y（1 <= y <= n）且 y != x。

「一号」玩家给值为 x 的节点染上红色，而「二号」玩家给值为 y 的节点染上蓝色。

之后两位玩家轮流进行操作，每一回合，玩家选择一个他之前涂好颜色的节点，将所选节点一个 未着色 的邻节点（即左右子节点、或父节点）进行染色。

如果当前玩家无法找到这样的节点来染色时，他的回合就会被跳过。

若两个玩家都没有可以染色的节点时，游戏结束。着色节点最多的那位玩家获得胜利 ✌️。


现在，假设你是「二号」玩家，根据所给出的输入，假如存在一个 y 值可以确保你赢得这场游戏，则返回 true；若无法获胜，就请返回 false。

示例：

![color](https://assets.leetcode-cn.com/aliyun-lc-upload/uploads/2019/08/04/1480-binary-tree-coloring-game.png)

输入：root = [1,2,3,4,5,6,7,8,9,10,11], n = 11, x = 3
输出：True
解释：第二个玩家可以选择值为 2 的节点。

提示：

    二叉树的根节点为 root，树上由 n 个节点，节点上的值从 1 到 n 各不相同。
    n 为奇数。
    1 <= x <= n <= 100

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/binary-tree-coloring-game
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 1145.2 解题思路
根据题意可得

![pic](https://pic.leetcode-cn.com/702fa9c7bbdb5b3516b2c8fb55c8d6470ff923cc741acf678bcde4d3ed8d69f4.png)

1.如图所示，当玩家一先选择值为x的节点（图中红色节点），玩家二可以选择的节点位于三个区域之一。

2.谁能取得一半以上的节点数量，谁就获胜。

3.每一回合，玩家选择一个他之前涂好颜色的节点，将所选节点一个 未着色 的邻节点（即左右子节点、或父节点）进行染色。

4.由3得，如果第一次玩家二选择某个区域中最靠近玩家一所选择的节点（即红色节点的左节点、右节点或者父节点），那么玩家一不能给该区域的节点染色。

5.由2、4得，如果有一个区域的节点数大于一半以上的节点数量，那么当二号玩家选择该区域最靠近能赢。

 

经过以上分析，步骤为：

1.根据值x，找到玩家一所选择的红色节点xNode

2.分别统计三个区域的节点数（区域A、B的节点数可以通过深度优先搜索xNode.Left或xNode.Right得到；区域C的节点，是树中除了区域A、区域B和xNode之外的节点，因此直接做减法即可求区域C节点数）

3.如果其中一个区域的节点数>一半，那么玩家二有机会赢，否则玩家二不能赢。

#### 1145.3 复杂度分析
时间复杂度：O(n）

空间复杂度：O(n)

#### 1145.4 代码
```go
type TreeNode struct {
	Val   int
	Left  *TreeNode
	Right *TreeNode
}

func btreeGameWinningMove(root *TreeNode, n int, x int) bool {
	// 寻找节点 x
	xNode := findX(root, x)

	// 统计节点 x 的左子节点个数
	leftCnt := count(xNode.Left)

	// 统计节点 x 的右子节点个数
	rightCnt := count(xNode.Right)

	// 剩余可用节点数
	availableCnt := n - leftCnt - rightCnt - 1

	// 对半数
	halfN := n >> 1

	// 三个区域，只要有一个大于 半数，则二号玩家就有机会赢
	return leftCnt > halfN || rightCnt > halfN || availableCnt > halfN
}

func findX(root *TreeNode, x int) *TreeNode {
	if root == nil {
		return nil
	}

	if root.Val == x {
		return root
	}

	left := findX(root.Left, x)
	if left != nil {
		return left
	}

	return findX(root.Right, x)
}

func count(root *TreeNode) int {
	if root == nil {
		return 0
	}

	return count(root.Left) + count(root.Right) + 1
}

func main() {
	root := &TreeNode{
		Val: 1,
		Left: &TreeNode{
			Val: 2,
			Left: &TreeNode{
				Val:   4,
				Left:  &TreeNode{Val: 4},
				Right: &TreeNode{Val: 9},
			},
			Right: &TreeNode{
				Val:   5,
				Left:  &TreeNode{Val: 10},
				Right: &TreeNode{Val: 11},
			},
		},
		Right: &TreeNode{
			Val:   3,
			Left:  &TreeNode{Val: 6},
			Right: &TreeNode{Val: 7},
		},
	}

	fmt.Println(btreeGameWinningMove(root, 11, 3))
}
```

### 1162. 地图分析
#### 1162.1 题目
你现在手里有一份大小为 N x N 的 网格 grid，上面的每个 单元格 都用 0 和 1 标记好了。其中 0 代表海洋，1 代表陆地，请你找出一个海洋单元格，这个海洋单元格到离它最近的陆地单元格的距离是最大的。

我们这里说的距离是「曼哈顿距离」（ Manhattan Distance）：(x0, y0) 和 (x1, y1) 这两个单元格之间的距离是 |x0 - x1| + |y0 - y1| 。

如果网格上只有陆地或者海洋，请返回 -1。

 

示例 1：

![1](https://assets.leetcode-cn.com/aliyun-lc-upload/uploads/2019/08/17/1336_ex1.jpeg#pic_left)

输入：`[[1,0,1],[0,0,0],[1,0,1]]`
输出：2
解释： 
海洋单元格 (1, 1) 和所有陆地单元格之间的距离都达到最大，最大距离为 2。
示例 2：

![2](https://assets.leetcode-cn.com/aliyun-lc-upload/uploads/2019/08/17/1336_ex2.jpeg#pic_left)

输入：`[[1,0,0],[0,0,0],[0,0,0]]`
输出：4
解释： 
海洋单元格 (2, 2) 和所有陆地单元格之间的距离都达到最大，最大距离为 4。


提示：

`1 <= grid.length == grid[0].length <= 100`
`grid[i][j]` 不是 0 就是 1

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/as-far-from-land-as-possible
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。

#### 1162.2 解题思路
1.分析题意：题目定义dist<海洋i，陆地>=min(曼哈顿距离<海洋i， 陆地j>)。要求的是max(dist<海洋i，陆地>)。

2.思路：可以想象成从陆地开始向4个方向每轮扩散一格，把海洋变成“陆地”，并记录该区域是第几轮成为“陆地”的，直到图中只有“陆地”为止。所求即为第几轮使所有区域成为“陆地”。

3.算法：图的多源BFS（图的多源BFS可以想象成该图外部有一个“超级源点”，与原来的多个源点都存在一条边，即从“超级源点”开始做单源BFS，原来的多个源点就是BFS的第二层而已）

4.特殊值处理：题目要求如果原始地图上只有陆地或者海洋，返回 -1。

#### 1162.3 复杂度分析
时间复杂度:O(N2)  (遍历二维数组)

空间复杂度:O(N2) （队列最大长度）

#### 1162.4 代码
```go
func maxDistance(grid [][]int) int {
	// 图的多源广搜，从原始陆地开始，每次扩散一格把"海洋"变为"陆地"
	// 修改grid[i][j]为扩散轮数+1，直到所有区域变成"陆地"
	// 返回最后一格变为"陆地"的grid[i][j]-1
	queue := make([]int, 0)

	col := len(grid[0])
	for i := range grid {
		for j := range grid[i] {
			// 判断是否陆地
			if grid[i][j] == 1 {
				// 陆地加入队列 i == i*col + j/col, j == i*col+j%col
				queue = append(queue, i*col+j)
			}
		}
	}

	// 上下左右四个方向进行陆地的扩散
	xDir := []int{-1, 0, 1, 0}
	yDir := []int{0, -1, 0, 1}

	// 陆地坐标
	x, y := 0, 0
	for len(queue) != 0 {
		x, y = queue[0]/col, queue[0]%col
		queue = queue[1:]

		// 从该"陆地"开始，往四个方向走一格，看能否扩散
		for i := 0; i < 4; i++ {
			xMove := xDir[i] + x
			yMove := yDir[i] + y

			// 不越界，并且是海洋，则加入扩散队列
			if xMove >= 0 && xMove < col && yMove >= 0 && yMove < col && grid[xMove][yMove] == 0 {
				queue = append(queue, xMove*col+yMove)
				grid[xMove][yMove] = grid[x][y] + 1
			}
		}
	}

	// 全部是陆地或者海洋，则一次都未扩散
	if grid[x][y] == 0 || grid[x][y] == 1 {
		return -1
	}

	// 扩散轮数
	return grid[x][y] - 1
}

func main() {
	a := [][]int{
		{1, 0, 0},
		{0, 0, 0},
		{0, 0, 0},
	}

	fmt.Println(maxDistance(a))
}
```