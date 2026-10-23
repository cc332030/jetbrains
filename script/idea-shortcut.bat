@ECHO OFF & PUSHD %~DP0
>NUL 2>&1 REG.exe query "HKU\S-1-5-19" || (
    ECHO SET UAC = CreateObject^("Shell.Application"^) > "%TEMP%\Getadmin.vbs"
    ECHO UAC.ShellExecute "%~f0", "%1", "", "runas", 1 >> "%TEMP%\Getadmin.vbs"
    "%TEMP%\Getadmin.vbs"
    DEL /f /q "%TEMP%\Getadmin.vbs" 2>NUL
    Exit /b
)
chcp 65001 >NUL
TITLE IDEA 右键菜单 - 添加

echo.
echo ======== 为「最新版本」的 IntelliJ IDEA 添加右键菜单 ========
echo.

call "%~dp0idea-detect.bat"
if errorlevel 1 goto :NoIdea

echo.
echo 正在写入注册表 ...
set "ERR="
call :AddKey "HKEY_CLASSES_ROOT\*\shell\IDEA"
call :AddKey "HKEY_CLASSES_ROOT\Directory\shell\IDEA"

echo.
if defined ERR (
    echo [失败] 写入注册表出错，请用管理员身份重新运行本脚本。
    goto :End
)
echo [完成] 右键菜单已添加，菜单名 "IDEA"，指向：
echo        %IDEA_EXE%
echo        在「文件」或「文件夹」上点右键即可看到。
echo        删除该菜单请运行同目录下的 idea-shortcut-remove.bat

:End
echo.
if /I not "%~1"=="/y" pause
popd
exit /b

:NoIdea
echo.
echo [失败] 未能定位 IDEA 安装目录，注册表未做任何修改。
echo.
echo 请手动指定安装根目录后重试，例如：
echo     %~nx0 "D:\JetBrains\IntelliJ IDEA 2026.2.3"
echo.
if /I not "%~1"=="/y" pause
popd
exit /b


rem ---------- 写入一组 shell 键（文件 / 文件夹通用） ----------
:AddKey
reg add "%~1" /ve /t REG_SZ /d "IDEA" /f >NUL 2>&1 || set "ERR=1"
reg add "%~1" /t REG_EXPAND_SZ /v "Icon" /d "\"%IDEA_EXE%\"" /f >NUL 2>&1 || set "ERR=1"
reg add "%~1\command" /t REG_SZ /v "" /d "\"%IDEA_EXE%\" \"%%1\"" /f >NUL 2>&1 || set "ERR=1"
goto :eof
