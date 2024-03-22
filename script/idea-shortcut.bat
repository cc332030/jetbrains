@ECHO OFF & PUSHD %~DP0 & TITLE
>NUL 2>&1 REG.exe query "HKU\S-1-5-19" || (
    ECHO SET UAC = CreateObject^("Shell.Application"^) > "%TEMP%\Getadmin.vbs"
    ECHO UAC.ShellExecute "%~f0", "%1", "", "runas", 1 >> "%TEMP%\Getadmin.vbs"
    "%TEMP%\Getadmin.vbs"
    DEL /f /q "%TEMP%\Getadmin.vbs" 2>NUL
    Exit /b
)

echo.
set /p idea_home=请输入 idea 地址：

set exePath=%idea_home%\bin\idea64.exe

echo.
SET /P ST=输入 1 添加右键菜单，输入 2 删除右键菜单：
if /I "%ST%"=="1" goto Add
if /I "%ST%"=="2" goto Remove
:Add
reg add "HKEY_CLASSES_ROOT\*\shell\IDEA"         /t REG_SZ /v "" /d "IDEA"   /f
reg add "HKEY_CLASSES_ROOT\*\shell\IDEA"         /t REG_EXPAND_SZ /v "Icon" /d "%exePath%" /f
reg add "HKEY_CLASSES_ROOT\*\shell\IDEA\command" /t REG_SZ /v "" /d "%exePath% \"%%1\"" /f

reg add "HKEY_CLASSES_ROOT\Directory\shell\IDEA"         /t REG_SZ /v "" /d "IDEA"   /f
reg add "HKEY_CLASSES_ROOT\Directory\shell\IDEA"         /t REG_EXPAND_SZ /v "Icon" /d "%exePath%" /f
reg add "HKEY_CLASSES_ROOT\Directory\shell\IDEA\command" /t REG_SZ /v "" /d "%exePath% \"%%1\"" /f

exit
:Remove
reg delete "HKEY_CLASSES_ROOT\*\shell\IDEA" /f
reg delete "HKEY_CLASSES_ROOT\Directory\shell\IDEA" /f
exit
