

# 1. openssl

```bash
# 生成RSA私钥  pkcs#1
openssl genrsa -out private.pem 1024

# 生成公钥
openssl rsa -in private.pem -pubout -out public.pem

# 生成证书请求文件
openssl req -new -key private.pem -out rsaCerReq.csr

# 生成证书，设置有效时间10年
openssl x509 -req -days 3650 -in rsaCerReq.csr -signkey private.pem -out rsaCert.crt

# 生成供iOS使用的公钥文件public_key.der
openssl x509 -outform der -in rsaCert.crt -out public.der

# 生成供iOS使用的私钥文件private_key.p12
openssl pkcs12 -export -out private.p12 -inkey private.pem -in rsaCert.crt
```



# 2. `PKCS#1` 和 `PKCS#8`

`PKCS#1` :

```bash
$ openssl genrsa -out PKCS1.pem 2048

$ cat PKCS1.pem
-----BEGIN RSA PRIVATE KEY-----
 .......
-----END RSA PRIVATE KEY-----`
```



`PKCS#8`:

```bash
# 证书转换
$ openssl pkcs8 -topk8 -inform PEM -in PKCS1.pem -outform PEM -nocrypt -out PKCS8.pem

$ cat PKCS8.pem
-----BEGIN PRIVATE KEY-----
............
-----END PRIVATE KEY-----
```



# 3. SM2

## 3.1 简介

SM2 国密算法是一种非对称加密算法，基于 ECC（椭圆加密算法）， SM2 算法对标我们常用的国际算法 RSA。

但是 SM2 算法由于基于 ECC，签名速度与秘钥速度都快于 RSA。另外 SM2 采用 ECC 256 位，安全强度比 RSA 2048 位更高，且运算速度同样也高于 ESA。

熟悉 RSA 算法同学应该知道，非对称加密算法，会有一对公私钥。

- 私钥可以用于加签，公钥可以用于验签。
- 公钥可以用于加密，私钥可以用于解密

同样 SM2 算法也有一对公私钥，它们的长度远远小于 RSA 公私钥。

SM2 私钥，一个大于等于 1 且小于 n-1的整数(n 为 sm2 算法的阶)，长度为 256 位，即 32 个字节，通常会用 16 进制表示。

```Java
SM2 私钥：B17EACC0BB629AB92C591287F2FA4589D10CD1E13BD4BDFDC9589A940F937C7C
```

SM2 公钥，SM2 椭圆曲线上的一个点，由横坐标与纵坐标两个分量构成，每个长度分量长度为 256 位，通常也用 16 进制表示。

SM2 公钥一般有两种表示方法：

- X|Y，即 X与 Y两个分量拼接在一起，总共 64 个字节。

    - 04|X|Y，有些给出公钥与上面格式一样，只不过前面增加 04，代表非压缩，整个公钥长度变成 65 字节。

- 分开展示，公钥 X，公钥 Y

```Java
公钥 X|Y：53B97D723AA4CEAC97A13B8C50AA53D40DE36960CFC3A3D7929FD54F39F824ED5A4A27AF871AD62C25C75C9D75C75A0907C565A78B805E9502E616C4E77F3B42
公钥 X:53B97D723AA4CEAC97A13B8C50AA53D40DE36960CFC3A3D7929FD54F39F824ED
公钥 Y:5A4A27AF871AD62C25C75C9D75C75A0907C565A78B805E9502E616C4E77F3B42
```





1. sm2 是非对称加密
2. 私钥 长度 32 字节（256 位）,公钥长度 64 字节 （512 位）
3. 密文长度和明文相同
4. 签名长度是 64 字节



在SM2算法中，密钥的格式分以下几种：

- 私钥：

	- D值 一般为硬件直接生成的值

	- `PKCS#8` JDK默认生成的私钥格式

	- `PKCS#1` 一般为OpenSSL生成的的EC密钥格式

  

- 公钥：

  - Q值 一般为硬件直接生成的值
  - X.509 JDK默认生成的公钥格式
  - PKCS#1 一般为OpenSSL生成的的EC密钥格式




## 3.2 安装工具

不推荐：https://github.com/guanzhi/GmSSL  （渣，问题较多）

推荐：openssl1.1.1 已支持sm相关算法

```bash
wget --no-check-certificate https://www.openssl.org/source/openssl-1.1.1n.tar.gz
tar zxvf openssl-1.1.1n.tar.gz
cd openssl-1.1.1n

./config 
make
make install
```



## 3.3 生成证书

```bash
$ openssl version
OpenSSL 1.1.1n  15 Mar 2022

$ openssl ecparam -list_curves | grep -i sm2
  SM2       : SM2 curve over a 256 bit prime field

# 生成sm2私钥
$ openssl ecparam -genkey -name SM2 -out sm2.pem

# 生成对应公钥 
openssl ec -in sm2.pem -pubout -out sm2Pub.pem

# 查看私钥
openssl ec -in sm2.pem -text

# 私钥pkcs#1转pkcs#8
openssl pkcs8 -topk8 -inform PEM -in sm2.pem -outform pem -nocrypt -out sm2pkcs8.pem
```



# 4. PKI 数据格式

PKI：公共密钥基础设施

## 4.1 ASN.1符号

 抽象语法标记(ASN.1)是数据类型和值的定义的一种规范语言，并且那些数据类型和值如何使用并且 被结合以多种数据结构。标准的目标是定义信息抽象语法没有限制条件信息如何为发射编码。 

X.509 RFC部分的示例： 

```ASN.1
Version ::= INTEGER { v1(0), v2(1), v3(2) } 
CertificateSerialNumber ::= INTEGER 
Validity ::= SEQUENCE { notBefore Time, notAfter Time } 
Time ::= CHOICE { utcTime UTCTime, generalTime GeneralizedTime }
```



## 4.2 BER/CER/DER编码

 ITU-T定义编码数据结构一个标准的方式在ASN.1描述的到二进制数据。X.690定义了基本编码规则 (BER)和其两子集、规范编码规则(CER)和著名的编码规则(DER)。全部三根据在一层次结构包装的 类型长度值数据域，从顺序、集和选择被建立，与这些差异： 

- BER提供编码同一个数据多种方式，没有适用与crypto操作。 

- CER提供毫不含糊的编码并且以一数据结尾标记在特定情况下使用不确定长度数据。 

- DER提供毫不含糊的编码并且在特定情况下使用明确长度标记。 

- 在三中， DER是通常遇到，当交易与PKI和crypto有效载荷时的那个。 

  

示例：在DER， 20位值1010 1011 1100 1101 1110编码如下： 

- 标记：0x03 (bitstring) 
- 长度：0x04 (字节) 
- 值：04 0x 0 ABCDE 
- 完整DER编码： 0x030404ABCDE0 

导致04意味着必须丢弃最后4个位(等于落后0位)编码的值，因为编码的值在字节边界不结束。



## 4.3 Base64编码

 Base64编码类似只代表与64个可印字符(A-Za-z0-9+/)的二进制数据于UUENCODE。在转换从二进 制到Base64，原始数据的每6位块编码到与转换表的一个8位可打印的ASCII字符。所以，数据的大 小，在编码由33百分比后(数据增加计时6个位分开的8，等于1.333)。 

24位缓冲区使用三(3)八组的转换(8)位到六(6)位的四(4)组里。所以一(1)或两(2)填充字节也许要求在 输入数据流结束时。填充符表示在Base64-encoded数据结束时，由一个等于(=)每八组(8)填充位的 符号被添加到输入在编码期间。





## 4.4 PEM编码

增强加密邮件(PEM)是一个全双工互联网工程任务组(IETF) PKI标准为了交换安全消息。它同样地不 再用途广泛，但是其封装语法广泛被借用为了格式化和交换Base64-encoded Pki相关数据。 

PEM RFC 1421：封装机制，定义了PEM消息如分隔由封装限定范围(EBs)，根据RFC 934，与此格式：

```x
 -----BEGIN PRIVACY-ENHANCED MESSAGE----- 
 Header: value 
 Header: value 
 ... 
 Base64-encoded data 
 ... 
 -----END PRIVACY-ENHANCED MESSAGE-----
```

实际上，当分配时PEM格式化的数据，此边界格式使用今天： 

```key
-----BEGIN type----- 
... 
-----END type-----
```

 类型可以是其他密钥或证书例如： 

- RSA 
- X509 CRL 



## 4.5 X.509证书和Crl 

X.509是X.500的一子集，是关于开放式系统互联的一个延长的ITU规格。它特别地处理证书和公共 密钥和适应作为互联网标准由IETF。X.509提供一个结构和语法，表示用RFC ASN.1符号，为了存 储证书信息和证书撤销列表。 

例如在X.509 PKI， CA问题绑定公共密钥的证书， ：Rivest Shamir Adelman (RSA)或数字签名算 法(DSA)密钥对一个特定的特有名(DN)，或者对一代替名称例如电子邮件地址或完全合格的域名 (FQDN)。DN跟随在X.500标准的结构。示例如下： 

`CN=common-name OU=organizational-unit O=organization L=location C=country `

由于ASN.1定义， X.509数据可以编码到DER为了交换以二进制形式，和或者，转换对文本基于通 信方式的Base64/PEM，例如在终端的复制-粘贴。



## 4.6 PKCS标准

公钥加密标准(PKCS)是从部分转变了成业界标准的RSA实验室的规格。经常遇到的那些，与这些主 题的交易;然而，不是所有与数据格式的交易。 

PKCS-1 (RFC 3347) -报道基于RSA的加密算法的实施方面(crypto原始，加密/签名策划， ASN.1语 法)。 

PKCS#5 (RFC 2898) -报道基于密码的密钥派生。 

PKCS-7 (RFC 2315)和S/MIME RFC 3852 -定义了消息语法传送签字和已加密数据和涉及的证书。 常用完全作为X.509证书的一个容器。 

PKCS#8-定义了消息语法传输明文或已加密RSA密钥对。 PKCS#9 (RFC 2985) -定义了另外的对象类和标识属性。 

PKCS-10 (RFC 2986) -定义了证书签名请求的(CSR)消息语法。CSR由实体发送对CA并且包含 CA将签字的信息，例如公共密钥关键信息、标识和另外的属性。

PKCS-12 -定义了包的相关PKI数据的一个容器(典型地，实体密钥对+实体cert +根和半成品CA证书 )在单个文件内。它是Microsoft的个人信息信息交换(PFX)格式的演变。





- `.pem`– (**隐私增强型电子邮件**) **DER**编码的证书再进行 **Base64** 编码的数据存放在”——-BEGIN CERTIFICATE——-“和”——-END CERTIFICATE——-“之中

- `.cer, .crt, .der` – 通常是**DER**二进制格式的，但 **Base64** 编码后也很常见。

- `.p7b, .p7c` – `PKCS#7`

	- `PKCS#7` 是签名或加密数据的格式标准，官方称之为容器。由于证书是可验真的签名数据，所以可以用 **SignedData** 结构表述。
	- `P7C`文件是退化的 **SignedData** 结构，没有包括签名的数据。

- `.p12` – `PKCS#12`格式，包含证书的同时可能还有带密码保护的私钥

	- `PKCS#12` 由 **PFX** 进化而来的用于交换公共的和私有的对象的标准格式。

- `.pfx`– **PFX，PKCS#12**之前的格式（通常用 **PKCS#12** 格式，比如那些由 **IIS** 产生的 **PFX** 文件）





https://www.cisco.com/c/zh_cn/support/docs/security/vpn-client/116039-pki-data-formats-00.pdf