@echo off

:: 注意: 文件编码必须是 ANSI，否则可能失效
echo Fucking BaiduNetdisk...
echo.

echo [1/7] Delete HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\YunShellExt
reg delete HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\YunShellExt /f >nul 2>nul

echo [2/7] Delete HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\YunShellExt
reg delete HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\YunShellExt /f >nul 2>nul

echo [3/7] Delete HKEY_CLASSES_ROOT\BaiduNetdiskImageViewerAssociations
:: taskkill /f /im BaiduNetdisk.exe >nul 2>nul
reg delete "HKEY_CLASSES_ROOT\BaiduNetdiskImageViewerAssociations" /f >nul 2>nul

echo [4/7] Delete HKEY_CURRENT_USER\Software\Baidu\BaiduNetdiskImageViewer
reg delete "HKEY_CURRENT_USER\Software\Baidu\BaiduNetdiskImageViewer" /f >nul 2>nul

echo [5/7] Delete HKEY_CURRENT_USER\Software\RegisteredApplications\BaiduNetdiskImageViewer
reg delete "HKEY_CURRENT_USER\Software\RegisteredApplications" /v "BaiduNetdiskImageViewer" /f >nul 2>nul

set "imageviewer_path=%APPDATA%\baidu\BaiduNetdisk\module\ImageViewer"
echo [6/7] Delete "%imageviewer_path%"
if exist "%imageviewer_path%" (
    rmdir /s /q "%imageviewer_path%" >nul 2>&1
)

set "installDir="
for %%L in (
    "%APPDATA%\Microsoft\Windows\Start Menu\Programs\百度网盘\百度网盘.lnk"
    "%PUBLIC%\Desktop\百度网盘.lnk"
    "%USERPROFILE%\Desktop\百度网盘.lnk"
) do (
    if not defined installDir (
        for /f "usebackq delims=" %%I in (`
            powershell -NoLogo -NoProfile -Command ^
                "(New-Object -COM WScript.Shell).CreateShortcut('%%L').TargetPath" 2^>nul
        `) do (
            set "installDir=%%~dpI"
        )
    )
)
echo [7/7] Delete "%installDir%\module\ImageViewer"
if defined installDir (
  rd /s /q "%installDir%\module\ImageViewer" 2>nul
)

echo.
echo Fuck Done!
pause
