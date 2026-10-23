@echo off
chcp 65001 >nul
setlocal
title enable tlsv1 for idea jbr

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%idea-enable-tlsv1.ps1"

if not exist "%PS1%" (
  echo.
  echo 找不到 %PS1%
  echo.
  pause
  exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo 需要管理员权限（IDEA 可能安装在 Program Files 下），正在提权重启...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
  exit /b
)

if "%~1"=="" (
  echo.
  echo 即将为当前运行中的 IDEA 自带 JBR 启用 TLSv1 / TLSv1.1
  echo 脚本会自动扫描 IDEA 进程定位 JBR，并在修改前备份 java.security
  echo 仅想看看会改什么，请先执行:  idea-enable-tlsv1.bat -DryRun
  echo.
  pause
)

cls
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

echo.
pause
