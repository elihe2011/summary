# 1. 安装

推荐普通用户权限下操作

```powershell
# 开启权限
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 指定 scoop 安装路径 (默认C:\Users\<username>\scoop)
$env:SCOOP='D:\dev\scoop'
$env:SCOOP_GLOBAL='D:\dev\scoop\global'
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
irm get.scoop.sh | iex  # 简写

# 永久环境变量
[Environment]::SetEnvironmentVariable("SCOOP","D:\dev\scoop","User")
[Environment]::SetEnvironmentVariable("SCOOP_GLOBAL","D:\dev\scoop\global","User")

# 使用帮助
scoop help

# 更新
scoop update
```



# 2. 库管理

**全局代理**：

```powershell
# 添加代理
scoop config proxy 127.0.0.1:7890

# 删除代理
scoop config rm proxy
```



**添加软件仓库**：国内bucket镜像站 https://gitee.com/scoop-installer

```powershell
# 添加 extras 仓库 (含大量GUI程序)
scoop bucket add extras
scoop bucket add extras https://gitee.com/scoop-bucket/extras.git  # 国内镜像

# 已添加的仓库
scoop bucket list

# 删除仓库
scoop rm extras

# 官方推荐的仓库
scoop bucket known
```



# 3. 程序管理

```powershell
# 安装
scoop install <app_name>

# 已安装的程序
scoop list

# 搜索
scoop search <app_name>

# 卸载
scoop uninstall <app_name>

# 查看更新
scoop status

# 删除旧版本
scoop cleanup

# 自身诊断
scoop checkup
```



# 4. 多版本管理

```powershell
# 安装多个版本
scoop install nodejs@18
scoop install nodejs@20

# 安装后的目录
~/scoop/apps/nodejs/
 ├─ 18.x.x
 ├─ 20.x.x
 └─ current -> 20.x.x
 
# 切换版本
scoop reset nodejs@20
```





# 5. 常用程序

## 5.1 aria2

```powershell
# 安装
scoop install aria2

# aria2 在 Scoop 中默认开启
scoop config aria2-enabled true

# 关于以下参数的作用，详见aria2的相关资料
scoop config aria2-retry-wait 4
scoop config aria2-split 16
scoop config aria2-max-connection-per-server 16
scoop config aria2-min-split-size 4M
```



## 5.2 nvm

```powershell
# 安装 nvm
scoop install nvm

# 安装 nodejs
nvm install 22
nvm use 22

# 验证
node --version
npm --version
```

