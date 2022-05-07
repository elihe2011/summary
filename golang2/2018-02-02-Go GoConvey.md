---
layout: post
title:  Go GoConvey
date:   2018-02-02 20:17:09
comments: true
photos: 
tags: 
  - go
categories: Golang
---


# 1. GoConvey简介

- GoConvey是一款针对Go语言的测试辅助开发包，在兼容Go原生测试的基础上，又拓展出便利的语法和大量的内置判断条件，减轻开发人员负担。
- 提供实时监控代码编译测试的程序，配以舒服的Web解码，能够让一个开发人员从此不再排斥写单元测试

# 2. 安装

```shell
go get github.com/smartystreets/goconvey
```

<!--more-->

# 3. 编写测试

```go
import (
	"testing"

	. "github.com/smartystreets/goconvey/convey"
)

func TestAdd(t *testing.T) {
	Convey("将两数相加", t, func() {
		So(Add(1, 2), ShouldEqual, 3)
	})
}

func TestSubtract(t *testing.T) {
	Convey("将两数相减", t, func() {
		So(Subtract(1, 2), ShouldEqual, -1)
	})
}

func TestMultiply(t *testing.T) {
	Convey("将两数相乘", t, func() {
		So(Multiply(3, 2), ShouldEqual, 6)
	})
}

func TestDivision(t *testing.T) {
	Convey("将两数相除", t, func() {

		Convey("除数为0", func() {
			_, err := Division(10, 0)
			So(err, ShouldNotBeNil)
		})

		Convey("除数不为0", func() {
			num, err := Division(10, 2)
			So(err, ShouldBeNil)
			So(num, ShouldEqual, 5)
		})
	})
}
```

# 4. 运行测试

- 使用Go原生方法：`go test -v`
- 使用GoConvey自动化编译测试 `goconvey`，访问http://localhost:8080查看
