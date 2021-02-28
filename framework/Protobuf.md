@[TOC](Golang Protobuf总结)

# 1. Protobuf

Protocol Buffers 的简称，Google公司开发的一种数据描述语言，它通过附带工具生成代码并实现将结构化数据序列化的功能

Protobuf 是一种与语言、平台无关，可扩展的序列化结构化数据的方法，常用于通信协议、数据存储等。相较于JSON、XML，它更小、更快、更简单。

# 2. 安装Protobuf工具

Protocol Buffers v3:

```sh
brew search protobuf
brew install protobuf@3.6
```

Protoc Plugin:

```sh
# 会自动编译安装protoc-gen-go可执行插件文件
go get -u github.com/golang/protobuf/protoc-gen-go
```

# 3. Protobuf 基本语法

```proto
// hello.proto
syntax = "proto3";

option go_package = ".;main"; // 重要

package main;

message String {
    string value = 1;
}
```

# 4. 生成代码

```bash
$ protoc --go_out=. hello.proto 
```


生成一个`hello.pb.go`文件

```go
type String struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Value string `protobuf:"bytes,1,opt,name=value,proto3" json:"value,omitempty"`
}

func (x *String) Reset() {
	*x = String{}
	if protoimpl.UnsafeEnabled {
		mi := &file_hello_proto_msgTypes[0]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *String) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*String) ProtoMessage() {}

func (x *String) ProtoReflect() protoreflect.Message {
	mi := &file_hello_proto_msgTypes[0]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use String.ProtoReflect.Descriptor instead.
func (*String) Descriptor() ([]byte, []int) {
	return file_hello_proto_rawDescGZIP(), []int{0}
}

func (x *String) GetValue() string {
	if x != nil {
		return x.Value
	}
	return ""
}
```



```proto
syntax = "proto3";

service SearchService {
	rpc Search (SearchRequest) returns (SearchResponse);
}

message SearchRequest {
	string query = 1;
	int32 page_number = 2;
	int32 result_per_page = 3;
}

message SearchResponse {
	...
}
```