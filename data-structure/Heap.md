# 1. 二叉堆

Binary Heap 的两个方法：下沉(sink)和上浮(swim)

应用：

- 堆排序
- 优先级队列

二叉堆本质是完全二叉树，但存储在数组中。

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/heap/binary-heap.png)

二叉堆分类：

- 最大堆：每个节点都大于等于它的子节点
- 最小堆：每个节点都小于等于它的子节点

## 1.1 优先级队列

优先级队列：插入或删除元素的时候，元素会自动排序，它底层的原理就是二叉堆的操作

```go
type PriorityQueue []int

func (q PriorityQueue) len() int            { return len(q) }
func (q PriorityQueue) less(i, j int) bool  { return q[i] < q[j] }
func (q PriorityQueue) swap(i, j int)       { q[i], q[j] = q[j], q[i] }
func (q PriorityQueue) parent(root int) int { return root / 2 }
func (q PriorityQueue) left(root int) int   { return root * 2 }
func (q PriorityQueue) right(root int) int  { return root*2 + 1 }

func NewPriorityQueue() *PriorityQueue {
	// 默认第 0 个元素不使用
	return &PriorityQueue{-1}
}

func (q *PriorityQueue) swim(k int) {
	for k > 1 && q.less(q.parent(k), k) {
		q.swap(q.parent(k), k)
		k = q.parent(k)
	}
}

func (q *PriorityQueue) sink(k int) {
	for q.left(k) < q.len() {
		// 先假设左节点较大
		older := q.left(k)

		// 如果右节点存在，比较大小
		if q.right(k) < q.len() && q.less(older, q.right(k)) {
			older = q.right(k)
		}

		// 节点 k 比左右节点都大，不必下沉
		if q.less(older, k) {
			break
		}

		// 否则，下沉 k 节点
		q.swap(k, older)

		k = older
	}
}

func (q PriorityQueue) Max() int {
	// 索引 0 不使用
	return q[1]
}

func (q *PriorityQueue) Insert(e int) {
	// 先将新元素追加到最后
	*q = append(*q, e)

	// 然后让其上浮到正确位置
	q.swim(q.len() - 1)
}

func (q *PriorityQueue) DelMax() int {
	max := (*q)[1]

	// 将最大元素换到最后，并删除
	q.swap(1, q.len()-1)
	*q = (*q)[:q.len()-1]

	// 堆顶元素下沉到正确位置
	q.sink(1)

	return max
}

func main() {
	a := []int{6, 3, 5, 2, 7, 1, 8, 4}

	q := NewPriorityQueue()
	for i := 0; i < len(a); i++ {
		q.Insert(a[i])
	}

	for q.len() > 1 {
		fmt.Printf("%d ", q.DelMax())
	}
}
```

使用`container/heap`包实现优先队列:

```go
type PriorityQueue []int

func (q PriorityQueue) Len() int           { return len(q) }
func (q PriorityQueue) Less(i, j int) bool { return q[i] > q[j] }
func (q PriorityQueue) Swap(i, j int)      { q[i], q[j] = q[j], q[i] }

func (q *PriorityQueue) Push(x interface{}) {
	*q = append(*q, x.(int))
}

func (q *PriorityQueue) Pop() interface{} {
	n := q.Len()
	x := (*q)[n-1]
	*q = (*q)[:n-1]
	return x
}

func main() {
	a := []int{6, 3, 5, 2, 7, 1, 8, 4}

	q := &PriorityQueue{}
	heap.Init(q)
	for i := 0; i < len(a); i++ {
		heap.Push(q, a[i])
	}

	for q.Len() > 0 {
		fmt.Printf("%d ", heap.Pop(q))
	}

	fmt.Println()
}
```







# 1. [设计推特](https://leetcode-cn.com/problems/design-twitter/)

设计一个简化版的推特(Twitter)，可以让用户实现发送推文，关注/取消关注其他用户，能够看见关注人（包括自己）的最近十条推文。你的设计需要支持以下的几个功能：

postTweet(userId, tweetId): 创建一条新的推文
getNewsFeed(userId): 检索最近的十条推文。每个推文都必须是由此用户关注的人或者是用户自己发出的。推文必须按照时间顺序由最近的开始排序。
follow(followerId, followeeId): 关注一个用户
unfollow(followerId, followeeId): 取消关注一个用户
示例:

```java
Twitter twitter = new Twitter();

// 用户1发送了一条新推文 (用户id = 1, 推文id = 5).
twitter.postTweet(1, 5);

// 用户1的获取推文应当返回一个列表，其中包含一个id为5的推文.
twitter.getNewsFeed(1);

// 用户1关注了用户2.
twitter.follow(1, 2);

// 用户2发送了一个新推文 (推文id = 6).
twitter.postTweet(2, 6);

// 用户1的获取推文应当返回一个列表，其中包含两个推文，id分别为 -> [6, 5].
// 推文id6应当在推文id5之前，因为它是在5之后发送的.
twitter.getNewsFeed(1);

// 用户1取消关注了用户2.
twitter.unfollow(1, 2);

// 用户1的获取推文应当返回一个列表，其中包含一个id为5的推文.
// 因为用户1已经不再关注用户2.
twitter.getNewsFeed(1);
```



```go
type Tweet struct {
	id   int
	time int
	next *Tweet
}

func NewTweet(id, time int) *Tweet {
	return &Tweet{id: id, time: time}
}

type User struct {
	id       int
	followed map[int]struct{}
	head     *Tweet // 用户的推文链表头结点
}

func NewUser(id int) *User {
	user := &User{
		id:       id,
		followed: make(map[int]struct{}),
	}

	// follow 自己
	user.follow(user.id)
	return user
}

func (user *User) follow(userId int) {
	user.followed[userId] = struct{}{}
}

func (user *User) unfollow(userId int) {
	if userId != user.id {
		if _, ok := user.followed[userId]; ok {
			delete(user.followed, userId)
		}
	}
}

func (user *User) post(tweetId, timestamp int) {
	tweet := NewTweet(tweetId, timestamp)

	// 时间最近的放链表最前面
	tweet.next = user.head
	user.head = tweet
}

type Twitter struct {
	timestamp int
	userMap   map[int]*User
}

/** Initialize your data structure here. */
func Constructor() Twitter {
	return Twitter{
		timestamp: 0,
		userMap:   make(map[int]*User),
	}
}

func (this *Twitter) CreateUser(userId int) *User {
	user := NewUser(userId)
	this.userMap[userId] = user
	return user
}

/** Compose a new tweet. */
func (this *Twitter) PostTweet(userId int, tweetId int) {
	user, ok := this.userMap[userId]
	if !ok {
		user = this.CreateUser(userId)
	}

	user.post(tweetId, this.timestamp)
	this.timestamp++
}

/** Retrieve the 10 most recent tweet ids in the user's news feed.
Each item in the news feed must be posted by users who the user followed or by the user herself.
Tweets must be ordered from most recent to least recent. */
func (this *Twitter) GetNewsFeed(userId int) []int {
	user, ok := this.userMap[userId]
	if !ok {
		return []int{}
	}

	q := &PriorityQueue{}

	for uid, _ := range user.followed {
		tweet := this.userMap[uid].head
		for tweet != nil {
			heap.Push(q, tweet)
			tweet = tweet.next
		}
	}

	var res []int
	for q.Len() > 0 {
		if len(res) == 10 {
			break
		}

		tweet := heap.Pop(q).(*Tweet)
		res = append(res, tweet.id)
	}

	return res
}

/** Follower follows a followee. If the operation is invalid, it should be a no-op. */
func (this *Twitter) Follow(followerId int, followeeId int) {
	follower, ok := this.userMap[followerId]
	if !ok {
		follower = this.CreateUser(followerId)
	}

	followee, ok := this.userMap[followeeId]
	if !ok {
		followee = this.CreateUser(followeeId)
	}

	follower.follow(followee.id)
}

/** Follower unfollows a followee. If the operation is invalid, it should be a no-op. */
func (this *Twitter) Unfollow(followerId int, followeeId int) {
	follower, ok := this.userMap[followerId]
	if !ok {
		follower = this.CreateUser(followerId)
	}

	followee, ok := this.userMap[followeeId]
	if !ok {
		followee = this.CreateUser(followeeId)
	}

	follower.unfollow(followee.id)
}

// 优选队列
type PriorityQueue []*Tweet

func (q PriorityQueue) Len() int           { return len(q) }
func (q PriorityQueue) Less(i, j int) bool { return q[i].time > q[j].time }
func (q PriorityQueue) Swap(i, j int)      { q[i], q[j] = q[j], q[i] }
func (q *PriorityQueue) Push(x interface{}) {
	*q = append(*q, x.(*Tweet))
}
func (q *PriorityQueue) Pop() interface{} {
	n := len(*q)
	x := (*q)[n-1]
	*q = (*q)[:n-1]
	return x
}

func main() {
	obj := Constructor()
	obj.PostTweet(1, 5)
	fmt.Println(obj.GetNewsFeed(1)) // 5

	obj.Follow(1, 2)

	obj.PostTweet(2, 6)
	fmt.Println(obj.GetNewsFeed(1)) // 6, 5

	obj.Unfollow(1, 2)

	fmt.Println(obj.GetNewsFeed(1)) // 5
}
```

