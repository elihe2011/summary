# 1. Trie 树

Trie 树，也叫「前缀树」或「字典树」。它是一个树形结构，专门用于处理字符串匹配，用来解决在一组字符串集合中快速查找某个字符串的问题。

> 注：Trie 来自于单词「retrieval」，你可以把它读作 tree，也可以读作 try。

Trie 树的本质，就是利用字符串之间的公共前缀，将重复的前缀合并在一起，比如我们有`["hello","her","hi","how","see","so"]` 这个字符串集合，可以将其构建成下面这棵 Trie 树：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/string-match-trie.png) 



每个节点表示一个字符串中的字符，从根节点到红色节点的一条路径表示一个字符串（红色节点表示是某个单词的结束字符，但不一定都是叶子节点）。

这样，我们就可以通过遍历这棵树来检索是否存在待匹配的字符串了，比如我们要在这棵 Trie 树中查询 `her`，只需从 `h` 开始，依次往下匹配，在子节点中找到 `e`，然后继续匹配子节点，在`e` 的子节点中找到 `r`，则表示匹配成功，否则匹配失败。通常，我们可以通过 Trie 树来构建敏感词或关键词匹配系统。



# 2. 实现 Trie 树

```go
type TrieNode struct {
	char     rune
	isEnding bool
	children map[rune]*TrieNode
}

func NewTrieNode(char rune) *TrieNode {
	return &TrieNode{
		char:     char,
		isEnding: false,
		children: make(map[rune]*TrieNode),
	}
}

type Trie struct {
	root *TrieNode
}

func NewTrie() *Trie {
	trieNode := NewTrieNode('/')
	return &Trie{trieNode}
}

func (t *Trie) Insert(word string) {
	node := t.root
	for _, char := range word {
		value, ok := node.children[char]
		if !ok {
			value = NewTrieNode(char)
			node.children[char] = value
		}
		node = value
	}
	node.isEnding = true
}

func (t *Trie) Find(word string) bool {
	node := t.root
	for _, char := range word {
		value, ok := node.children[char]
		if !ok {
			return false
		}
		node = value
	}

	// 是否完全匹配
	return node.isEnding
}
```



# 3. Trie 树的复杂度

构建 Trie 树的过程比较耗时，对于有 `n` 个字符的字符串集合而言，需要遍历所有字符，对应的时间复杂度是 `O(n)`，但是一旦构建之后，查询效率很高，如果匹配串的长度是 `k`，那只需要匹配 `k` 次即可，与原来的主串没有关系，所以对应的时间复杂度是 `O(k)`，基本上是个常量级的数字。

Trie 树显然也是一种空间换时间的做法，构建 Trie 树的过程需要额外的存储空间存储 Trie 树，而且这个额外的空间是原来的数倍。



# 4. Trie 树的应用

Trie 树适用于那些查找前缀匹配的字符串，比如敏感词过滤和搜索框联想功能。

## 4.1 敏感词过滤系统

敏感词过滤系统，就用到了 Trie 树来对敏感词进行搜索匹配：首先运营在后台手动更新敏感词，底层通过 Tire 树构建敏感词库，然后当商家发布商品时，以商品标题+详情作为主串，将敏感词库作为模式串，进行匹配，如果模式串和主串有匹配字符，则以此为起点，继续往后匹配，直到匹配出完整字符串，然后标记为匹配出该敏感词（如果想嗅探所有敏感词，继续往后匹配），否则将主串匹配起点位置往后移，从下一个字符开始，继续与模式串匹配。

## 4.2 搜索框联想功能

搜索框的查询关键词联想功能也是基于 Trie 树实现的, 进而可以扩展到浏览器网址输入自动补全、IDE 代码编辑器自动补全、输入法自动补全功能等。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/string-match-trie-google.png)Google搜索框联想词



# 5. Lettcode [208. 实现 Trie (前缀树)](https://leetcode-cn.com/problems/implement-trie-prefix-tree/)

```go
type Trie struct {
	char     rune
	isEnding bool
	children map[rune]*Trie
}

func Constructor() Trie {
	return Trie{
		char:     '/',
		isEnding: false,
		children: make(map[rune]*Trie),
	}
}

func (this *Trie) Insert(word string) {
	node := this
	for _, char := range word {
		value, ok := node.children[char]
		if !ok {
			value = &Trie{
				char:     char,
				isEnding: false,
				children: make(map[rune]*Trie),
			}
			node.children[char] = value
		}
		node = value
	}
	node.isEnding = true
}

func (this *Trie) Search(word string) bool {
	node := this
	for _, char := range word {
		value, ok := node.children[char]
		if !ok {
			return false
		}
		node = value
	}
	return node.isEnding
}

func (this *Trie) StartsWith(prefix string) bool {
	node := this
	for _, char := range prefix {
		value, ok := node.children[char]
		if !ok {
			return false
		}
		node = value
	}

	// 完全匹配 或 部分匹配
	return node.isEnding || (!node.isEnding && len(node.children) != 0)
}

func Test2(t *testing.T) {
	obj := Constructor()

	ops := []string{"insert", "startsWith", "search", "insert", "startsWith", "search", "insert", "startsWith", "search", "insert", "startsWith", "search", "insert", "startsWith", "search", "insert", "startsWith", "search"}
	words := []string{"p", "pr", "p", "pr", "pre", "pr", "pre", "pre", "pre", "pref", "pref", "pref", "prefi", "pref", "prefi", "prefix", "prefi", "prefix"}
	wants := []interface{}{nil, false, true, nil, false, true, nil, true, true, nil, true, true, nil, true, true, nil, true, true}
	var results []interface{}

	for i := 0; i < len(ops); i++ {
		op := ops[i]
		word := words[i]
		want := wants[i]

		switch op {
		case "insert":
			obj.Insert(word)
			results = append(results, nil)
		case "search":
			actual := obj.Search(word)
			results = append(results, actual)
			if actual != want.(bool) {
				t.Errorf("[%d] Search %s: expected %v, but got %v", i, word, want, actual)
			}
		case "startsWith":
			actual := obj.StartsWith(word)
			results = append(results, actual)
			if actual != want.(bool) {
				t.Errorf("[%d] StartsWith %s: expected %v, but got %v", i, word, want, actual)
			}
		}
	}

	if !reflect.DeepEqual(wants, results) {
		t.Errorf("expected %v, but got %v", wants, results)
	}

	t.Log("done")
}
```

