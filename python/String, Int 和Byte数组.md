# 1. Bytes & String

## 1.1 Bytes => String

Python:

```python
byte_array = bytes([104, 101, 108, 108, 111])
s = byte_array.decode()  # 默认utf-8
```



Golang:

```go
byteArray := []byte{104, 101, 108, 108, 111}
s := string(byteArray)
```



## 1.2 String => Bytes

Python:

```python
s = 'hello'
byte_array = s.encode() # 默认utf-8
byte_array = bytes(s, encoding='utf-8')
byte_array = b'hello'
```



Golang:

```go
s := "hello"
byteArray := []byte(s)
```



## 1.3 Bytes => Hex

Python:

```python
s = '中国'

byte_array = s.encode()              # b'\xe4\xb8\xad\xe5\x9b\xbd'
hex_str = byte_array.hex()           # 'e4b8ade59bbd'

byte_array1 = binascii.b2a_hex(byte_array)   # b'e4b8ade59bbd'
byte_array = binascii.a2b_hex(byte_array1)   # b'\xe4\xb8\xad\xe5\x9b\xbd'
```



Golang:

```go
byteArray := []byte("中国")

hexStr := hex.EncodeToString(byteArray)   // e4b8ade59bbd
```



## 1.4 Hex => Bytes

Python:

```python
byte_array = bytes.fromhex(hex_str)
```



Golang:

```go
byteArray, _ = hex.DecodeString(hexStr)   // []byte{0xe4, 0xb8, 0xad, 0xe5, 0x9b, 0xbd}
```



## 1.5 字符串长度

Python: `len(v)`: Return the length (the number of items) of an object

```python
s = 'Hello, 世界'
len(s)             # 9
len(s.encode())    # 13
```



Golang: `len(v)`: Return the number of bytes in String, the number of elements in Slice

```go   
s := "Hello, 世界"

len(s)             // 13
len([]byte(s))     // 13

len([]rune(s))                // 9
utf8.RuneCountInString(s)     // 9
```



# 2. Int & String

## 2.1 Int => String

Python:

```python
n = 10
s = str(n)
s = '{}'.format(n)
```



Golang:

```go
n := 10
s := strconv.Itoa(n)
```



## 2.2 Int => String with base

Python:

```python
# 16 进制
s = hex(n)

# 2 进制
s = bin(n)
```



Golang:

```go
# 16 进制
s := strconv.FormatInt(int64(n), 16)   // a
s := fmt.Sprintf("0x%x", n)            // 0xa

# 2 进制
s := strconv.FormatInt(int64(n), 2)    // 1010
s := fmt.Sprintf("0b%b", n)            // 0b1010
```



## 2.3 String => Int

Python:

```python
n = int('10')

n = int('0xa', 16)
n = int('a', 16)

n = int('0b1010', 2)
n = int('1010', 2)
```



Golang:

```go
s = "10"
n, _ := strconv.Atoi(s)
n, _ := strconv.ParseInt(s, 10, 64)   // int64

s := "a"
n, _ := strconv.ParseInt(s, 16, 32)   // int32

s := "1010"
n, _ := strconv.ParseInt(s, 2, 8)     // int8
```



# 3. Int & Bytes

## 3.1 Int => Bytes

Python:

```python
n = 1234
my_bytes = n.to_bytes(length=4, byteorder='little', signed=False)   # b'\xd2\x04\x00\x00'
my_bytes = struct.pack('<I', n)                                     # b'\xd2\x04\x00\x00'
```

pack 参数：

| 参数 | 含义   |
| ---- | ------ |
| >    | 大端   |
| <    | 小端   |
| B    | uint8  |
| b    | int8   |
| H    | uint16 |
| h    | int16  |
| I    | uint32 |
| i    | int32  |
| L    | uint64 |
| l    | int64  |
| s    | ascii  |



Golang:

```go
n := 1234

bytesBuffer := bytes.NewBuffer([]byte{})
binary.Write(bytesBuffer, binary.LittleEndian, int32(n))    // int32 => length=4
byte_array := bytesBuffer.Bytes()    // d2040000
```



## 3.2 Bytes => Int

Python:

```python
byte_array = b'\xd2\x04\x00\x00'

n = int.from_bytes(byte_array, byteorder='little', signed=False)
n = struct.unpack('<I', byte_array)[0]
```



Golang:

```go
byteArray := []byte{0xd2, 0x04, 0x00, 0x00}

var n int32
bytesBuffer := bytes.NewBuffer(byteArray)
binary.Read(bytesBuffer, binary.LittleEndian, &n)
```



# 4. Zero bytes in Array

Python:

```python
byte_array = b'\xe4\xb8\xad\xe5\x9b\xbd\x00\x00\x00\x00'
s = byte_array.decode()       # '中国\x00\x00\x00\x00'

n = byte_array.find(b'\x00')
s = byte_array[:n].decode()   # '中国'
```



Golang:

```go
byteArray := []byte{0xe4, 0xb8, 0xad, 0xe5, 0x9b, 0xbd, 0x00, 0x00, 0x00, 0x00}

n := bytes.IndexByte(byteArray[:], 0)
s := string(byteArray[:n])   // 中国
```

