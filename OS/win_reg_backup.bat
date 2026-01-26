@echo off

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set NOW=%%i

set BACKUP_DIR=%USERPROFILE%\Desktop\RegistryBackup\%NOW%
mkdir "%BACKUP_DIR%"

echo Backing up registry to: 
echo %BACKUP_DIR%
echo.

echo Processing HKCR... 
reg export HKCR "%BACKUP_DIR%\HKCR.reg" /y
echo.

echo Processing HKCU... 
reg export HKCU "%BACKUP_DIR%\HKCU.reg" /y
echo.

echo Processing HKLM... 
reg export HKLM "%BACKUP_DIR%\HKLM.reg" /y
echo.

echo Processing HKU... 
reg export HKU  "%BACKUP_DIR%\HKU.reg"  /y
echo.

echo Processing HKCC... 
reg export HKCC "%BACKUP_DIR%\HKCC.reg" /y
echo.

echo Registry backup completed.
pause