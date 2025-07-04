# 1. 概念

Git 特点：

- 直接存储文件快照（特定时间点得完整文件），而非存储差异
- 几乎所有操作都在本地执行，只有同步版本库才需要联网
- 天然得数据完整性校验（SHA-1，40bits）



文件变更的三个阶段：

- 修改(modified)
- 暂存(staged) 已加入下次提交列表
- 提交(committed) 保存到版本数据目录



三个阶段数据存放区域：

- 工作目录 (workspace)
- 暂存索引文件 (.git/index)
- 本地数据目录 (.git/objects)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/git/git-transport-cmds.png)



# 2. 设置

## 2.1 用户

```bash
git config --global user.name 'eli.he'
git config --global user.email 'eli.he@live.cn'
```



## 2.2 属性

```bash
git config --list

git config --global core.autocrlf false
```



## 2.3 密钥

```bash
# 生成密钥
ssh-keygen -t rsa -C 'eli.he@live.cn'

# 上传公钥 id_rsa.pub 至SSH keys管理
cat ~/.ssh/id_rsa.pub

# 测试连通性
ssh -T git@github.com
```



## 2.4 忽略提交

- 全局(.gitignore)
- 个人(.git/info/exclude)



# 3. 版本库

## 3.1 新建

```bash
mkdir test
cd test
git init

# 配置远程地址
git remote add origin git@github.com:elihe2011/test.git
```



## 3.2 克隆

```bash
# 默认远程仓库名为origin
git clone https://github.com/elihe2011/abc.git

# 指定远程仓库名为git_prj
git clone -o git_prj https://github.com/elihe2011/abc.git
```



## 3.3 远程库

```bash
# 查看
git remote -v
git remote show origin

# 获取但不合并
git fetch origin master
git fetch ～/github/new_test master

# 获取并合并
git pull origin master
git pull ～/github/new_test master


```



## 3.4 提交

```bash
git add .
git commit -m 'add a.txt' a.txt
git commit -m 'add all'

git commit -am 'commit tracked files'

git commit -m --amend --no-edit  # 使用新的commit替代原有的，保持commit描述不变
```



通用提交备注：

- feat: 新功能（feature）
- fix: 修补bug
- docs: 文档（documentation）
- style: 格式（不影响代码运行的变动）
- refactor: 重构（即不是新增功能，也不是修改bug的代码变动）
- chore: 构建过程或辅助工具的变动
- revert: 撤销，版本回退
- perf: 性能优化
- test：测试
- improvement: 改进
- build: 打包
- ci: 持续集成 



## 3.5 推送

```bash
git push -u origin master 

# -u, --set-upstream 第一次push的时候需要，自动添加如下配置
branch.master.remote=origin
branch.master.merge=refs/heads/master
```



# 4. 文件操作

## 4.1 对比

```bash
# workspace, staged
git diff hello.py 

# satged, local-repo
git diff --cached

# local-repo, remote-repo
git diff master origin/master
```



## 4.2 撤销

### 4.2.1 checkout

workspace 和 staged 撤销修改

```bash
# 撤销本次修改，commit前均可操作
git checkout hello.py    

# 使用特定commit的文件，替换staged和workspace下的文件
git checkout ad12sa1 hello.py       
cat .git/HEAD               # defd8bb....
```



### 4.2.2 reset

不可恢复撤销（谨慎操作）

```bash
# 回滚staged，git add的反操作
git reset [<files>]

# 回滚staged和workspace，回到最近一次提交
git reset [<files>] --hard

# 回滚staged到指定commit，之前的提交全部删除
git reset <commit>

# workspace也回滚
git reset <commit> --hard

# 作用于staged
git reset --mixed HEAD
```



reset将一个分支的末端指向另一个提交，并移除当前分支的一些提交

```bash
git checkout hotfix
git reset HEAD~2
```

**hotfix分支末端的两个提交变成悬挂提交，下次Git执行垃圾回收时，这两个提交会被删除**。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/git/git_reset.png)



撤销缓存区和工作目录：

- --soft	缓存区和工作目录均不修改
- --mixed    默认项，缓存区同步到你指定的提交，但工作目录不受影响
- --hard       缓存区和工作目录均同步到你指定的提交

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/git/git_reset2.png)

使用前提：**你的更改未分享给别人，git reset是撤销这些更改的简单方法**



### 4.2.3 revert

撤销已提交的快照，但不从项目中删除这个 commit，新生成一个 commit

```bash
touch 1.txt 2.txt 3.txt
git add .
git commit -m 'add 1.txt' 1.txt
git commit -m 'add 2.txt' 2.txt
git commit -m 'add 3.txt' 3.txt

git log --oneline -5
git revert cc79f5a          # revert 2.txt
ls -l [1-3].txt             # 1.txt, 3.txt
```



revert撤销一个提交同时会创建一个新的提交。比reset安全，且不会重写提交历史

```bash
git checkout hotfix
git revert HEAD~2
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/git/git_revert.png)

**reset vs revert**:

- **reset**：撤销本地修改，会完整地删除一个 change set，适用于私有分支。
- **revert**：安全地撤销一个公共 commit，会保留最初的 change set，新建一个 commit，适用于公共分支。



### 4.2.4 总结

常用撤销操作：

```bash
# 已修改，未暂存
git checkout .
git reset --hard

# 已暂存，未提交
git reset
git checkout .

or
git reset --hard

# 已提交，未推送
git reset --hard origin/master

# 已推送
git reset --hard HEAD^
git push -f origin master
```



| 命令         | 操作区域                         |
| ------------ | -------------------------------- |
| checkout     | staged -> workspace              |
| reset        | committed -> staged              |
| reset --hard | committed -> staged -> workspace |



## 4.3 删除

### 4.3.1 已 traced

```bash
# 删除workspace中的文件，如果已在staged中，报错
git rm a.txt

# 同时删除workspace & staged文件，保留committed文件
git rm -f a.txt

# 同时删除staged & committed文件，保留workspace文件
git rm --cached a.txt

# 清理已被删除的所有文件
git rm $(git ls-files --deleted)
```



### 4.3.2 未 traced

```bash
git clean -f
git clean -df
```



## 4.4 大小写

已被提交的文件，直接修改文件名大小写，不会触发变更

**方法一**：git mv 文件重命名

```bash
# 文件
git mv test.txt TEST.txt

# 目录，不能直接修改，按下面迂回修改
git mv test-dir tmp
git mv tmp TEST-DIR

# 提交和推送
git commit -m "注释"
git push
```



**方法二**：关闭大小写敏感配置 （不推荐）

```bash
# 关闭大小写敏感配置
git config core.ignorecase false

# 删除缓存区文件
git rm -r --cached test.txt
git rm -r --cached test-dir
 
# 提交和推送
git commit -m "注释"
git push
```



# 5. 标签

## 5.1 创建

```bash
# 为当前分支最近一次提交创建标签
git tag 1.0

# 标签 develop/1.1
git tag develop_1.1 develop

# 为某个历史提交创建标签
git tag 1.2 66cbbb4
```



## 5.2 查询

```bash
git tag
git tag -l '1.2.*'
git show 1.1
```



## 5.4 检出

```bash
git checkout 1.0
```



## 5.5 删除

```bash
git tag -d 1.1
```



# 6. 日志

## 6.1 git log

```bash
git log
git log -5
git log stat    # 详细日志
git log -p      # 更详细日志

git log --author='eli'

git log --grep='modify'     # 过滤提交描述

git log --graph
git log --graph --decorate --oneline

git log --oneline

git log ada6cb2..62a89cf

git log --merges
git log --no-merges     # 过滤merge提交

git log --since='2017-11-20' --until='2017-12-01'

git log --pretty=format:"%cn committed %h on %cd"
    
# 格式化参数
%cn     committer name
%h      commit hash
%cd     commit date
%s      short message

git log --pretty="%h - %s" --author='eli' --since='2017-11-27 00:00:00' --before='2017-11-27 11:59:59'
```



## 6.2 git reflog

```bash
# 所有分支日志
git reflog --relative-date
```



## 6.3 git shortlog

```bash
git shortlog
```



# 7. 分支

## 7.1 创建

```bash
# 从当前分支创建新分支，但不切换
git branch develop

# 从当前分支创建新分支，并切换
git checkout -b develop

# 从develop分支创建新分支
git checkout -b test develop
```



## 7.2 删除

```bash
# 删除已merge的分支
git branch -d develop

# 强制删除分支，不管是否已merge
git branch -D develop
```



## 7.3 更名

```bash
git branch -m dev
```



## 7.4 切换

本质上是更新HEAD指向给定的branch或commit

```bash
git checkout develop

git checkout -b test

# 产生detached HEAD状态，detached意味着当前所有修改和项目发展的其他部分完全脱离，无法被merge
git checkout <commit>

git checkout <tag>
```



## 7.5 合并

### 7.5.1 merge

```bash
# 自动指定merge算法
git merge <branch>

# 强制fast-forword merge算法
git merge --on-ff <branch>

# 撤销合并，只能在合并冲突时使用
git merge --abort 
```



### 7.5.2 rebase

重定义分支起点：`git rebase <base>   # base: commit, tag, branch, HEAD~N`

```bash
git checkout -b develop
touch echo.py
git add echo.py
git commit -m 'add echo.py on develop branch'

git checkout master
touch print.py
git add print.py
git commit -m 'add print.py on master branch'

git checkout develop
git rebase master       # 将整个develop分支的commit放在master分支之后，不会创建merge commit，但会为develop分支的每个commit创建一个新的commit

git checkout master
git merge develop       # 只产生merge commit，分支commit不合入
```



### 7.5.3 总结

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/git/git-rebase-merge.png)



**merge vs rebase**：

- **merge**：
  - 不会改写已有提交，保留分支的历史轨迹
  - 适合团队协作，保留谁干了什么、何时合并的痕迹
- **rebase**：
  - 支持将多个提交合并成一个，删除历史提交痕迹
  - 适合于个人开发者提交前清理历史



**git pull**：

- 默认按 merge 方式合并
- `--rebase` 按 rebase 方式合并



## 7.6 远程分支

```bash
# 查询远程分支
git ls-remote

# 跟踪远程分支
git checkout -b daily origin/daily
git checkout --track origin/daily	# 本地和远程的分支名保持一致

# 添加本地分支与远程分支的关联关系（--set-upstream-to=）
git branch -u origin/daily

# 查询当前已跟踪的分支
git branch -vv

# 删除远程分支
git push origin --delete daily

# 远程仓库被删除，导致无法pull
git remote prune origin
```



# 8. 实操案例

## 8.1 rebase 合并

### 8.1.1 查询记录

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



### 8.1.2 执行命令

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



## 8.2 放弃修改

强制覆盖本地代码

```bash
$ git fetch --all
$ git reset --hard origin/master 
$ git pull
```



简化步骤：

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



## 8.3 删除分支

```bash
git branch -d dev-xxx      # 删除本地分支
git push origin -d dev-xxx # 删除远程分支
```



# 9. 其它

## 9.1 归档

```bash
git archive --format=zip HEAD > `date +%s`.zip
```



## 9.2 查询代码最后修改人

```bash
git blame xxx
```



## 9.3 分支关系图

```bash
git show-branch
```



## 9.4 拆分或合并仓库

```bash
git subtree
```

















































