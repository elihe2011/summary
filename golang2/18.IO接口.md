# 1.  io - 基本的 IO 接口

## 1.1 Reader & Writer  接口

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/io-interface.png)

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}
```

实现Reader和Writer接口的类型：

```go
// os
var (
    Stdin  = NewFile(uintptr(syscall.Stdin), "/dev/stdin")
    Stdout = NewFile(uintptr(syscall.Stdout), "/dev/stdout")
    Stderr = NewFile(uintptr(syscall.Stderr), "/dev/stderr")
)
```

| 类型                       | io.Reader | io.Writer |
| -------------------------- | --------- | --------- |
| **os.File**                | Yes       | Yes       |
| **strings.Reader**         | Yes       | -         |
| **bufio.Reader**           | Yes       | -         |
| **bufio.Writer**           | -         | Yes       |
| **bytes.Buffer**           | Yes       | Yes       |
| bytes.Reader               | Yes       | -         |
| compress/gzip.Reader       | Yes       | -         |
| compress/gzip.Writer       | -         | Yes       |
| crypto/cipher.StreamReader | Yes       | -         |
| crypto/cipher.StreamWriter | -         | Yes       |
| crypto/tls.Conn            | Yes       | Yes       |
| encoding/csv.Reader        | Yes       | -         |
| encoding/csv.Writer        | -         | Yes       |
| mime/multipart.Part        | Yes       | -         |
| **net/conn**               | Yes       | Yes       |
| io.LimitedReader           | Yes       | -         |
| io.PipeReader              | Yes       | -         |
| io.SectionReader           | Yes       | -         |
| net/conn io.PipeWriter     | -         | Yes       |



## 1.2 Seeker 接口

用于设置偏移量的，这样可以从某个特定位置开始操作数据流

```go
type Seeker interface {
    Seek(offset int64, whence int) (ret int64, err error)
}

// whence
const (
  SeekStart   = 0 // seek relative to the origin of the file
  SeekCurrent = 1 // seek relative to the current offset
  SeekEnd     = 2 // seek relative to the end
)
```



## 1.3 Closer 接口

用于关闭数据流

```go
type Closer interface {
    Close() error
}
```



## 1.4 ByteReader & ByteWriter 接口

```go
type ByteReader interface {
    ReadByte() (c byte, err error)
}

type ByteWriter interface {
    WriteByte(c byte) error
}

ByteScanner、RuneReader 和 RuneScanner
```

| 类型               | io.ByteReader | io.ByteWriter |
| ------------------ | ------------- | ------------- |
| **strings.Reader** | Yes           | -             |
| **bufio.Reader**   | Yes           | -             |
| **bufio.Writer**   | -             | Yes           |
| **bytes.Buffer**   | Yes           | Yes           |
| bytes.Reader       | Yes           | -             |



## 1.5 PipeReader & PipeWriter 类型

```go
type PipeReader struct {
    p *pipe
}

type PipeWriter struct {
    p *pipe
}

func Pipe() (*PipeReader, *PipeWriter)
```

示例：

```go
var wg sync.WaitGroup

func main() {
	wg.Add(2)

	pipeReader, pipeWriter := io.Pipe()

	go write(pipeWriter)
	go read(pipeReader)

	wg.Wait()
}

func write(w *io.PipeWriter) {
	data := []byte("just a test")

	for i := 0; i < 3; i++ {
		n, err := w.Write(data)
		if err != nil {
			fmt.Println(err)
			break
		}
		fmt.Printf("write bytes: %d\n", n)
	}

	wg.Done()
	//w.CloseWithError(errors.New("writer closed"))
	w.Close() // EOF
}

func read(r *io.PipeReader) {
	buf := make([]byte, 128)
	for {
		fmt.Println("waiting for reading")
		time.Sleep(3 * time.Second)
		n, err := r.Read(buf)
		if err != nil {
			fmt.Println(n, err)
			break
		}
		fmt.Printf("read bytes: %d\n", n)
	}

	wg.Done()
	r.Close()
}
```



## 1.6 Copy & CopyN 函数

```go
// 将 src 复制到 dst，直到在 src 上到达 EOF 或发生错误
func Copy(dst Writer, src Reader) (written int64, err error)
func CopyN(dst Writer, src Reader, n int64) (written int64, err error)
```

示例：

```go
// 
io.Copy(os.Stdout, os.Stdin)

io.Copy(os.Stdout, strings.NewReader("Go语言中文网"))
io.CopyN(os.Stdout, strings.NewReader("Go语言中文网"), 8)
```



## 1.7 WriteString 函数

将s的内容写入w中，当 w 实现了 WriteString 方法时，会直接调用该方法，否则执行 w.Write([]byte(s))

```go
func WriteString(w Writer, s string) (n int, err error)
```



## 1.8 MultiReader & MultiWriter 函数

合并IO操作

```go
func MultiReader(readers ...Reader) Reader
func MultiWriter(writers ...Writer) Writer
```

合并reader:

```go
func main() {
	readers := []io.Reader{
		strings.NewReader("from strings reader."),
		bytes.NewBufferString("from bytes buffer string."),
	}

	reader := io.MultiReader(readers...)

	data := make([]byte, 0, 128)
	buf := make([]byte, 10)
	for {
		n, err := reader.Read(buf)
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}

		data = append(data, buf[:n]...)
	}

	fmt.Printf("%s\n", data)
}
```

合并writer，即多渠道输出:

```go
func main() {
	f, _ := os.Create("tmp.txt")
	defer f.Close()

	writers := []io.Writer{
		f,
		os.Stdout,
	}

	writer := io.MultiWriter(writers...)
	n, err := writer.Write([]byte("Go语言中文网\n"))
	fmt.Println(n, err)
}
```



## 1.9 TeeReader函数

将从 r 中读到的数据写入 w 中。所有经由它处理的从 r 的读取都匹配于对应的对 w 的写入。它没有内部缓存，即写入必须在读取完成前完成

```go
func TeeReader(r Reader, w Writer) Reader
```

示例：

```go
func main() {
	f1, _ := os.Open("tmp.txt")
	f2, _ := os.Create("backup.txt")

	reader := io.TeeReader(f1, f2)

	data := make([]byte, 0, 128)
	buf := make([]byte, 10)
	for {
		n, err := reader.Read(buf)
		if err == io.EOF {
			break
		}

		if err != nil {
			panic(err)
		}

		data = append(data, buf[:n]...)
	}

	fmt.Fprintf(os.Stdout, "%s\n", data)
}
```



# 2. ioutil - IO 操作函数集

## 2.1 NopCloser 

对应的Close方法不做任何处理，直接返回nil。1.16+ 后，已在 io 包中实现了

```go
// a no-op Close method wrapping
func NopCloser(r io.Reader) io.ReadCloser

// net/http.func NewRequest(method, url string, body io.Reader) (*Request, error)
	rc, ok := body.(io.ReadCloser)
	if !ok && body != nil {
		rc = io.NopCloser(body)
	}
```



## 2.2 ReadAll

1.16+ 后，已在 io 包中实现了

```go
// reads from r until an error or EOF and returns the data it read
func ReadAll(r io.Reader) ([]byte, error)
```



## 2.3 ReadDir

1.16+ 后，已在 io 包中实现了

```go
// returns a list of fs.FileInfo for the directory's contents, sorted by filename
func ReadDir(dirname string) ([]fs.FileInfo, error)
```

示例：读取文件目录

```go
func main() {
	listDir(`E:\HHZ\gitee\golearn\algorithm`, 0)
}

func listDir(path string, level int) {
	fileInfos, err := ioutil.ReadDir(path)
	if err != nil {
		fmt.Println(err)
		return
	}

	for _, info := range fileInfos {
		for i := level; i > 0; i-- {
			fmt.Printf("|\t")
		}

		if info.IsDir() {
			fmt.Printf("%s/\n", info.Name())
			subPath := filepath.Join(path, info.Name())
			listDir(subPath, level+1)
		} else {
			fmt.Println(info.Name())
		}
	}
}
```



## 2.4 ReadFile & WriteFile

1.16+ 后，已在 io 包中实现了

```go
// ReadFile 和 ReadAll 类似，但是 ReadFile 会先判断文件的大小，给 bytes.Buffer 一个预定义容量，避免额外分配内存
func ReadFile(filename string) ([]byte, error)

func WriteFile(filename string, data []byte, perm os.FileMode) error
```



## 2.5 TempFile & TempDir

```go
func TempFile(dir, pattern string) (f *os.File, err error)
func TempDir(dir, pattern string) (name string, err error) 
```

示例：

```go
func TmpFile() {
	fmt.Println(os.TempDir())

	// dir=""时，直接在 os.TempDir() 下操作
	f, err := ioutil.TempFile("", "abc*.txt")
	if err != nil {
		panic(err)
	}

	// 注意关闭和删除文件，以避免临时目录空间被耗空
	defer func() {
		f.Close()
		os.Remove(f.Name())
	}()

	fmt.Println(f.Name())
}
```



## 2.6 Discard

丢弃流，即将数据写入黑洞 `/dev/null`

```go
var Discard io.Writer = io.Discard

// Discard is an Writer on which all Write calls succeed
// without doing anything.
var Discard Writer = discard{}

type discard struct{}

// discard implements ReaderFrom as an optimization so Copy to
// io.Discard can avoid doing unnecessary work.
var _ ReaderFrom = discard{}

func (discard) Write(p []byte) (int, error) {
	return len(p), nil
}

func (discard) WriteString(s string) (int, error) {
	return len(s), nil
}

var blackHolePool = sync.Pool{
	New: func() interface{} {
		b := make([]byte, 8192)
		return &b
	},
}

func (discard) ReadFrom(r Reader) (n int64, err error) {
	bufp := blackHolePool.Get().(*[]byte)
	readSize := 0
	for {
		readSize, err = r.Read(*bufp)
		n += int64(readSize)
		if err != nil {
			blackHolePool.Put(bufp)
			if err == EOF {
				return n, nil
			}
			return
		}
	}
}
```



# 3. bufio - 带缓存的IO

## 3.1 Reader 类型

```go
// Reader implements buffering for an io.Reader object.
type Reader struct {
	buf          []byte
	rd           io.Reader // reader provided by the client
	r, w         int       // buf read and write positions
	err          error
	lastByte     int // last byte read for UnreadByte; -1 means invalid
	lastRuneSize int // size of last rune read for UnreadRune; -1 means invalid
}

func NewReader(rd io.Reader) *Reader                 // size=4096
func NewReaderSize(rd io.Reader, size int) *Reader

// 相关方法
func (b *Reader) Size() int 
func (b *Reader) Reset(r io.Reader) 
func (b *Reader) Peek(n int) ([]byte, error)
func (b *Reader) Discard(n int) (discarded int, err error)

func (b *Reader) Read(p []byte) (n int, err error)

func (b *Reader) ReadByte() (byte, error) 
func (b *Reader) UnreadByte() error 

func (b *Reader) ReadRune() (r rune, size int, err error)
func (b *Reader) UnreadRune() error

// returns the number of bytes that can be read from the current buffer
func (b *Reader) Buffered() int 

func (b *Reader) ReadSlice(delim byte) (line []byte, err error) 
func (b *Reader) ReadLine() (line []byte, isPrefix bool, err error)

func (b *Reader) ReadBytes(delim byte) ([]byte, error)
func (b *Reader) ReadString(delim byte) (string, error) 

func (b *Reader) WriteTo(w io.Writer) (n int64, err error)
```



## 3.2 Writer 类型

```go
type Writer struct {
	err error
	buf []byte
	n   int
	wr  io.Writer
}

func NewWriter(w io.Writer) *Writer
func NewWriterSize(w io.Writer, size int) *Writer

func (b *Writer) Size() int
func (b *Writer) Reset(w io.Writer)
func (b *Writer) Flush() error

// returns how many bytes are unused in the buffer
func (b *Writer) Available() int

func (b *Writer) Buffered() int

func (b *Writer) Write(p []byte) (nn int, err error)
func (b *Writer) WriteByte(c byte) error
func (b *Writer) WriteRune(r rune) (size int, err error)
func (b *Writer) WriteString(s string) (int, error) 

func (b *Writer) ReadFrom(r io.Reader) (n int64, err error)
```



## 3.3 Scanner 类型

Scanner，比Reader更容易的处理如按行读取输入序列或空格分隔单词等。它终结了如输入一个很长的有问题的行这样的输入错误，并且提供了简单的默认行为：基于行的输入，每行都剔除分隔标识

```go
type Scanner struct {
	r            io.Reader // The reader provided by the client.
	split        SplitFunc // The function to split the tokens.
	maxTokenSize int       // Maximum size of a token; modified by tests.
	token        []byte    // Last token returned by split.
	buf          []byte    // Buffer used as argument to split.
	start        int       // First non-processed byte in buf.
	end          int       // End of data in buf.
	err          error     // Sticky error.
	empties      int       // Count of successive empty tokens.
	scanCalled   bool      // Scan has been called; buffer is in use.
	done         bool      // Scan has finished.
}

type SplitFunc func(data []byte, atEOF bool) (advance int, token []byte, err error)

func NewScanner(r io.Reader) *Scanner 

func (s *Scanner) Err() error
func (s *Scanner) Bytes() []byte
func (s *Scanner) Text() string
func (s *Scanner) Scan() bool
func (s *Scanner) Buffer(buf []byte, max int)
func (s *Scanner) Split(split SplitFunc) 

func ScanBytes(data []byte, atEOF bool) (advance int, token []byte, err error)
func ScanRunes(data []byte, atEOF bool) (advance int, token []byte, err error) 
func ScanLines(data []byte, atEOF bool) (advance int, token []byte, err error)
func ScanWords(data []byte, atEOF bool) (advance int, token []byte, err error)
```



示例1：标准输入缓冲

```go
func main() {
	scanner := bufio.NewScanner(os.Stdin)
	
	for scanner.Scan() {
		fmt.Println(scanner.Text()) // Println will add back the final '\n'
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "reading standard input:", err)
	}
}
```



示例2：单词统计

```go
func main() {
	const input = "This is The Golang Standard Library.\nWelcome you!\nIt is a test!"

	scanner := bufio.NewScanner(strings.NewReader(input))
	scanner.Split(bufio.ScanWords) // 单词

	count := 0
	for scanner.Scan() {
		count++
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "reading input:", err)
	}

	fmt.Println(count)
}
```







