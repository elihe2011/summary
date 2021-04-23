# 1. 图的存储

- 邻接矩阵法:  

  一维数组：顶点信息

  二维数组：边信息，即顶点连接信息

  ```go
  type Graph struct {
      Vex []byte
      Edge [][]int
      vexnum, arcnum int
  }
  ```

  路径数量：`A^n[i][j]` 顶点 i 到顶点 j 的边数总和

  缺点：空间复杂度高 O(n^2)，适合存储稠密图

- 邻接表法：顺序 + 链式存储

  ```go
  type Graph struct {
     vertices []*VNode
     vexnum, arcnum int
  }
  
  type VNode struct {
      data int // 顶点信息
      first *ArcNode  // 第一条边
  }
  
  type ArcNode struct {
      adjvex int  // 边指向的节点
      next *ArcNode
  }
  
  ```

  缺点：表式方式不唯一，找边不容易。适合稀疏图

- 十字链表法：存储有向图

- 邻接多重表：存储无向图

# 2. 图的遍历

## 2.1 BFS 广度优先遍历

遍历要点：

- 找到与一个顶点相邻的所有顶点
- 标记哪些顶点被访问过
- 需要一个辅助队列

- 广度优先搜索BFS( breadth-first search) 

广度优先遍历可定义如下：首先访问出发点v，接着依次访问v的所有邻接点w1、w2......wt，然后依次访问w1、w2......wt邻接的所有未曾访问过的顶点。以此类推，直至图中所有和源点v有路径相通的顶点都已访问到为止。此时从v开始的搜索过程结束。

结论：广度优先遍历借助了队列来保证按层次搜索，上级层次的结点先入队，结点出队时它的相邻子结点再依次入队

![bfs](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/bfs.png)



## 2.2 DFS 深度优先遍历

遍历要求：类似树的先序遍历

深度优先搜索 DFS(depth-first search)

深度优先遍历可定义如下：首先访问出发点v，并将其标记为已访问过；然后依次从v出发搜索v的每个邻接点w。若w未曾访问过，则以w为新的出发点继续进行深度优先遍历，直至图中所有和源点v有路径相通的顶点均已被访问为止。若此时图中仍有未访问的顶点，则另选一个尚未访问的顶点为新的源点重复上述过程，直至图中所有的顶点均已被访问为止。

结论：深度优先遍历尽可能优先往深层次进行搜索

![dfs](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/dfs.png)



## 2.3 最小生成树 

最小代价树：Minimum Spanning Tree, MST

- Prim算法（普里姆）: 从某一个顶点开始构建生成树；每次将代价最小的新顶点纳入生成树中，直到所有顶点都纳入为止
- Kruskal算法（克努斯卡尔）：每次选择一条权值最小的边，使这条边的两头连通（原本已经连通的就不选），直到所有节点都连通

## 2.4 最短路径

  Dijkstra 













# 1. Union-Find 算法

并查集算法，主要用于解决图论中「动态连通性」问题.

算法关键的3点：

1. parent数组：记录每个节点的父节点，相当于指向父节点的指针，所以parent数组实际存储一个森林（若干棵多叉树）
2. size数组：记录没棵树的重量，其目的是让union后依然保持树的平衡性，不会退化成链表，影响操作性能
3. find()函数：进行路径压缩，保证任意树的高度保持在常数(不超过 3)，使得union()和connected()函数的时间复杂度保持在O(1)



```go
type UnionFind struct {
	count  int   // 连同分量，即存在多少个连同
	parent []int // 节点 x 的父节点是 parent[x]
	size   []int // 记录树的重量
}

func NewUnionFind(n int) *UnionFind {
	u := &UnionFind{}

	// 一开始都不连通
	u.count = n

	// 每个节点的父节点指针指向自己
	u.parent = make([]int, n)
	u.size = make([]int, n)
	for i := 0; i < n; i++ {
		u.parent[i] = i
		u.size[i] = 1
	}

	return u
}

// 找到节点 x 的根节点
func (u *UnionFind) find(x int) int {
	// 根节点 parent[x] == x
	for u.parent[x] != x {
		// 路径压缩
		u.parent[x] = u.parent[u.parent[x]]
		x = u.parent[x]
	}
	return x
}

func (u *UnionFind) union(p, q int) {
	// 分别找到这个两个节点的根节点
	rootP := u.find(p)
	rootQ := u.find(q)

	// 根节点相同，说明它们已经连通了
	if rootP == rootQ {
		return
	}

	// 小树放大树下，以求平衡
	if u.size[rootP] > u.size[rootQ] {
		u.parent[rootQ] = rootP
		u.size[rootP] += u.size[rootQ]
	} else {
		u.parent[rootP] = rootQ
		u.size[rootQ] += u.size[rootP]
	}

	// 连通量减少一个
	u.count--
}

// 检测两个元素的连通性
func (u *UnionFind) connected(p, q int) bool {
	// 分别找到它们的根节点
	rootP := u.find(p)
	rootQ := u.find(q)

	// 根节点相同，说明它们连通
	return rootP == rootQ
}
```

## 1.1 [被围绕的区域](https://leetcode-cn.com/problems/surrounded-regions/)

给定一个二维的矩阵，包含 'X' 和 'O'（字母 O）。

找到所有被 'X' 围绕的区域，并将这些区域里所有的 'O' 用 'X' 填充。

示例:

```txt
X X X X
X O O X
X X O X
X O X X
```

运行你的函数后，矩阵变为：

```txt
X X X X
X X X X
X X X X
X O X X
```

```go
func solve(board [][]byte) {
	if len(board) == 0 {
		return
	}

	m := len(board)
	n := len(board[0])

	u := NewUnionFind(m*n + 1)
	dummy := m * n

	// 首列和末列的 “O” 与 dummy 相连
	for i := 0; i < m; i++ {
		if board[i][0] == 'O' {
			u.union(i*n, dummy)
		}
		if board[i][n-1] == 'O' {
			u.union(i*n+n-1, dummy)
		}
	}

	// 首行和末行的 “O” 与 dummy 相连
	for j := 0; j < n; j++ {
		if board[0][j] == 'O' {
			u.union(j, dummy)
		}
		if board[m-1][j] == 'O' {
			u.union((m-1)*n+j, dummy)
		}
	}

	// 上下搜索方向组
	d := [][]int{{1, 0}, {-1, 0}, {0, -1}, {0, 1}}
	for i := 1; i < m-1; i++ {
		for j := 1; j < n-1; j++ {
			if board[i][j] == 'O' {
				for k := 0; k < 4; k++ {
					x := i + d[k][0]
					y := j + d[k][1]
					if board[x][y] == 'O' {
						u.union(x*n+y, i*n+j)
					}
				}
			}
		}
	}

	// 所有与dummy不相连的“O” 换成 X
	for i := 1; i < m-1; i++ {
		for j := 1; j < n-1; j++ {
			if board[i][j] == 'O' {
				if !u.connected(dummy, i*n+j) {
					board[i][j] = 'X'
				}
			}
		}
	}
}
```

## 1.2 [等式方程的可满足性](https://leetcode-cn.com/problems/satisfiability-of-equality-equations/)

```txt
输入：["a==b","b!=a"]
输出：false
解释：如果我们指定，a = 1 且 b = 1，那么可以满足第一个方程，但无法满足第二个方程。没有办法分配变量同时满足这两个方程。
```

```go
func equationsPossible(equations []string) bool {
    if len(equations) == 0 {
        return true
    }

    u := NewUnionFind(26)

    for _, e := range equations {
        x, y, op := e[0], e[3], e[1]
        if op == '!' {
            continue
        }

        u.union(int(x - 'a'), int(y - 'a'))
    }

    for _, e := range equations {
        x, y, op := e[0], e[3], e[1]
        if op != '!' {
            continue
        }

        if u.connected(int(x - 'a'), int(y - 'a')) {
            return false
        }
    }

    return true
}
```





