# 1. pymysql 连接 MySQL8.0

```python
连接数据库代码：
import pymysql
conn = pymysql.connect(host='127.0.0.1',port=3306,user='root',password='111111',db='testDB',charset='utf8')
此时报错：pymysql.err.OperationalError: (1045, u"Access denied for user 'root'@'localhost' (using password: NO)")

只是由于MySQL8.0对于密码的认证方式已经变为了caching_sha2_password，所以我们只需要改下连接用户的密码认证方式就OK了

进入MySQL更改认证方式，改为 mysql_native_password：

ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '111111';
```

