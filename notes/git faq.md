使用 git rebase 合并 commit



# 1. 查询记录

使用 git log，查看 commit 记录，找到最近的 dev 分支后面的记录

```bash
$ git log --pretty=oneline --abbrev-commit
fdbdd22 (HEAD, dev-eli) 日志重构
1406224 日志中间件
ee01d09 casbin rule change
65c523f (origin/dev, dev) pub.api
1a23f96 身份和权限认证
...
```

如示例，当前需要合并的记录分别是：

- fdbdd22
- 1406224
- ee01d09



# 2. 执行命令

命令解释：

```bash
$ git rebase -i [startpoint] [endpoint]

# -i, --interactive  弹出交互式界面让用户编辑完成合并操作
# [startpoint]  合并区间的起点(不包含)
# [endpoint]    合并区间的终点，默认是当前分支 HEAD 所指向的 commit
```

交互窗口命令说明：

- p, pick：保留提交
- r, reword：保留提交，可以修改提交注释
- e, edit：保留提交，但停下来修改该提交(不仅仅是注释)，可用来解决merge冲突
- s, squash：将该提交和前面一个提交合并
- f, fixup：将该提交和前面一个提交合并，但不保留该提交的注释信息
- e, exec：执行 shell 命令
- d, drop：丢弃该提交



任选其中一条命令执行：

```bash
# 指定合并区间起点(不包含)和终点
$ git rebase -i 65c523f fdbdd22

# 合并区间终点默认为HEAD
$ git rebase -i 65c523f 

# 合并最近三个提交
$ git rebase -i HEAD~3
```



编辑提交内容：

将 pick 修改为 squash或s，然后`:wq`保存退出

```bash
pick ee01d09 casbin rule change
squash 1406224 日志中间件  # pick => squash
squash fdbdd22 日志重构    # pick => squash
...
```

编辑提交注释：

```bash
# This is a combination of 3 commits.
# This is the 1st commit message:

casbin rule change

# This is the commit message #2:

日志中间件

# This is the commit message #3:

日志重构

...
```

修改为：

```bash
# This is the 1st commit message:

日志中间件重构

...
```

操作结果：

```bash
$ git rebase -i HEAD~3
[detached HEAD c17c2ba] 日志中间件重构
 Date: Thu Mar 30 09:22:55 2023 +0800
 23 files changed, 639 insertions(+), 200 deletions(-)
 rename internal/handler/sys/{user_policy_handler.go => policy_handler.go} (62%)
 create mode 100644 internal/handler/user/logout_handler.go
 rename internal/logic/sys/{user_policy_logic.go => policy_logic.go} (57%)
 create mode 100644 internal/logic/user/logout_logic.go
 create mode 100644 internal/middleware/log_middleware.go
 create mode 100644 model/log/exception_log.go
 create mode 100644 model/log/login_log.go
 create mode 100644 model/log/operation_log.go
 create mode 100644 plugins/crypt/password_test.go
Successfully rebased and updated detached HEAD.
```



再次查看日志，已合并：

```bash
$ git log --pretty=oneline --abbrev-commit
c17c2ba (HEAD) 日志中间件重构
65c523f (origin/dev, dev) pub.api
1a23f96 身份和权限认证
...
```



# 3. 放弃修改

强制覆盖本地代码

```bash
$ git fetch --all
$ git reset --hard origin/master 
$ git pull
```



简化版提交步骤：

```bash
# 拉取最新的代码
git pull

# 查询操作日志
$ git log --pretty=oneline --abbrev-commit
fdbdd22 (HEAD, dev-eli) 日志重构
1406224 日志中间件
ee01d09 casbin rule change
65c523f (origin/dev, dev) pub.api   # dev 分支后修改的commit，此处3个
1a23f96 身份和权限认证
...

# 操作后，检查代码，删除或修改不合适的
$ git reset HEAD~3   

# 提交代码，一个提交点
git add .
git commit -am '日志重构功能'

# 合并dev分支，如果有冲突，先解决冲突
git merge dev

# 推送分支
git push -f
```

