# 1. [扁平化嵌套列表迭代器](https://leetcode-cn.com/problems/flatten-nested-list-iterator/)

```txt
输入: [1,[4,[6]]]
输出: [1,4,6]
解释: 通过重复调用 next 直到 hasNext 返回 false，next 返回的元素的顺序应该是: [1,4,6]。
```

```go
/**
 * // This is the interface that allows for creating nested lists.
 * // You should not implement it, or speculate about its implementation
 * type NestedInteger struct {
 * }
 *
 * // Return true if this NestedInteger holds a single integer, rather than a nested list.
 * func (this NestedInteger) IsInteger() bool {}
 *
 * // Return the single integer that this NestedInteger holds, if it holds a single integer
 * // The result is undefined if this NestedInteger holds a nested list
 * // So before calling this method, you should have a check
 * func (this NestedInteger) GetInteger() int {}
 *
 * // Set this NestedInteger to hold a single integer.
 * func (n *NestedInteger) SetInteger(value int) {}
 *
 * // Set this NestedInteger to hold a nested list and adds a nested integer to it.
 * func (this *NestedInteger) Add(elem NestedInteger) {}
 *
 * // Return the nested list that this NestedInteger holds, if it holds a nested list
 * // The list length is zero if this NestedInteger holds a single integer
 * // You can access NestedInteger's List element directly if you want to modify it
 * func (this NestedInteger) GetList() []*NestedInteger {}
 */

type NestedInteger struct {
	obj interface{}
}

func (this NestedInteger) IsInteger() bool {
	if _, ok := this.obj.(int); ok {
		return true
	}
	return false
}

func (this NestedInteger) GetInteger() int {
	if !this.IsInteger() {
		panic("non-integer")
	}
	return this.obj.(int)
}

func (this *NestedInteger) SetInteger(value int) {
	this.obj = value
}

func (this *NestedInteger) Add(elem NestedInteger) {
	this.obj = elem
}

func (this NestedInteger) GetList() []*NestedInteger {
	var a []*NestedInteger

	if this.IsInteger() {
		a = append(a, &this)
	} else {
		elems := this.obj.([]*NestedInteger)
		for i := 0; i < len(elems); i++ {
			a = append(a, elems[i])
		}
	}

	return a
}

/**************************************************/
type NestedIterator struct {
	L []*NestedInteger
}

func Constructor(nestedList []*NestedInteger) *NestedIterator {
	return &NestedIterator{L: nestedList}
}

func (this *NestedIterator) Next() int {
	value := this.L[0]
	this.L = this.L[1:]
	return value.GetInteger()
}

func (this *NestedIterator) HasNext() bool {
	if len(this.L) == 0 {
		return false
	}

	if this.L[0].IsInteger() {
		return true
	}

	this.L = append(this.L[0].GetList(), this.L[1:]...)
	return this.HasNext()
}

func main() {
	n1 := NestedInteger{1}
	n4 := NestedInteger{4}
	n6 := NestedInteger{6}

	a6 := NestedInteger{[]*NestedInteger{&n6}}
	a46 := NestedInteger{[]*NestedInteger{&n4, &a6}}
	//a146 := NestedInteger{[]*NestedInteger{&n1, &a46}}

	it := Constructor([]*NestedInteger{&n1, &a46})
	for it.HasNext() {
		fmt.Println(it.Next())
	}
}
```



# 2. 数据流中的中位数

算法：

1. 两个优先级队列（栈）

   - 最大堆lo: 存储较小一半数字，top最大

   - 最小堆hi: 存储较大一半数字，top最小

2. lo允许比hi多一个元素
3. 添加一个数`num`
   - 将`num`添加到lo中，然后将`lo.top`移到hi中
   - 如果`len(hi) > len(lo)`, 将`hi.top`移到lo中

```go
type MaxHeap []int

func (h MaxHeap) Len() int            { return len(h) }
func (h MaxHeap) Less(i, j int) bool  { return h[i] > h[j] } // sort from large to small
func (h MaxHeap) Swap(i, j int)       { h[i], h[j] = h[j], h[i] }
func (h MaxHeap) Top() int            { return h[0] }
func (h *MaxHeap) Push(x interface{}) { *h = append(*h, x.(int)) }
func (h *MaxHeap) Pop() interface{} {
	n := (*h).Len()
	x := (*h)[n-1]
	*h = (*h)[:n-1]
	return x
}

type MinHeap []int

func (h MinHeap) Len() int            { return len(h) }
func (h MinHeap) Less(i, j int) bool  { return h[i] < h[j] } // sort from small to large
func (h MinHeap) Swap(i, j int)       { h[i], h[j] = h[j], h[i] }
func (h MinHeap) Top() int            { return h[0] }
func (h *MinHeap) Push(x interface{}) { *h = append(*h, x.(int)) }
func (h *MinHeap) Pop() interface{} {
	n := (*h).Len()
	x := (*h)[n-1]
	*h = (*h)[:n-1]
	return x
}

type MedianFinder struct {
	lo *MaxHeap // 头元素存储最大值
	hi *MinHeap // 头元素存储最小值
}

/** initialize your data structure here. */
func Constructor() MedianFinder {
	return MedianFinder{
		lo: &MaxHeap{},
		hi: &MinHeap{},
	}
}

func (this *MedianFinder) AddNum(num int) {
	if (*this.lo).Len() == (*this.hi).Len() {
		heap.Push(this.hi, num)
		heap.Push(this.lo, heap.Pop(this.hi))
	} else {
		heap.Push(this.lo, num)
		heap.Push(this.hi, heap.Pop(this.lo))
	}
}

func (this *MedianFinder) FindMedian() float64 {
	if (*this.lo).Len() == (*this.hi).Len() {
		return float64(this.lo.Top()+this.hi.Top()) * 0.5
	} else {
		return float64(this.lo.Top())
	}
}

func main() {
	obj := Constructor()
	for i := 1; i < 6; i++ {
		obj.AddNum(i * (-1))
		fmt.Println(obj.lo, obj.hi, obj.FindMedian())
		fmt.Println("--------------------")
	}
}
```

# 3. 二分查找

二分查找技巧，算法的时间复杂度为 O(NlogN)

## 3.1 [爱吃香蕉的珂珂](https://leetcode-cn.com/problems/koko-eating-bananas/)

```txt
珂珂喜欢吃香蕉。这里有 N 堆香蕉，第 i 堆中有 piles[i] 根香蕉。警卫已经离开了，将在 H 小时后回来。

珂珂可以决定她吃香蕉的速度 K （单位：根/小时）。每个小时，她将会选择一堆香蕉，从中吃掉 K 根。如果这堆香蕉少于 K 根，她将吃掉这堆的所有香蕉，然后这一小时内不会再吃更多的香蕉。  

珂珂喜欢慢慢吃，但仍然想在警卫回来前吃掉所有的香蕉。

返回她可以在 H 小时内吃掉所有香蕉的最小速度 K（K 为整数）。

输入: piles = [3,6,7,11], H = 8
输出: 4
```

```go
func minEatingSpeed1(piles []int, H int) int {
	max := getMax(piles)

	for speed := 1; speed < max; speed++ {
		if canFinish(piles, speed, H) {
			return speed
		}
	}

	return max
}

func minEatingSpeed(piles []int, H int) int {
	max := getMax(piles)

    // 二分查找核心代码
	left, right := 1, max+1
	for left < right {
		mid := left + (right-left)/2
		if canFinish(piles, mid, H) {
			right = mid
		} else {
			left = mid + 1
		}
	}
	return left
}

func getMax(piles []int) int {
	max := 0
	for i := 0; i < len(piles); i++ {
		if max < piles[i] {
			max = piles[i]
		}
	}
	return max
}

func canFinish(piles []int, speed, H int) bool {
	h := 0
	for i := 0; i < len(piles); i++ {
		h += timeIt(piles[i], speed)
	}

	return h <= H
}

func timeIt(num, speed int) int {
	h := num / speed
	if num%speed > 0 {
		h++
	}
	return h
}
```

## 3.2 [在 D 天内送达包裹的能力](https://leetcode-cn.com/problems/capacity-to-ship-packages-within-d-days/)

```txt
传送带上的包裹必须在 D 天内从一个港口运送到另一个港口。

传送带上的第 i 个包裹的重量为 weights[i]。每一天，我们都会按给出重量的顺序往传送带上装载包裹。我们装载的重量不会超过船的最大运载重量。

返回能在 D 天内将传送带上的所有包裹送达的船的最低运载能力。

输入：weights = [1,2,3,4,5,6,7,8,9,10], D = 5
输出：15
解释：
船舶最低载重 15 就能够在 5 天内送达所有包裹，如下所示：
第 1 天：1, 2, 3, 4, 5
第 2 天：6, 7
第 3 天：8
第 4 天：9
第 5 天：10

请注意，货物必须按照给定的顺序装运，因此使用载重能力为 14 的船舶并将包装分成 (2, 3, 4, 5), (1, 6, 7), (8), (9), (10) 是不允许的。 
```

```go
func shipWithinDays(weights []int, D int) int {
    left, right := getMaxAndSum(weights)
    right += 1

    for left < right {
        mid := left + (right-left)/2
        if canFinish(weights, mid, D) {
            right = mid
        } else {
            left = mid + 1
        }
    }

    return left
}

func getMaxAndSum(w []int) (int, int) {
    max, sum := 0, 0
    for i := 0; i < len(w); i++ {
        if max < w[i] {
            max = w[i]
        }
        sum += w[i]
    }
    return max, sum
}

func canFinish(w []int, cap, D int) bool {
    i := 0
    for day := 0; day < D; day++ {
        maxCap := cap
        for maxCap - w[i] >= 0 {
            maxCap -= w[i]
            i++
            if i == len(w) {
                return true
            }
        }
    }

    return false
}
```



# 4. 滑动窗口

链表：快慢指针

字符串：滑动窗口

数组反转：左右指针

归并排序：二分搜索



滑动窗口算法框架：

```cpp
/* 滑动窗口算法框架 */
void slidingWindow(string s, string t) {
    unordered_map<char, int> need, window;
    for (char c : t) need[c]++;

    int left = 0, right = 0;
    int valid = 0; 
    while (right < s.size()) {
        // c 是将移入窗口的字符
        char c = s[right];
        // 右移窗口
        right++;
        // 进行窗口内数据的一系列更新
        ...

        /*** debug 输出的位置 ***/
        printf("window: [%d, %d)\n", left, right);
        /********************/

        // 判断左侧窗口是否要收缩
        while (window needs shrink) {
            // d 是将移出窗口的字符
            char d = s[left];
            // 左移窗口
            left++;
            // 进行窗口内数据的一系列更新
            ...
        }
    }
}
```

## 4.1 [最小覆盖子串](https://leetcode-cn.com/problems/minimum-window-substring/)

```txt
给你一个字符串 s 、一个字符串 t 。返回 s 中涵盖 t 所有字符的最小子串。如果 s 中不存在涵盖 t 所有字符的子串，则返回空字符串 "" 。

注意：如果 s 中存在这样的子串，我们保证它是唯一的答案。

输入：s = "ADOBECODEBANC", t = "ABC"
输出："BANC"
```

```go
func minWindow(s, t string) string {
	window := make(map[byte]int)
	wanted := make(map[byte]int)

	for i := 0; i < len(t); i++ {
		wanted[t[i]]++
	}

	left, right := 0, 0
	start, length := -1, len(s)+1 // +1 防止 t == s
	valid := 0

	for right < len(s) {
		// 滑动右窗口
		c := s[right]
		right++

		if _, ok := wanted[c]; ok {
			window[c]++
			if window[c] == wanted[c] {
				valid++
			}
		}

		fmt.Println(right, left, valid)

		// 找到全部需要的字符，进行收缩，注意是len(wanted)
		for valid == len(wanted) {
			fmt.Printf("%d - %d = %d\n", left, right, right-left)
			// 重置最小字符
			if right-left < length {
				start = left
				length = right - left
			}

			// 滑动左窗口
			d := s[left]
			left++

			if _, ok := wanted[d]; ok {
				if wanted[d] == window[d] {
					valid--
				}
				window[d]--
			}
		}
	}

	if start == -1 {
		return ""
	}

	fmt.Println(start, length)
	return s[start : start+length]
}
```

## 4.2 [字符串的排列](https://leetcode-cn.com/problems/permutation-in-string/)

```txt
给定两个字符串 s1 和 s2，写一个函数来判断 s2 是否包含 s1 的排列。

输入: s1 = "ab" s2 = "eidbaooo"
输出: True
解释: s2 包含 s1 的排列之一 ("ba").
```



```go
func checkInclusion(t, s string) bool {
	window := make(map[byte]int)
	wanted := make(map[byte]int)

	for i := 0; i < len(t); i++ {
		wanted[t[i]]++
	}

	left, right := 0, 0
	valid := 0

	for right < len(s) {
		c := s[right]
		right++

		if _, ok := wanted[c]; ok {
			window[c]++
			if wanted[c] == window[c] {
				valid++
			}
		}

		for right-left >= len(t) {
			if valid == len(wanted) {
				return true
			}

			d := s[left]
			left++

			if _, ok := wanted[d]; ok {
				if wanted[d] == window[d] {
					valid--
				}
				window[d]--
			}
		}
	}

	return false
}
```

## 4.3 [找到字符串中所有字母异位词](https://leetcode-cn.com/problems/find-all-anagrams-in-a-string/)

```txt
给定一个字符串 s 和一个非空字符串 p，找到 s 中所有是 p 的字母异位词的子串，返回这些子串的起始索引。

说明：
字母异位词指字母相同，但排列不同的字符串。
不考虑答案输出的顺序。

输入:
s: "cbaebabacd" p: "abc"

输出:
[0, 6]

解释:
起始索引等于 0 的子串是 "cba", 它是 "abc" 的字母异位词。
起始索引等于 6 的子串是 "bac", 它是 "abc" 的字母异位词。
```

```go
func findAnagrams(s, p string) []int {
	var ans []int

	window := make(map[byte]int)
	wanted := make(map[byte]int)

	for i := 0; i < len(p); i++ {
		wanted[p[i]]++
	}

	left, right := 0, 0
	valid := 0

	for right < len(s) {
		c := s[right]
		right++

		if _, ok := wanted[c]; ok {
			window[c]++
			if wanted[c] == window[c] {
				valid++
			}
		}

		for right-left >= len(p) {
			if valid == len(wanted) {
				ans = append(ans, left)
			}

			d := s[left]
			left++

			if _, ok := wanted[d]; ok {
				if wanted[d] == window[d] {
					valid--
				}
				window[d]--
			}
		}
	}

	return ans
}
```

## 4.4 [无重复字符的最长子串](https://leetcode-cn.com/problems/longest-substring-without-repeating-characters/)

```txt
给定一个字符串，请你找出其中不含有重复字符的 最长子串 的长度。

输入: s = "abcabcbb"
输出: 3 
解释: 因为无重复字符的最长子串是 "abc"，所以其长度为 3。
```

```go
func lengthOfLongestSubstring(s string) int {
	var ans int

	window := make(map[byte]int)
	left, right := 0, 0

	for right < len(s) {
		c := s[right]
		right++

		window[c]++

		for window[c] > 1 {
			d := s[left]
			left++

			window[d]--
		}

		if right-left > ans {
			ans = right - left
		}
	}

	return ans
}
```



# 5. 数组元素维护

## 5.1 [常数时间插入、删除和获取随机元素](https://leetcode-cn.com/problems/insert-delete-getrandom-o1/)

```txt
设计一个支持在平均 时间复杂度 O(1) 下，执行以下操作的数据结构。

insert(val)：当元素 val 不存在时，向集合中插入该项。
remove(val)：元素 val 存在时，从集合中移除该项。
getRandom：随机返回现有集合中的一项。每个元素应该有相同的概率被返回。
```

```go
type RandomizedSet struct {
	list []int
	data map[int]int
}

/** Initialize your data structure here. */
func Constructor() RandomizedSet {
	return RandomizedSet{data: make(map[int]int)}
}

/** Inserts a value to the set. Returns true if the set did not already contain the specified element. */
func (this *RandomizedSet) Insert(val int) bool {
	if _, ok := this.data[val]; ok {
		return false
	}

	this.list = append(this.list, val)
	this.data[val] = len(this.list) - 1
	return true
}

/** Removes a value from the set. Returns true if the set contained the specified element. */
func (this *RandomizedSet) Remove(val int) bool {
	if n, ok := this.data[val]; ok {
		length := len(this.list)
		if n != length-1 {
			transVal := this.list[length-1]
			this.list[n] = transVal
			this.data[transVal] = n
		}

		this.list = this.list[:length-1]
		delete(this.data, val)

		return true
	}

	return false
}

/** Get a random element from the set. */
func (this *RandomizedSet) GetRandom() int {
	rand.Seed(time.Now().UnixNano())
	n := rand.Intn(len(this.list))
	return this.list[n]
}
```

## 5.2 [黑名单中的随机数](https://leetcode-cn.com/problems/random-pick-with-blacklist/)

```txt
给定一个包含 [0，n ) 中独特的整数的黑名单 B，写一个函数从 [ 0，n ) 中返回一个不在 B 中的随机整数。
对它进行优化使其尽量少调用系统方法 Math.random() 。

提示:
1 <= N <= 1000000000
0 <= B.length < min(100000, N)
[0, N) 不包含 N，详细参见 interval notation 。

输入: 
["Solution","pick","pick","pick"]
[[1,[]],[],[],[]]
输出: [null,0,0,0]
```

```go
type Solution struct {
	size    int
	mapping map[int]int
}

func Constructor(N int, blacklist []int) Solution {
	size := N - len(blacklist)
	mapping := make(map[int]int)
	for _, v := range blacklist {
		mapping[v] = 0
	}

	last := N - 1
	for _, v := range blacklist {
		if v >= size {
			continue
		}

		for {
			if _, ok := mapping[last]; ok {
				last--
			} else {
				break
			}
		}

		mapping[v] = last
		last--
	}

	return Solution{
		size:    size,
		mapping: mapping,
	}
}

func (this *Solution) Pick() int {
	rand.Seed(time.Now().UnixNano())
	n := rand.Intn(this.size)

	if v, ok := this.mapping[n]; ok {
		return v
	}

	return n
}
```

# 6. 原地修改数组

慢指针 `slow` 走在后面，快指针 `fast` 走在前面探路，找到一个不重复的元素就告诉 `slow` 并让 `slow` 前进一步

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/array-double-pointer.gif)

## 6.1 [删除排序数组中的重复项](https://leetcode-cn.com/problems/remove-duplicates-from-sorted-array/)

```txt
给定一个排序数组，你需要在 原地 删除重复出现的元素，使得每个元素只出现一次，返回移除后数组的新长度。
不要使用额外的数组空间，你必须在 原地 修改输入数组 并在使用 O(1) 额外空间的条件下完成。

给定 nums = [0,0,1,1,1,2,2,3,3,4],
函数应该返回新的长度 5, 并且原数组 nums 的前五个元素被修改为 0, 1, 2, 3, 4。
```

```go
func removeDuplicates(nums []int) int {
    n := len(nums)
    slow, fast := 0, 0

    for fast < n {
        if nums[fast] != nums[slow] {
            slow++
            nums[slow] = nums[fast]
        }
        fast++
    }

    return slow+1
}
```

## 6.2 [删除排序链表中的重复元素](https://leetcode-cn.com/problems/remove-duplicates-from-sorted-list/)

```txt
给定一个排序链表，删除所有重复的元素，使得每个元素只出现一次。

输入: 1->1->2->3->3
输出: 1->2->3
```

```go
func deleteDuplicates(head *ListNode) *ListNode {
    if head == nil {
        return head
    }
    
    slow, fast := head, head

    for fast != nil {
        if slow.Val != fast.Val {
            slow = slow.Next
            slow.Val = fast.Val  // 去修改值，不要尝试 slow.Next = fast
        }
        fast = fast.Next 
    }

    slow.Next = nil
    return head
}
```

## 6.3 [移除元素](https://leetcode-cn.com/problems/remove-element/)

```txt
给你一个数组 nums 和一个值 val，你需要 原地 移除所有数值等于 val 的元素，并返回移除后数组的新长度。
不要使用额外的数组空间，你必须仅使用 O(1) 额外空间并 原地 修改输入数组。
元素的顺序可以改变。你不需要考虑数组中超出新长度后面的元素。

给定 nums = [0,1,2,2,3,0,4,2], val = 2,
函数应该返回新的长度 5, 并且 nums 中的前五个元素为 0, 1, 3, 0, 4。
```

```go
func removeElement(nums []int, val int) int {
    slow, fast := 0, 0
    for fast < len(nums) {
        if nums[fast] != val {
            nums[slow] = nums[fast]
            slow++
        }
        fast++
    }
    return slow
}

// 逻辑更清晰
func removeElement(nums []int, val int) int {
	n := len(nums)
	slow, fast := 0, 0

	for fast < n {
		if nums[slow] != val && nums[fast] != val {
			slow++
			fast++
		} else if nums[slow] != val && nums[fast] == val {
			fast++
		} else if nums[slow] == val && nums[fast] != val {
			nums[slow], nums[fast] = nums[fast], nums[slow]
			slow++
			fast++
		} else {
			fast++
		}
	}

	return slow
}
```

## 6.4 [移动零](https://leetcode-cn.com/problems/move-zeroes/)

```txt
给定一个数组 nums，编写一个函数将所有 0 移动到数组的末尾，同时保持非零元素的相对顺序。

输入: [0,1,0,3,12]
输出: [1,3,12,0,0]
```

```go
func moveZeroes(nums []int)  {
    slow, fast := 0, 0
    for fast < len(nums) {
        if nums[fast] != 0 {
            nums[slow], nums[fast] = nums[fast], nums[slow]
            slow++
        }
        fast++
    }
}

// 逻辑更清晰
func moveZeroes(nums []int) {
	n := len(nums)
	slow, fast := 0, 0

	for fast < n {
		if nums[slow] != 0 && nums[fast] != 0 {
			slow++
			fast++
		} else if nums[slow] != 0 && nums[fast] == 0 {
			fast++
		} else if nums[slow] == 0 && nums[fast] != 0 {
			nums[slow], nums[fast] = nums[fast], nums[slow]
			slow++
			fast++
		} else {
			fast++
		}
	}
}
```

# 7. twoNum

## 7.1 [两数之和](https://leetcode-cn.com/problems/two-sum/)

```txt
给定一个整数数组 nums 和一个整数目标值 target，请你在该数组中找出 和为目标值 的那 两个 整数，并返回它们的数组下标。
你可以假设每种输入只会对应一个答案。但是，数组中同一个元素不能使用两遍。

输入：nums = [2,7,11,15], target = 9
输出：[0,1]
解释：因为 nums[0] + nums[1] == 9 ，返回 [0, 1] 。
```

```go
func twoSum(nums []int, target int) []int {
    mapping := make(map[int]int, len(nums))

    for i := 0; i < len(nums); i++ {
        val := target - nums[i]
        if j, ok := mapping[val]; ok {
            return []int{i, j}
        } else {
            mapping[nums[i]] = i  // 不存在，先放map中
        }
    }

    return []int{-1, -1}
}
```

对于有序列表：

```cpp
int[] twoSum(int[] nums, int target) {
    int left = 0, right = nums.length - 1;
    while (left < right) {
        int sum = nums[left] + nums[right];
        if (sum == target) {
            return new int[]{left, right};
        } else if (sum < target) {
            left++; // 让 sum 大一点
        } else if (sum > target) {
            right--; // 让 sum 小一点
        }
    }
    // 不存在这样两个数
    return new int[]{-1, -1};
}
```



## 7.2 两数之和 III - 数据结构设计（简单）

```txt
设计并实现一个 TwoSum 的类，使该类需要支持 add 和 find 的操作。
add 操作 - 对内部数据结构增加一个数。
find 操作 - 寻找内部数据结构中是否存在一对整数，使得两数之和与给定的数相等。

示例：
add(1); add(3); add(5);
find(4) -> true
find(7) -> false
```

```go
type TwoNum struct {
	data map[int]int
}

func Constructor() TwoNum {
	return TwoNum{data: make(map[int]int)}
}

func (t *TwoNum) Add(num int) {
	t.data[num]++
}

func (t *TwoNum) Find(val int) bool {
	for k, c := range t.data {
		other := val - k

		// 相同的值，需保证至少两个
		if other == val && c >= 2 {
			return true
		}

		if _, ok := t.data[other]; ok {
			return true
		}
	}

	return false
}
```

