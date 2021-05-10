# 1. 标准二分查找

特征：

- 序列有序
- 时间复杂度低于 `O(n)`, 或者直接为 `O(log n)`

```go
func BinarySearchStandard(nums []int, target int) int {
	left, right := 0, len(nums)-1

	for left <= right {
		mid := left + ((right - left) >> 1)
		if nums[mid] == target {
			return mid
		} else if nums[mid] > target {
			right = mid - 1
		} else {
			left = mid + 1
		}
	}

	return -1
}
```



Leet Code [69. x 的平方根](https://leetcode-cn.com/problems/sqrtx/)

```txt
实现 int sqrt(int x) 函数。
计算并返回 x 的平方根，其中 x 是非负整数。
由于返回类型是整数，结果只保留整数的部分，小数部分将被舍去。

示例 1:
输入: 4
输出: 2
示例 2:

输入: 8
输出: 2
说明: 8 的平方根是 2.82842..., 由于返回类型是整数，小数部分将被舍去。
```

```go
func MySqrt(x int) int {
	left, right := 1, x/2

	for left <= right {
		mid := left + (right-left)/2

		if mid*mid > x {
			right = mid - 1
		} else if mid*mid < x {
			if (mid+1)*(mid+1) > x {
				return mid
			}
			left = mid + 1
		} else {
			return mid
		}
	}

	return 1
}
```



# 2. 二分查找左边界

三种情况：

1. 数组有序，但包含重复元素  [278. 第一个错误的版本](https://leetcode-cn.com/problems/first-bad-version/) 

2. 数组部分有序，且不包含重复元素 [153. 寻找旋转排序数组中的最小值](https://leetcode-cn.com/problems/find-minimum-in-rotated-sorted-array/)

3. 数组部分有序，且包含重复元素 [154. 寻找旋转排序数组中的最小值 II](https://leetcode-cn.com/problems/find-minimum-in-rotated-sorted-array-ii/)

```go
// 适合 1 & 2
func BinarySearchLeftBoundary1(nums []int, target int) int {
	left, right := 0, len(nums)-1

	for left < right {
		mid := left + (right-left)/2
		if nums[mid] < target {
			left = mid + 1
		} else {
			right = mid // 找到目标值后，继续向左寻找左边界
		}
	}

	if nums[left] == target {
		return left
	}

	return -1
}

// 适合 3
func BinarySearchLeftBoundary2(nums []int, target int) int {
	left, right := 0, len(nums)-1

	for left < right {
		mid := left + (right-left)/2
		if nums[mid] < target {
			left = mid + 1
		} else if nums[mid] > target {
			right = mid // 找到目标值后，继续向左寻找左边界
		} else {
			right-- // 更保守的右边值收缩，防止跳过目标边界导致遗漏
		}
	}

	if nums[left] == target {
		return left
	}

	return -1
}
```

## 2.1 leetcode [278. 第一个错误的版本](https://leetcode-cn.com/problems/first-bad-version/) 

解题：有这么一个数组：`[false, false, false, ..., fasle, true, true, ..., true]`，求最左侧true的位置

```go
/** 
 * Forward declaration of isBadVersion API.
 * @param   version   your guess about first bad version
 * @return 	 	      true if current version is bad 
 *			          false if current version is good
 * func isBadVersion(version int) bool;
 */

func firstBadVersion(n int) int {
    left, right := 1, n
    for left < right {
        mid := left + (right-left)/2
        if isBadVersion(mid) {
            right = mid  // mid 是错误的版本，向左收缩
        } else {
            left = mid+1 // mid 是正确的版本，向右扩展
        }
    }

    if isBadVersion(left) {
        return left
    }

    return -1
}
```



## 2.2 leetcode [153. 寻找旋转排序数组中的最小值](https://leetcode-cn.com/problems/find-minimum-in-rotated-sorted-array/)

旋转数组

```
输入：nums = [4,5,6,7,0,1,2]
输出：0
解释：原数组为 [0,1,2,4,5,6,7] ，旋转 4 次得到输入数组。
```

```go
func findMin(nums []int) int {
    n := len(nums)-1
    left, right := 0, n

    for left < right {
        mid := left + (right-left)/2
        if nums[mid] > nums[n] {
            left = mid+1
        } else {
            right = mid
        }
    }

    return nums[left]
}
```



## 2.3 leetcode [154. 寻找旋转排序数组中的最小值 II](https://leetcode-cn.com/problems/find-minimum-in-rotated-sorted-array-ii/)

数组中包含重复元素：

```
输入：nums = [2,2,2,0,1]
输出：0
```

```go
func findMin(nums []int) int {
    left, right := 0, len(nums)-1
    for left < right {
        mid := left + (right-left)/2
        if nums[mid] > nums[right] {
            left = mid + 1  // mid 位于旋转点左侧
        } else if nums[mid] < nums[right] {
            right = mid     // mid 位于旋转点右侧
        } else {
            right--   // 相等时，向左查找左边界，所以直接收缩有边界
        }
    }

    return nums[right]
}
```



## 2.4 leetcode [744. 寻找比目标字母大的最小字母](https://leetcode-cn.com/problems/find-smallest-letter-greater-than-target/)

给你一个排序后的字符列表 letters ，列表中只包含小写英文字母。另给出一个目标字母 target，请你寻找在这一有序列表里比目标字母大的最小字母。

在比较时，字母是依序循环出现的。如果目标字母 target = 'z' 并且字符列表为 letters = ['a', 'b']，则答案返回 'a'

```go
func nextGreatestLetter(letters []byte, target byte) byte {
	n := len(letters) - 1
	left, right := 0, len(letters)-1
	for left < right {
		mid := left + (right-left)/2
		if letters[mid] <= target {
			left = mid + 1
		} else {
			right = mid
		}
	}

	return letters[left%n] // 处理循环
}
func TestNextGreatestLetter(t *testing.T) {
	cases := []struct {
		letters  []byte
		target   byte
		expected byte
	}{
		{[]byte{'c', 'f', 'j'}, 'c', 'f'},
		{[]byte{'c', 'f', 'j'}, 'j', 'c'},
	}

	for _, c := range cases {
		actual := nextGreatestLetter(c.letters, c.target)
		if actual != c.expected {
			t.Errorf("expected %c, but got %c", c.expected, actual)
		}
	}

	t.Log("done")
}
```



# 3. 二分查找右边界

```go
func BinarySearchRightBoundary(nums []int, target int) int {
	left, right := 0, len(nums)-1

	for left < right {
		mid := left + (right-left)/2 + 1 // 中间位置偏右
		if nums[mid] > target {
			right = mid - 1
		} else {
			left = mid
		}
	}

	if nums[right] == target {
		return right
	}

	return -1
}
```



# 4. 二分查找左右边界

leetcode [34. 在排序数组中查找元素的第一个和最后一个位置](https://leetcode-cn.com/problems/find-first-and-last-position-of-element-in-sorted-array/)

```go
func BinarySearchRange(nums []int, target int) []int {
	res := []int{-1, -1}
	n := len(nums) - 1
	if n < 0 {
		return res
	}

	// 左查找
	left, right := 0, n
	for left < right {
		mid := left + (right-left)/2
		if nums[mid] < target {
			left = mid + 1
		} else {
			right = mid
		}
	}

	if nums[left] == target {
		res[0] = left
	} else {
		return res
	}

	// 右查找
	if left == n || nums[left+1] != target {
		res[1] = left
	} else {
		right = n
		for left < right {
			mid := left + (right-left)/2 + 1
			if nums[mid] > target {
				right = mid - 1
			} else {
				left = mid
			}
		}

		res[1] = right
	}

	return res
}

func TestBinarySearchRange(t *testing.T) {
	cases := []struct {
		nums     []int
		target   int
		expected []int
	}{
		{[]int{5, 7, 7, 8, 8, 10}, 8, []int{3, 4}},
		{[]int{5, 7, 7, 8, 8, 10}, 6, []int{-1, -1}},
		{[]int{}, 0, []int{-1, -1}},
		{[]int{1}, 1, []int{0, 0}},
	}

	for _, c := range cases {
		actual := BinarySearchRange(c.nums, c.target)
		if !reflect.DeepEqual(actual, c.expected) {
			t.Errorf("expected %v, but got %v", c.expected, actual)
		}
	}

	t.Log("done")
}
```



# 5. 二分查找极值

在二分查找极值点的应用中，和相邻元素去比，以完成某种单调性的检测

```
输入：nums = [1,2,3,1]
输出：2
解释：3 是峰值元素，你的函数应该返回其索引 2。

输入：nums = [1,2,1,3,5,6,4]
输出：1 或 5 
解释：你的函数可以返回索引 1，其峰值元素为 2； 或者返回索引 5， 其峰值元素为 6。
```



```go
func findPeakElement(nums []int) int {
    left, right := 0, len(nums)-1
    
    for left < right {
        mid := left + (right-left)/2
        if nums[mid] < nums[mid+1] {
            left = mid+1
        } else {
            right = mid
        }
    }

    return left
}
```



# 6. 总结

| 查找方式     | 循环条件        | 左侧更新         | 右侧更新          | 中间点位置               | 返回值        |
| ------------ | --------------- | ---------------- | ----------------- | ------------------------ | ------------- |
| 标准二分查找 | `left <= right` | `left = mid - 1` | `right = mid + 1` | `(left + right) / 2`     | `-1 or mid`   |
| 二分找左边界 | `left < right`  | `left = mid - 1` | `right = mid`     | `(left + right) / 2`     | `-1 or left`  |
| 二分找右边界 | `left < right`  | `left = mid`     | `right = mid - 1` | `(left + right) / 2 + 1` | `-1 or right` |

