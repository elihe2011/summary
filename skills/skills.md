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

