# 1. Powershell 问题

activate.ps1 cannot be loaded because running scripts is disabled on this system. For more information, see about_Ex ecution_Policies at https:/go.microsoft.com/fwlink/?LinkID=135170.

```bash
PS C:\> Get-ExecutionPolicy -List
        Scope ExecutionPolicy
        ----- ---------------
MachinePolicy       Undefined
   UserPolicy       Undefined
      Process    Unrestricted
  CurrentUser       Undefined
 LocalMachine      Restricted
 
PS C:\> Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose
you to the security risks described in the about_Execution_Policies help topic at
https:/go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): A
```



# 2. msys2

https://www.msys2.org/wiki/MSYS2-installation/

安装后，使用 `MSYS MinGW x64`

| 命令                  | 解释                                                         |
| --------------------- | ------------------------------------------------------------ |
| `pacman -Syu`         | 升级系统及所有已经安装的软件                                 |
| `pacman -S 软件名`    | 安装软件。也可以同时安装多个包，只需以空格分隔包名即可       |
| `pacman -Rs 软件名`   | 删除软件，同时删除本机上只有该软件依赖的软件。               |
| `pacman -Ru 软件名`   | 删除软件，同时删除不再被任何软件所需要的依赖。               |
| `pacman -Ssq 关键字`  | 在仓库中搜索含关键字的软件包，并用简洁方式显示。             |
| `pacman -Qs 关键字`   | 搜索已安装的软件包。                                         |
| `pacman -Qi 软件名`   | 查看某个软件包信息，显示软件简介,构架,依赖,大小等详细信息。  |
| `pacman -Sg`          | 列出软件仓库上所有的软件包组。                               |
| `pacman -Sg 软件包组` | 查看某软件包组所包含的所有软件包。                           |
| `pacman -Sc`          | 清理未安装的包文件，包文件位于 /var/cache/pacman/pkg/ 目录。 |
| `pacman -Scc`         | 清理所有的缓存文件。                                         |


```bash
# 更新本地软件包
pacman -Sy

# 查询并找到msys/gcc
pacman -Ss gcc
pacman -S msys/gcc

# 查询并找到msys/make
pacman -Ss make
pacman -S msys/make


# The GCC compiler suite and the development libraries needed for cgo can be installed with just one command:
pacman -S --needed base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
```



# 3. 英文系统

部分软件字符乱码

Settings -> Time&Language -> Region: 

- Country or region => China

-  Additional date, time, & reginal settings -> Region
  - Formats: Format => Chinese xxx
  - Administrative -> Change system locale:  Current system locale => Chinese xxx (NOT chose Beta box)
- Restart



# 4. 修改后缀名

```bash
@echo off
 
set DIR=%~dp0
set ROOT=%DIR%
 
for /f "delims=" %%f in ('dir  /b/a-d/s  %ROOT%\*.cnt') do (
	echo %%f
	ren %%f *.jpg
)

pause
```



# 5. C盘数据搬迁

先将Chrome下的数据剪切到D盘，然后建立软连接

```bash
echo off
mklink /d "C:\Users\Administrator\AppData\Local\Google\Chrome\User Data" "D:\Program Files\Chrome\User Data"
mklink /d "C:\Users\Administrator\AppData\Local\Google\Chrome\Application" "D:\Program Files\Chrome\Application"
explorer "C:\Users\Administrator\AppData\Local\Google\Chrome"
echo The 'Administrator' in this file needs to be modified for the current user
pause
```



# 6. 网络刷新

```bash
# 释放现有IP
ipconfig /release
ipconfig /release *Adapter*   # Vmware

# 向DHCP服务器发IP租用请求
ipconfig /renew

# 清除 dns 缓存
ipconfig /flushdns
```



# 7. 用户

```bash
# 当前用户SID
> whoami /user
User Name             SID
===================== =============================================
desktop-e17bd19\elihe S-1-5-21-2570433964-3893667463-618210156-1001

# 当前系统所有用户的SID
> wmic useraccount get name,sid
Name                SID
Administrator       S-1-5-21-2570433964-3893667463-618210156-500
DefaultAccount      S-1-5-21-2570433964-3893667463-618210156-503
elihe               S-1-5-21-2570433964-3893667463-618210156-1001
Guest               S-1-5-21-2570433964-3893667463-618210156-501
WDAGUtilityAccount  S-1-5-21-2570433964-3893667463-618210156-504
```



# 8. Postman

页面刷新不出来解决方法：**删除%appdata%目录下的Postman文件**，然后重新打开Postman重新登录
