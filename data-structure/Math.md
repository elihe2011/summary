# 1. 位操作

**一些有趣的位操作：**

```go
// toLower
'a' | ' '   // 'a'
'A' | ' '   // 'a'

// toUpper
'a' & '_'   // 'A'
'A' & '_'   // 'A'

// exchange
'a' ^ ' '   // 'A'
'A' ^ ' '   // 'a'

// 判断两个是是否有异号
x, y := -1, 2
x ^ y < 0  // true 说明有异号

// 不用中间变量交换
x, y := 1, 2
x ^= y
y ^= x
x ^= y


```

## 1.1 [位1的个数](https://leetcode-cn.com/problems/number-of-1-bits/)

```txt
编写一个函数，输入是一个无符号整数（以二进制串的形式），返回其二进制表达式中数字位数为 '1' 的个数（也被称为汉明重量）。
```

分析：使用`n&(n-1)`来消除n的二进制bit中最后一个1

```go
func hammingWeight(num uint32) int {
	var result int

	for num != 0 {
		num = num & (num - 1)
		result++
	}

	return result
}
```

## 1.2 [2的幂](https://leetcode-cn.com/problems/power-of-two/)

```txt
给定一个整数，编写一个函数来判断它是否是 2 的幂次方。

输入: 16
输出: true
解释: 24 = 16

输入: 218
输出: false
```

分析：2^n的特点，二进制bit位中，只有一个1

```go
2^0  0001
2^1  0010
2^2  0100
```

```go
func isPowerOfTwo(n int) bool {
	if n <= 0 {
		return false
	}

	// 2^n的二进制bit位中最多一个1
	return n&(n-1) == 0
}
```

## 1.3 [只出现一次的数字](https://leetcode-cn.com/problems/single-number/)

```txt
给定一个非空整数数组，除了某个元素只出现一次以外，其余每个元素均出现两次。找出那个只出现了一次的元素。

输入: [4,1,2,1,2]
输出: 4
```

**分析: 通过`a^0=a, a^a=0`来实现去除重复的数字**

```go
func singleNumber(nums []int) int {
	var res int
	for _, num := range nums {
		res ^= num
	}
	return res
}
```

## 1.4 [只出现一次的数字 II](https://leetcode-cn.com/problems/single-number-ii/)

```txt
给定一个非空整数数组，除了某个元素只出现一次以外，其余每个元素均出现了三次。找出那个只出现了一次的元素。

输入: [0,1,0,1,0,1,99]
输出: 99
```

分析：为了区分出现一次的数字和出现三次的数字，使用两个位掩码：seen_once 和 seen_twice。

思路是：仅当 seen_twice 未变时，改变 seen_once。仅当 seen_once 未变时，改变seen_twice。

```go
func singleNumber(nums []int) int {
    once, twice := 0, 0

    for _, num := range nums {
        once = ^twice & (once ^ num)
        twice = ^once & (twice ^ num)
    }

    return once
}
```

# 2. 阶乘

## 2.1 [阶乘后的零](https://leetcode-cn.com/problems/factorial-trailing-zeroes/)

```txt
给定一个整数 n，返回 n! 结果尾数中零的数量。

输入: 5
输出: 1
解释: 5! = 120, 尾数中有 1 个零.
```

思路：两数相乘，尾部出现0，必然要出现5，所以乘数中要出现5及5的倍数(10, 15, 20, 25, 30...)，但同时这些倍数中，又会再次出现被5分解的数，如25,125等

```go
func trailingZeroes(n int) int {
	var res = 0
	var divisor = 5

	for divisor <= n {
		res += n / divisor
		divisor *= 5
	}

	return res
}

// 优化，减少向上乘的值扩展
func trailingZeroes(n int) int {
	var res = 0

	for i := n; i >= 5; i = i / 5 {
		res += i / 5
	}

	return res
}
```

## 2.2 [阶乘函数后K个零](https://leetcode-cn.com/problems/preimage-size-of-factorial-zeroes-function/)

```go
f(x) 是 x! 末尾是0的数量。（回想一下 x! = 1 * 2 * 3 * ... * x，且0! = 1）
例如， f(3) = 0 ，因为3! = 6的末尾没有0；而 f(11) = 2 ，因为11!= 39916800末端有2个0。给定 K，找出多少个非负整数x ，有 f(x) = K 的性质。

输入:K = 0
输出:5
解释: 0!, 1!, 2!, 3!, and 4! 均符合 K = 0 的条件。

示例 2:
输入:K = 5
输出:0
解释:没有匹配到这样的 x!，符合K = 5 的条件。
```

解法1：穷举

```go
func preimageSizeFZF(K int) int {
	var res int

	for i := 0; i < MaxInt; i++ {
		val := trailingZeroes(i)
		if val == K {
			res++
		} else if val > K {
			break
		} else {
			continue
		}
	}
    
	return res
}
```

解法2：使用二分查找，优化搜索次数

```go
func preimageSizeFZF(K int) int {
	return rightBound(K) - leftBound(K) + 1
}

const MaxInt = 1<<63 - 1

func leftBound(target int) int {
	lo, hi := 0, MaxInt
	for lo < hi {
		mid := lo + (hi-lo)/2
		val := trailingZeroes(mid)

		if val < target {
			lo = mid + 1
		} else if val > target {
			hi = mid
		} else {
			hi = mid
		}
	}
	return lo
}

func rightBound(target int) int {
	lo, hi := 0, MaxInt
	for lo < hi {
		mid := lo + (hi-lo)/2
		val := trailingZeroes(mid)

		if val < target {
			lo = mid + 1
		} else if val > target {
			hi = mid
		} else {
			lo = mid + 1
		}
	}
	return lo - 1
}
```

# 3. 素数

检查是否素数：时间复杂度 O(N)

```go
func isPrime(n int) bool {
	for i := 2; i < n; i++ {
		if n%i == 0 {
			return false
		}
	}

	return true
}
```

优化：在区间 `[2,sqrt(n)]` 内未发现可整除因子，即可确定 `n` 是素数。时间复杂度 O(sqrt(N))

```txt
12
2 * 6
3 * 4
sqrt(12) * sqrt(12)
4 * 3
6 * 2
```

```go
func isPrime(n int) bool {
	for i := 2; i*i <= n; i++ {
		if n%i == 0 {
			return false
		}
	}

	return true
}
```

## 3.1 [计数质数](https://leetcode-cn.com/problems/count-primes/)

```txt
统计所有小于非负整数 n 的质数的数量。

输入：n = 10
输出：4
解释：小于 10 的质数一共有 4 个, 它们是 2, 3, 5, 7 。
```

解法1：暴力穷举 (n=1500000时，超时)

```go
func countPrimes(n int) int {
    var res int
    for i := 2; i < n; i++ {
        if isPrime(i) {
            res++
        }
    }

    return res
}

func isPrime(n int) bool {
    for i := 2; i*i <= n; i++ {
        if n % i == 0 {
            return false
        }
    }

    return true
}
```

解法2: **Sieve of Eratosthenes 埃拉托斯特尼筛法**

![prime](https://upload.wikimedia.org/wikipedia/commons/b/b9/Sieve_of_Eratosthenes_animation.gif)

时间复杂度：`n/2 + n/3 + n/5 + n/7 + ... = n × (1/2 + 1/3 + 1/5 + 1/7...)`  `O(N*loglogN)`

```python
for i = 2, 3, 4, ..., not exceeding n:
  if A[i] is true:
    for j = i^2, i^2+i, i^2+2i, i^2+3i, ..., not exceeding n :
      A[j] := false
```

```go
func countPrimes(n int) int {
	isPrime := make([]bool, n)
	for i := 2; i < n; i++ {
		isPrime[i] = true
	}

	for i := 2; i < n; i++ {
		if isPrime[i] {
			for j := i * i; j < n; j = j + i {
				isPrime[j] = false
			}
		}
	}

	var count int
	for i := 2; i < n; i++ {
		if isPrime[i] {
			count++
		}
	}

	return count
}
```

# 4. 幂(mi)运算

## 4.1 [超级次方](https://leetcode-cn.com/problems/super-pow/)

```txt
你的任务是计算 a^b 对 1337 取模，a 是一个正整数，b 是一个非常大的正整数且会以数组形式给出。

输入：a = 2, b = [3]
输出：8

输入：a = 1, b = [4,3,3,8,5,2]
输出：1

输入：a = 2147483647, b = [2,0,0]
输出：1198
```

1. 处理数组指数

$$
a^{[1,2,3,4]} = a^{4} * (a^{[1,2,3]})^{10}
$$

2. mod 运算

​     `(a * b) % k = (a % k)(b % k) % k`

3. 高效求幂

$$
a^{b} = \left\{\begin{matrix}
 a * a^{b-1} & b为奇数  \\ 
 (a^{b/2})^{2} & b为偶数
\end{matrix}\right.
$$



```go
const base = 1337

func superPow(a int, b []int) int {
	if a == 1 {
		return 1
	}

	n := len(b)
	if n == 0 {
		return 1
	}

	last := b[n-1]
	b = b[:n-1]

	p1 := pow(a, last)
	p2 := pow(superPow(a, b), 10)

	return (p1 * p2) % base
}

func pow(a, k int) int {
	if k == 0 {
		return 1
	}

	a %= base

	if k%2 == 1 {
		return (a * pow(a, k-1)) % base
	} else {
		sub := pow(a, k/2)
		return (sub * sub) % base
	}
}
```

# 5. 寻找缺失和重复的元素

## 5.1 [找到所有数组中消失的数字](https://leetcode-cn.com/problems/find-all-numbers-disappeared-in-an-array/)

```txt
给定一个范围在  1 ≤ a[i] ≤ n ( n = 数组大小 ) 的 整型数组，数组中的元素一些出现了两次，另一些只出现一次。
找到所有在 [1, n] 范围之间没有出现在数组中的数字。
您能在不使用额外空间且时间复杂度为O(n)的情况下完成这个任务吗? 你可以假定返回的数组不算在额外空间内。

输入: [4,3,2,7,8,2,3,1]
输出: [5,6]
```

思路：原地置换法

- 每个值都有固定的下标与之对应：1-0，2-1, ..., N-(N-1)

- 遍历数组中的每个值n, 通过n-1找到其对应的下标index，并将该index对应的值改为负数，标记这个值当前找到了对应的下标
- 对于已修改为负数的值，取其绝对值进行上述遍历
- 重新遍历整个数组，值为正数的index，在其基础上加1即为缺失的数字

```go
func findDisappearedNumbers(nums []int) []int {
	for _, n := range nums {
		index := abs(n) - 1
		if nums[index] > 0 {
			nums[index] *= -1
		}
	}

	var result []int
	for i := range nums {
		if nums[i] > 0 {
			result = append(result, i+1)
		}
	}

	return result
}

func abs(n int) int {
	if n < 0 {
		n *= -1
	}
	return n
}
```

## 5.2 [错误的集合](https://leetcode-cn.com/problems/set-mismatch/)

```txt
集合 s 包含从 1 到 n 的整数。不幸的是，因为数据错误，导致集合里面某一个数字复制了成了集合里面的另外一个数字的值，导致集合 丢失了一个数字 并且 有一个数字重复 。
给定一个数组 nums 代表了集合 S 发生错误后的结果。
请你找出重复出现的整数，再找到丢失的整数，将它们以数组的形式返回。

输入：nums = [1,2,2,4]
输出：[2,3]
```

```go
func findErrorNums(nums []int) []int {
	var missing, duplicate int

	for _, n := range nums {
		index := abs(n) - 1

		if nums[index] > 0 {
			nums[index] *= -1
		} else {
            duplicate = abs(n)
		}
	}

	for i := range nums {
		if nums[i] > 0 {
			missing = i + 1
			break
		}
	}

	return []int{duplicate, missing}
}
```

# 6. 无限序列随机抽取

水塘抽样算法（Reservoir Sampling），本质上是一种随机概率算法

谷歌算法题：给你一个**未知长度**的链表，请你设计一个算法，**只能遍历一次**，随机地返回链表中的一个节点。

这里说的随机是均匀随机（uniform random），也就是说，如果有 `n` 个元素，每个元素被选中的概率都是 `1/n`，不可以有统计意义上的偏差。

**当你遇到第** **`i`** **个元素时，应该有** **`1/i`** **的概率选择该元素，`1 - 1/i` 的概率保持原有的选择**

**证明**：假设总共有 `n` 个元素，我们要的随机性无非就是每个元素被选择的概率都是 `1/n` 对吧，那么对于第 `i` 个元素，它被选择的概率就是：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/reservoir-sampling.png)

```java
/* 返回链表中一个随机节点的值 */
int getRandom(ListNode head) {
    Random r = new Random();
    int i = 0, res = 0;
    ListNode p = head;
    // while 循环遍历链表
    while (p != null) {
        // 生成一个 [0, i) 之间的整数
        // 这个整数等于 0 的概率就是 1/i
        if (r.nextInt(++i) == 0) {
            res = p.val;
        }
        p = p.next;
    }
    return res;
}
```

## 6.1 [链表随机节点](https://leetcode-cn.com/problems/linked-list-random-node/)

```txt
给定一个单链表，随机选择链表的一个节点，并返回相应的节点值。保证每个节点被选的概率一样。
```

```go
type ListNode struct {
	Val  int
	Next *ListNode
}

type Solution struct {
	head *ListNode
	r    *rand.Rand
}

func Constructor(head *ListNode) Solution {
	return Solution{
		head: head,
		r:    rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

func (this *Solution) GetRandom() int {
	p := this.head.Next
	res := this.head.Val

	var i = 2
	for p != nil {
		//if this.r.Intn(i+1) == i {  // 未能通过
		if this.r.Intn(i) == 0 {
			res = p.Val
		}

		p = p.Next
		i++
	}

	return res
}
```

## 6.2 [随机数索引](https://leetcode-cn.com/problems/random-pick-index/)

```txt
给定一个可能含有重复元素的整数数组，要求随机输出给定的数字的索引。 您可以假设给定的数字一定存在于数组中。

int[] nums = new int[] {1,2,3,3,3};
Solution solution = new Solution(nums);

// pick(3) 应该返回索引 2,3 或者 4。每个索引的返回概率应该相等。
solution.pick(3);

// pick(1) 应该返回 0。因为只有nums[0]等于1。
solution.pick(1);
```

```go
type Solution struct {
	nums []int
	r    *rand.Rand
}

func Constructor(nums []int) Solution {
	return Solution{
		nums: nums,
		r:    rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

func (this *Solution) Pick(target int) int {
	k := 1
	var res int

	for i := range this.nums {
		if this.nums[i] == target {
			if this.r.Intn(k) == 0 {
				res = i
			}

			k++
		}
	}

	return res
}
```

# 7. 一行代码即可解

## 7.1 [Nim 游戏](https://leetcode-cn.com/problems/nim-game/)

```txt
你和你的朋友，两个人一起玩 Nim 游戏：
桌子上有一堆石头。
你们轮流进行自己的回合，你作为先手。
每一回合，轮到的人拿掉 1 - 3 块石头。
拿掉最后一块石头的人就是获胜者。
假设你们每一步都是最优解。请编写一个函数，来判断你是否可以在给定石头数量为 n 的情况下赢得游戏。如果可以赢，返回 true；否则，返回 false 。

输入：n = 4
输出：false 
解释：如果堆中有 4 块石头，那么你永远不会赢得比赛；因为无论你拿走 1 块、2 块 还是 3 块石头，最后一块石头总是会被你的朋友拿走。

输入：n = 1
输出：true
```

```go
func canWinNim(n int) bool {
    return n % 4 != 0
}
```

## 7.2 [石子游戏](https://leetcode-cn.com/problems/stone-game/)

```txt
亚历克斯和李用几堆石子在做游戏。偶数堆石子排成一行，每堆都有正整数颗石子 piles[i] 。
游戏以谁手中的石子最多来决出胜负。石子的总数是奇数，所以没有平局。
亚历克斯和李轮流进行，亚历克斯先开始。 每回合，玩家从行的开始或结束处取走整堆石头。 这种情况一直持续到没有更多的石子堆为止，此时手中石子最多的玩家获胜。
假设亚历克斯和李都发挥出最佳水平，当亚历克斯赢得比赛时返回 true ，当李赢得比赛时返回 false 。

输入：[5,3,4,5]
输出：true
解释：
亚历克斯先开始，只能拿前 5 颗或后 5 颗石子 。
假设他取了前 5 颗，这一行就变成了 [3,4,5] 。
如果李拿走前 3 颗，那么剩下的是 [4,5]，亚历克斯拿走后 5 颗赢得 10 分。
如果李拿走后 5 颗，那么剩下的是 [3,4]，亚历克斯拿走后 4 颗赢得 9 分。
这表明，取前 5 颗石子对亚历克斯来说是一个胜利的举动，所以我们返回 true 。
```

```go
func stoneGame(piles []int) bool {
    return true
}
```

## 7.3 [灯泡开关](https://leetcode-cn.com/problems/bulb-switcher/)

```txt
初始时有 n 个灯泡关闭。
第 1 轮，你打开所有的灯泡。 第 2 轮，每两个灯泡你关闭一次。 第 3 轮，每三个灯泡切换一次开关（如果关闭则开启，如果开启则关闭）。
第 i 轮，每 i 个灯泡切换一次开关。 对于第 n 轮，你只切换最后一个灯泡的开关。
找出 n 轮后有多少个亮着的灯泡。

输入：n = 3
输出：1 
解释：
初始时, 灯泡状态 [关闭, 关闭, 关闭].
第一轮后, 灯泡状态 [开启, 开启, 开启].
第二轮后, 灯泡状态 [开启, 关闭, 开启].
第三轮后, 灯泡状态 [开启, 关闭, 关闭]. 
你应该返回 1，因为只有一个灯泡还亮着。

我们假设只有 6 盏灯，而且我们只看第 6 盏灯。需要进行 6 轮操作对吧，请问对于第 6 盏灯，会被按下几次开关呢？这不难得出，第 1 轮会被按，第 2 轮，第 3 轮，第 6 轮都会被按。
为什么第 1、2、3、6 轮会被按呢？因为 6=1*6=2*3。一般情况下，因子都是成对出现的，也就是说开关被按的次数一般是偶数次。但是有特殊情况，比如说总共有 16 盏灯，那么第 16 盏灯会被按几次?
16=1*16=2*8=4*4
其中因子 4 重复出现，所以第 16 盏灯会被按 5 次，奇数次。现在你应该理解这个问题为什么和平方根有关了吧？
```

![z](https://assets.leetcode.com/uploads/2020/11/05/bulb.jpg)

```go
func bulbSwitch(n int) int {
    return int(math.Sqrt(float64(n)))
}
```



# 8. 概率问题

计算概率的两个最简单原则：

原则一：计算概率一定要有一个参照系，称作「样本空间」，即随机事件可能出现的所有结果。事件 A 发生的概率 = A 包含的样本点 / 样本空间的样本总数。

原则二：计算概率一定要明白，概率是一个连续的整体，不可以把连续的概率分割开，也就是所谓的条件概率。

## 8.1 男孩女孩问题

假设有一个家庭，有两个孩子，现在告诉你其中有一个男孩，请问另一个也是男孩的概率是多少？

很多人，不假思索地回答：1/2 ，因为另一个孩子要么是男孩，要么是女孩，而且概率相等。但是实际正确的答案是 **1/3**。

上述思想为什么错误？因为没有正确计算样本空间，导致原则一计算错误。有两个孩子，那么样本空间为 4：即哥哥妹妹，哥哥弟弟，姐姐妹妹，姐姐弟弟这四种情况。已知有一个男孩，那么排除姐姐妹妹这种情况，所以样本空间变成 3。另一个孩子也是男孩只有哥哥弟弟这 1 种情况，所以概率为 1/3。

为什么计算样本空间会出错呢？因为我们忽略了条件概率，即混淆了下面两个问题：

这个家庭只有一个孩子，这个孩子是男孩的概率是多少？

这个家庭有两个孩子，其中一个是男孩，另一个孩子是男孩的概率是多少？

根据原则二，**概率问题是连续的，不可以把上述两个问题混淆。第二个问题需要用条件概率，即求一个孩子是男孩的条件下，另一个也是男孩的概率**。

## 8.2 生日悖论

生日悖论是由这样一个问题引出的：一个屋子里需要有多少人，才能使得**存在**至少两个人生日是同一天的概率达到 50%？

答案是 23 个人，也就是说房子里如果有 23 个人，那么就有 50% 的概率会存在两个人生日相同。

“存在” 并不意味着一定会出现，概率变化是线性的，就像中奖率 50% 的游戏，你玩两次的中奖率就是 100% 吗？显然不是，你玩两次的中奖率是 75%：

```
P(两次能中奖) = P(第一次就中了) + P(第一次没中但第二次中了) = 1/2 + 1/2*1/2 = 75%
```

为什么只要 23 个人出现相同生日的概率就能大于 50% 了呢？我们先计算 23 个人生日都唯一（不重复）的概率。只有 1 个人的时候，生日唯一的概率是 `365/365`，2 个人时，生日唯一的概率是 `365/365 × 364/365`，以此类推可知 23 人的生日都唯一的概率：
$$
P(A') = \frac{365}{365} \times \frac{364}{365} \times \frac{363}{365} \times \frac{362}{365} \times \cdot \cdot \cdot  \times \frac{343}{365} 
$$
算出来大约是 0.493，所以存在相同生日的概率就是 0.507，差不多就是 50% 了。实际上，按照这个算法，当人数达到 70 时，存在两个人生日相同的概率就上升到了 99.9%，基本可以认为是 100% 了。所以从概率上说，一个几十人的小团体中存在生日相同的人真没啥稀奇的。

## 8.3 三门问题

很经典的游戏：游戏参与者面对三扇门，其中两扇门后面是山羊，一扇门后面是跑车。参与者只要随便选一扇门，门后面的东西就归他（跑车的价值当然更大）。但是主持人决定帮一下参与者：在他选择之后，先不急着打开这扇门，而是由主持人打开剩下两扇门中的一扇，展示其中的山羊（主持人知道每扇门后面是什么），然后给参与者一次换门的机会，此时参与者应该换门还是不换门呢？

为了防止第一次看到这个问题的读者迷惑，再具体描述一下这个问题：

你是游戏参与者，现在有门 1,2,3，假设你随机选择了门 1，然后主持人打开了门 3 告诉你那后面是山羊。现在，你是坚持你最初的选择门 1，还是选择换成门 2 呢？

![](https://gblobscdn.gitbook.com/assets%2F-MS38NtlQPprrWHTMIJv%2Fsync%2F121a3cfd141366864d07801242f63419967c0fd7.png?alt=media)

答案是应该换门，换门之后抽到跑车的概率是 2/3，不换的话是 1/3。又一次反直觉，感觉换不换的中奖概率应该都一样啊，因为最后肯定就剩两个门，一个是羊，一个是跑车，这是事实，所以不管选哪个的概率不都是 1/2 吗？

类似前面说的男孩女孩问题，最简单稳妥的方法就是把所有可能结果穷举出来：

![](https://gblobscdn.gitbook.com/assets%2F-MS38NtlQPprrWHTMIJv%2Fsync%2F98c51178dafb2624463f680670ae93345873a3e5.png?alt=media)

# 9. 数组

## 9.1 前缀和数组

前缀和主要用于处理数组区间的问题

### 9.1.1 前缀和

```go
func prefixSum(nums []int) []int {
	n := len(nums)
	preSum := make([]int, n+1)
	preSum[0] = 0

	for i := 0; i < n; i++ {
		preSum[i+1] = preSum[i] + nums[i]
	}

	return preSum[1:]
}
```

### 9.1.2 [和为K的子数组](https://leetcode-cn.com/problems/subarray-sum-equals-k/)

```txt
给定一个整数数组和一个整数 k，你需要找到该数组中和为 k 的连续的子数组的个数。

输入:nums = [1,1,1], k = 2
输出: 2 , [1,1] 与 [1,1] 为两种不同的情况。
```

```go
func subarraySum(nums []int, k int) int {
	n := len(nums)
	preSum := make([]int, n+1)
	preSum[0] = 0
	for i := 0; i < n; i++ {
		preSum[i+1] = preSum[i] + nums[i]
	}

	var res int
	for i := 1; i <= n; i++ {
		for j := 0; j < i; j++ {
			// sum of nums[j...i-1]
			if preSum[i]-preSum[j] == k {
				res++
			}
		}
	}

	return res
}
```

### 9.1.3 分数统计

```java
int[] scores; // 存储着所有同学的分数
// 试卷满分 150 分
int[] count = new int[150 + 1]
// 记录每个分数有几个同学
for (int score : scores)
    count[score]++
// 构造前缀和
for (int i = 1; i < count.length; i++)
    count[i] = count[i] + count[i-1];
```



## 9.2 查分数组

**差分数组：主要适用场景是频繁对原始数组的某个区间的元素进行增减**。

### 9.2.1 差分数组

相邻两个元素的差值

```go
func diffArray(nums []int) []int {
	n := len(nums)
    
    // 差分数组
	diff := make([]int, n)
	diff[0] = nums[0]
	for i := 1; i < n; i++ {
		diff[i] = nums[i] - nums[i-1]
	}
    
    // 根据差分数组，构造结果数组
    res := make([]int, n)
	res[0] = diff[0]
	for i := 1; i < n; i++ {
		res[i] = res[i-1] + diff[i]
	}

	return diff
}
```

### 9.2.2 [航班预订统计](https://leetcode-cn.com/problems/corporate-flight-bookings/)

```txt
这里有 n 个航班，它们分别从 1 到 n 进行编号。
我们这儿有一份航班预订表，表中第 i 条预订记录 bookings[i] = [j, k, l] 意味着我们在从 j 到 k 的每个航班上预订了 l 个座位。
请你返回一个长度为 n 的数组 answer，按航班编号顺序返回每个航班上预订的座位数。

输入：bookings = [[1,2,10],[2,3,20],[2,5,25]], n = 5
输出：[10,55,45,25,25]

使用差分数组：
定义：如果有一个数组arr，它的差分数组diffArr定义如下：
diffArr[0] = arr[0]
diffArr[i] = arr[i] - arr[i - 1]

计算：这样，如果要对原始数组arr的[i, j]区间的元素全部加某个值value，对应到其查分数组中时，只需要对查分数组进行如下O(1)复杂度的操作即可。
diffArr[i] += value
diffArr[j + 1] -= value （j + 1 < n时）

还原：把对原始数组的一系列区间加减操作映射到其查分数组的计算操作之后，这个查分数组还原成原数组，即可得到原数组经过这一系列操作之后的状态。还原方法如下：
arr[0] = diffArr[0]
arr[i] = diffArr[i] + arr[i - 1]
```



```go
func corpFlightBookings(bookings [][]int, n int) []int {
	diff := make([]int, n)

	for _, booking := range bookings {
		i, j := booking[0]-1, booking[1]-1
		val := booking[2]

		diff[i] += val
		if j+1 < n {
			diff[j+1] -= val
		}
	}

	answer := make([]int, n)
	answer[0] = diff[0]
	for i := 1; i < n; i++ {
		answer[i] = diff[i] + answer[i-1]
	}

	return answer
}
```



