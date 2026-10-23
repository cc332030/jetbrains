@echo off
chcp 65001 >NUL
rem =====================================================================
rem  idea-detect.bat   公共脚本：扫描本机「最新版本」的 IntelliJ IDEA
rem
rem  在其它脚本里这样调用（变量会直接返回到调用者的环境里）：
rem      call "%~dp0idea-detect.bat"                        自动扫描
rem      call "%~dp0idea-detect.bat" "D:\JetBrains\IDEA"   手动指定安装根目录
rem
rem  返回变量：
rem      IDEA_HOME   安装根目录（含 bin 的那一层）
rem      IDEA_EXE    启动文件完整路径（...\bin\idea64.exe）
rem      IDEA_VER    版本号，如 2026.2.3
rem      IDEA_BUILD  内部构建号，如 IU-262.10968.63
rem  返回码：
rem      0 = 找到    1 = 未找到
rem
rem  扫描位置：%LOCALAPPDATA%\Programs、Toolbox 安装目录、
rem            %ProgramFiles%\JetBrains、%ProgramFiles(x86)%\JetBrains
rem  排序依据：build.txt 里的构建号，取最大者（= 最新版本）
rem =====================================================================

set "IDEA_HOME="
set "IDEA_EXE="
set "IDEA_VER="
set "IDEA_BUILD="
set "IDEA_EXE_NAME="
set "IDEA_KEY=V000000000000000000"

rem ---------- 0. 有传参就用手动指定的目录 ----------
if not "%~1"=="" goto :UseManual

rem ---------- 1. 扫描常见安装位置 ----------
call :ScanRoot "%LOCALAPPDATA%\Programs"
call :ScanRoot "%LOCALAPPDATA%\JetBrains\Toolbox\apps"
call :ScanRoot "%APPDATA%\JetBrains\Toolbox\apps"
call :ScanRoot "%ProgramFiles%\JetBrains"
call :ScanRoot "%ProgramFiles(x86)%\JetBrains"

rem 额外扫描目录（比如装在 D 盘时，设置环境变量 IDEA_SCAN_ROOT=D:\JetBrains）
if defined IDEA_SCAN_ROOT call :ScanRoot "%IDEA_SCAN_ROOT%"

rem ---------- 2. 兜底：脚本本身被放进了 IDEA 安装目录 ----------
if not defined IDEA_EXE call :ProbeExe "%~dp0..\bin\idea64.exe"
if not defined IDEA_EXE call :ProbeExe "%~dp0bin\idea64.exe"
goto :Report

:UseManual
call :ProbeExe "%~1\bin\idea64.exe"
if not defined IDEA_EXE call :ProbeExe "%~1\bin\idea.exe"
if not defined IDEA_EXE call :ProbeExe "%~1"

:Report
if not defined IDEA_EXE goto :NotFound
call :Norm
echo   IDEA 版本 : %IDEA_VER%  [%IDEA_BUILD%]
echo   安装路径 : %IDEA_HOME%
echo   启动文件 : %IDEA_EXE%
exit /b 0

:NotFound
echo   [错误] 没有找到 IntelliJ IDEA 的安装目录。
echo          可以手动指定后重试，例如：
echo            "%~nx0" "D:\JetBrains\IntelliJ IDEA 2026.2.3"
exit /b 1


rem =====================================================================
rem  以下为内部子过程
rem =====================================================================

rem ---------- 扫描某个父目录下的所有 idea64.exe ----------
:ScanRoot
if not exist "%~1" goto :eof
for /f "delims=" %%f in ('dir /s /b /a-d "%~1\idea64.exe" 2^>nul') do call :ProbeExe "%%~f"
goto :eof

rem ---------- 检查一个 exe，比当前记录新就替换 ----------
:ProbeExe
if not exist "%~1" goto :eof
set "P_EXE=%~1"
set "P_NAME=%~nx1"
for %%a in ("%P_EXE%") do set "P_BIN=%%~dpa"
set "P_BIN=%P_BIN:~0,-1%"
for %%a in ("%P_BIN%") do set "P_HOME=%%~dpa"
set "P_HOME=%P_HOME:~0,-1%"
call :KeyOf
if not defined IDEA_EXE goto :Accept
if "%P_KEY%" GTR "%IDEA_KEY%" goto :Accept
goto :eof
:Accept
set "IDEA_KEY=%P_KEY%"
set "IDEA_EXE=%P_EXE%"
set "IDEA_EXE_NAME=%P_NAME%"
set "IDEA_HOME=%P_HOME%"
set "IDEA_VER=%P_VER%"
set "IDEA_BUILD=%P_BUILD%"
goto :eof

rem ---------- 读取 build.txt，算出可比较的版本键 ----------
rem  键格式：V + 6位主版本 + 6位构建号 + 6位补丁号
rem  例：IU-262.10968.63  ->  V000262010968000063
:KeyOf
set "P_KEY=V000000000000000000"
set "P_BUILD=未知"
set "P_VER="
set "NUMB="
if not exist "%P_HOME%\build.txt" goto :GoVer
set "B="
for /f "usebackq delims=" %%v in ("%P_HOME%\build.txt") do if not defined B set "B=%%v"
if not defined B goto :GoVer
set "P_BUILD=%B%"
for /f "tokens=1,2 delims=-" %%x in ("%B%") do if not "%%y"=="" set "B=%%y"
set "NUMB=%B%"
for /f "tokens=1,2,3 delims=." %%x in ("%B%") do call :SetSegs "%%x" "%%y" "%%z"
:GoVer
call :ReadVer
goto :eof

:SetSegs
call :Pad6 %~1
set "S1=%PAD%"
call :Pad6 %~2
set "S2=%PAD%"
call :Pad6 %~3
set "S3=%PAD%"
set "P_KEY=V%S1%%S2%%S3%"
goto :eof

:Pad6
set "PAD=000000%~1"
set "PAD=%PAD:~-6%"
goto :eof

rem ---------- 取人类可读的版本号：优先 product-info.json ----------
:ReadVer
set "V="
if not exist "%P_HOME%\product-info.json" goto :ReadVerBack
for /f "delims=" %%v in ('findstr /i /c:"\"version\"" "%P_HOME%\product-info.json" 2^>nul') do if not defined V set "V=%%v"
if not defined V goto :ReadVerBack
set V=%V: =%
set V=%V:"=%
set V=%V:,=%
for /f "tokens=2 delims=:" %%x in ("%V%") do set "V=%%x"
if not defined V goto :ReadVerBack
set "P_VER=%V%"
goto :eof

:ReadVerBack
if defined NUMB set "P_VER=20%NUMB:~0,2%.%NUMB:~2,1%"
goto :eof

rem ---------- 规范化安装目录路径（去掉 .. 之类） ----------
:Norm
if not exist "%IDEA_HOME%" goto :eof
pushd "%IDEA_HOME%" 2>NUL || goto :eof
set "IDEA_HOME=%CD%"
popd
if exist "%IDEA_HOME%\bin\idea64.exe" set "IDEA_EXE=%IDEA_HOME%\bin\idea64.exe"
if not exist "%IDEA_HOME%\bin\idea64.exe" if exist "%IDEA_HOME%\bin\idea.exe" set "IDEA_EXE=%IDEA_HOME%\bin\idea.exe"
if not defined IDEA_VER set "IDEA_VER=未识别"
goto :eof
