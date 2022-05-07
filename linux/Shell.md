# 1. EOF

What is different between "<<-EOF" and "<<EOF" in bash script ？

<<-EOF will ignore leading tabs in your heredoc, while <<EOF will not. Thus:

```bash
cat <<EOF
    Line 1
    Line 2
EOF

# will produce
    Line 1 
    Line 2
```

while

```bash
cat <<-EOF
    Line 1
    Line 2
EOF

# produces
Line 1 
Line 2
```

example:

```bash
function foo() { 
        # the end EOF cannot be preceded and followed by any characters 
        cat <<EOF 
        Line 1 
        Line 2 
EOF 
        echo '--------------' 
        cat <<-EOF 
        Line 1 
        Line 2 
        EOF

        echo '--------------' 
        cat <<-EOF 
        Line 1 
        Line 2 
EOF 
}

# output
        Line 1 
        Line 2 
-------------- 
Line 1 
Line 2 
-------------- 
Line 1 
Line 2
```



# 2. $* 和 $@

$*和$@: 获取传递给脚本或函数的所有参数

在没有双引号包裹时：$*与 $@相同，都是数组

在有双引号包裹时："$*" 是一个字符串，而 "$@" 依旧为数组

```bash
#!/bin/sh

foo() {
    for var in "$@"
    do
        echo ${var}
    done
}

bar() {
    for var in "$*"
    do
        echo ${var}
    done
}
 
# 1 
# 2 
# 3 
# 4 
foo 1 2 3 4
 
# 1 2 3 4
bar 1 2 3 4
```



# 
