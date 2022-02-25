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


