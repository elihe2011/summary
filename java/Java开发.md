# 1. 安装Java1.8

下载地址：https://sourceforge.net/projects/portableapps/files/JDK/jdk-8u381-windows-x64.exe/download

安装后，设置环境变量：我的电脑>>属性>>高级系统设置>>高级>>环境变量

```bat
JAVA_HOME=C:\Program Files\Java\jdk-1.8
CLASSPATH=.;%JAVA_HOME%\lib;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar;

# XXX以前的保持不变
Path=%JAVA_HOME%\bin;%JAVA_HOME%\jre\bin;XXX
```

重新打开PowerShell，检查环境变量：

```powershell
PS C:\Windows\system32> java -version
java version "1.8.0_381"
Java(TM) SE Runtime Environment (build 1.8.0_381-b09)
Java HotSpot(TM) 64-Bit Server VM (build 25.381-b09, mixed mode)
```



# 2. Maven

## 2.1 安装

下载地址：https://dlcdn.apache.org/maven/maven-3/3.9.4/binaries/apache-maven-3.9.4-bin.tar.gz

创建目录 C:\Maven，解压安装包到该目录下

设置环境变量：

```bash
M2_HOME=C:\Maven\apache-maven-3.9.4
Path=%M2_HOME%\bin;XXX

export M2_HOME=/usr/local/apache-maven-3.9.4
export PATH=$PATH:$M2_HOME/bin
```

重新打开PowerShell，检查环境变量：

```powershell
PS C:\Windows\system32> mvn -v
Apache Maven 3.9.4 (dfbb324ad4a7c8fb0bf182e6d91b0ae20e3d2dd9)
Maven home: C:\Maven\apache-maven-3.9.4
Java version: 1.8.0_381, vendor: Oracle Corporation, runtime: C:\Program Files\Java\jdk-1.8\jre
Default locale: en_US, platform encoding: GBK
OS name: "windows 10", version: "10.0", arch: "amd64", family: "windows"
```



## 2.2 仓库配置

修改 `C:\Maven\apache-maven-3.9.4\conf\settings.xml`

本地仓库：

```xml
<settings ...>
  <localRepository>E:\Maven\home\repo</localRepository>
</settings>
```



远程仓库：

```xml
  <mirrors>
    ...
    <mirror>
      <id>alimaven</id>
      <name>aliyun maven</name>
      <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
```



## 2.3 依赖配置

修改 `pom.xml`文件：

```xml
<dependency>
    <groupId>commons-logging</groupId>
    <artifactId>commons-logging</artifactId>
    <version>1.2</version>
</dependency>
```

对于某个依赖，Maven只需要3个变量即可唯一确定某个jar包：

- groupId：属于组织的名称，类似Java的包名；
- artifactId：该jar包自身的名称，类似Java的类名；
- version：该jar包的版本。



## 2.4 依赖管理

Maven定义了几种依赖关系，分别是`compile`、`test`、`runtime`和`provided`：

| scope    | 说明                                          | 示例            |
| :------- | :-------------------------------------------- | :-------------- |
| compile  | 编译时需要用到该jar包（默认）                 | commons-logging |
| test     | 编译Test时需要用到该jar包                     | junit           |
| runtime  | 编译时不需要，但运行时需要用到                | mysql           |
| provided | 编译时需要用到，但运行时由JDK或某个服务器提供 | servlet-api     |

其中，默认的`compile`是最常用的，Maven会把这种类型的依赖直接放入classpath。

`test`依赖仅在测试时使用，最常用的就是JUnit：

```
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter-api</artifactId>
    <version>5.3.2</version>
    <scope>test</scope>
</dependency>
```

`runtime`依赖编译时不需要，但运行时需要。最典型的`runtime`依赖是JDBC驱动：

```
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <version>5.1.48</version>
    <scope>runtime</scope>
</dependency>
```

`provided`依赖编译时需要，但运行时不需要。最典型的`provided`依赖是Servlet API，编译的时候需要，但是运行时，Servlet服务器内置了相关的jar，所以运行期不需要：

```
<dependency>
    <groupId>javax.servlet</groupId>
    <artifactId>javax.servlet-api</artifactId>
    <version>4.0.0</version>
    <scope>provided</scope>
</dependency>
```



## 2.5 常用命令

`mvn clean`：清理所有生成的class和jar；

`mvn clean compile`：先清理，再执行到`compile`；

`mvn clean test`：先清理，再执行到`test`，因为执行`test`前必须执行`compile`，所以这里不必指定`compile`；

`mvn clean package`：先清理，再执行到`package`。

经常用到的phase其实只有几个：

- clean：清理
- compile：编译
- test：运行测试
- package：打包



