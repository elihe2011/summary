# 1. 远程连接

mysql 5.7+:

```mysql
create user admin; 
GRANT ALL PRIVILEGES ON *.* TO admin@"%" IDENTIFIED BY 'admin' WITH GRANT OPTION;
flush privileges; 
```



mysql8.0+:

```mysql
use mysql;
select host, user, authentication_string, plugin from user;

-- 本地连接
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456';
flush privileges;

-- 远程连接
create user 'root'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
flush privileges;
```

