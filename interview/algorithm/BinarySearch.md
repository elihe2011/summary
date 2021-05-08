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

特点：

- 数组有序，但包含重复元素

- 数组部分有序，且不包含重复元素

- 数组部分有序，且包含重复元素

