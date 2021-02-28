

# 1. 数据交换格式

- json
- xml
- msgpack：二进制 json
- Protobuf：二进制，基于代码自动生成

## 1.1 Protobuf 开发流程：

- IDL编写
- 生成指定语言的代码
- 序列化和反序列化

```protobuf
enum EnumAllowingAlias {
	UNKNOWN = 0;
	STARTED = 1;
	RUNNING = 2;
}

// 结构体
message Person {
	int32 id = 1;
	string name = 2;
	repeated Phone phones = 3; // 数组
}
```

安装工具：

```txt
# 安装工具
https://github.com/protocolbuffers/protobuf/releases

# 安装插件
go get -u github.com/golang/protobuf/protoc-gen-go
```



编写IDL:

```protobuf
syntax = "proto3";

package address;

enum PhoneType {
  HOME = 0;
  WORK = 1;
}

message Phone {
  PhoneType type = 1;
  string number = 2;
}

message Person {
  int32 id = 1;
  string name = 2;
  repeated Phone phones = 3;
}

message ContactBook {
  repeated Person persons = 1;
}
```

生成go代码：

```bash
protoc --go_out=./address ./person.proto
```

使用pb.go文件结构：

```go
func main() {
	var contactBook address.ContactBook

	for i := 0; i < 100; i++ {
		person := &address.Person{
			Id:   int32(i),
			Name: fmt.Sprintf("Jack %d", i),
		}

		phone := &address.Phone{
			Type:   address.PhoneType_HOME,
			Number: fmt.Sprintf("%d", rand.Int()),
		}

		person.Phones = append(person.Phones, phone)

		contactBook.Persons = append(contactBook.Persons, person)
	}

	data, err := proto.Marshal(&contactBook)
	if err != nil {
		fmt.Printf("protoc.Marshal error: %v\n", err)
		return
	}

	err = ioutil.WriteFile("test.dat", data, 0644)
	if err != nil {
		fmt.Printf("ioutil.WriteFile error: %v\n", err)
		return
	}

	fmt.Println("Done")
}
```

