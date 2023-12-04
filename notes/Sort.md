### 2.4.6 排序算法

```go
func main() {
	arr := [...]int{5, 7, 8, 1, 2, 4, 9, 0, 3, 6}

	//bubbleSort(arr[:])
	//selectSort(arr[:])
	//insertSort(arr[:])
	quickSort(arr[:], 0, len(arr)-1)

	fmt.Println(arr)
}

func bubbleSort(a []int) {
	for i := 0; i < len(a); i++ {
		for j := 1; j < len(a)-i; j++ {
			// 相邻比较，交换位置
			if a[j] < a[j-1] {
				a[j], a[j-1] = a[j-1], a[j]
			}
		}
	}
}

func selectSort(a []int) {
	for i := 0; i < len(a); i++ {
		for j := i + 1; j < len(a); j++ {
			// 选择a[i]作为标兵，将它与i+1...的值比较，找到最小或最大，赋值给a[i]
			if a[i] > a[j] {
				a[i], a[j] = a[j], a[i]
			}
		}
	}
}

func insertSort(a []int) {
	// 假定第一个元素是有序的，后的元素与之比较，满足条件逐个插入
	for i := 1; i < len(a); i++ {
		for j := i; j > 0; j-- {
			// 前一个元素大于后一个元素，跳过比较
			if a[j] > a[j-1] {
				break
			}
			a[j], a[j-1] = a[j-1], a[j]
		}
	}
}

func quickSort(a []int, left, right int) {
	if left >= right {
		return
	}

	// 选取一个元素，作为比较项
	k := left
	val := a[k]

	for i := left + 1; i <= right; i++ {
		// 比基准值小的摆放在基准前面，比基准值大的摆在基准的后面
		if a[i] < val {
			a[k] = a[i]
			a[i] = a[k+1]
			k++
		}
	}

	a[k] = val

	quickSort(a, left, k-1)
	quickSort(a, k+1, right)
}
```

