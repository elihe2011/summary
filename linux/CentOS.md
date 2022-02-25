# 1. 运行级别

```bash
# 获取
$ systemctl get-default
multi-user.target

$ runlevel 
N 5

# 设置
$ systemctl set-default  multi-user.target   
$ systemctl set-default  graphical.target
```



