换源

```bash
cd /etc/yum.repos.d/
mkdir bak
mv *.repo bak

wget http://mirrors.aliyun.com/repo/Centos-8.repo
yum update

sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

yum makecache
```



安装 rsyslog-mysql

```bash
 yum install rsyslog-mysql -y
 
 cd /usr/share/doc/rsyslog/
 cat mysql-createDB.sql
```







修改 rsyslog 配置

```bash
vi /etc/rsyslog.conf

#### MODULES ####
...
module(load="ommysql")   # 添加


#### RULES ####
...
# save to mysql
*.info;mail.none;authpriv.none;cron.none                :ommysql:127.0.0.1,Syslog,syslog,123456
```





安装数据库

```bash
yum install mariadb-server -y

systemctl start mariadb.service
systemctl enable mariadb.service
systemctl status mariadb.service
```



创建数据库和表

```bash
mysql < /usr/share/doc/rsyslog/mysql-createDB.sql
```



创建数据库账号

```bash
mysql
grant all on Syslog.* to syslog@'%' identified by '123456'; 
```



启动 rsyslog 服务

```bash
systemctl restart rsyslog.service
```



查看数据

```bash
mysql

MariaDB [(none)]> use Syslog;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [Syslog]> show tables;
+------------------------+
| Tables_in_Syslog       |
+------------------------+
| SystemEvents           |
| SystemEventsProperties |
+------------------------+
2 rows in set (0.000 sec)

MariaDB [Syslog]> select count(*) from SystemEvents;
+----------+
| count(*) |
+----------+
|        8 |
+----------+
1 row in set (0.000 sec)

```





安装 LogAnalyzer



安装 php

```bahs
yum install httpd php php-mysqlnd -y
```



[Download Archives - Adiscon LogAnalyzer](https://loganalyzer.adiscon.com/downloads/)

```bash
wget https://download.adiscon.com/loganalyzer/loganalyzer-4.1.13.tar.gz

tar zxvf loganalyzer-4.1.13.tar.gz
cd loganalyzer-4.1.13

mkdir -p /var/www/html/loganalyzer
cp -r src/* /var/www/html/loganalyzer
cp contrib/configure.sh /var/www/html/loganalyzer

cd /var/www/html/loganalyzer
bash configure.sh
chcon -h -t httpd_sys_script_rw_t config.php
```



修改 php-fpm

```bash
vi /etc/httpd/conf/httpd.conf
...
<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>
```



启动 apache

```bash
systemctl start httpd
systemctl enable httpd
systemctl status httpd

```





```bash
1) /usr/sbin/setenforce — 修改SELinux运行模式，例子如下：
• setenforce 1 — SELinux以强制(enforcing)模式运行
• setenforce 0 — SELinux以警告(permissive)模式运行
为了关闭SELinux，你可以修改配置文件：/etc/selinux/config或/etc/sysconfig/selinux



```

