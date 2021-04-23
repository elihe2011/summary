# 1. 修改后缀名 (Windows)

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



# 2. C盘数据搬迁

先将Chrome下的数据剪切到D盘，然后建立软连接

```bash
echo off
mklink /d "C:\Users\Administrator\AppData\Local\Google\Chrome\User Data" "D:\Program Files\Chrome\User Data"
mklink /d "C:\Users\Administrator\AppData\Local\Google\Chrome\Application" "D:\Program Files\Chrome\Application"
explorer "C:\Users\Administrator\AppData\Local\Google\Chrome"
echo The 'Administrator' in this file needs to be modified for the current user
pause
```



# 3. 网络刷新

```bash
# 释放现有IP
ipconfig /release
ipconfig /release *Adapter*   # Vmware

# 向DHCP服务器发IP租用请求
ipconfig /renew

# 清除 dns 缓存
ipconfig /flushdns
```

