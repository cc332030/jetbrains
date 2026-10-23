@ECHO OFF & PUSHD %~DP0
>NUL 2>&1 REG.exe query "HKU\S-1-5-19" || (
    ECHO SET UAC = CreateObject^("Shell.Application"^) > "%TEMP%\Getadmin.vbs"
    ECHO UAC.ShellExecute "%~f0", "%1", "", "runas", 1 >> "%TEMP%\Getadmin.vbs"
    "%TEMP%\Getadmin.vbs"
    DEL /f /q "%TEMP%\Getadmin.vbs" 2>NUL
    Exit /b
)
chcp 65001 >NUL
TITLE IDEA 右键菜单 - 删除

echo.
echo ================ 删除 IntelliJ IDEA 右键菜单 ================
echo.

set "N=0"
reg delete "HKEY_CLASSES_ROOT\*\shell\IDEA" /f >NUL 2>&1 && set /a N+=1 >NUL
reg delete "HKEY_CLASSES_ROOT\Directory\shell\IDEA" /f >NUL 2>&1 && set /a N+=1 >NUL

echo.
if "%N%"=="0" (
    echo [跳过] 没有发现 "IDEA" 右键菜单项，无需删除。
) else (
    echo [完成] 已删除 %N% 处右键菜单项（文件 / 文件夹）。
)
echo.
if /I not "%~1"=="/y" pause
popd
exit /b
