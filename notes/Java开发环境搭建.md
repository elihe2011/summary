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
MAVEN_HOME=C:\Maven\apache-maven-3.9.4
Path=%MAVEN_HOME%\bin;XXX
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









```bash
docker run -d --
```

