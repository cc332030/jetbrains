@echo off

set source="%~dp0data"
set target="%userprofile%\AppData\Roaming\JetBrains"

if not defined source (
  echo.
  set /p source=请输入源目录：
)

if not defined target (
  echo.
  set /p target=请输入目标目录：
)

if not exist %source% (
  echo.
  echo 文件夹不存在 %source%
  pause >nul
  exit 0
)

:: 创建父级目录
if not exist %target% (
  mkdir %target%
)
rd /s /q %target%

echo.
mklink /d %target% %source%

pause >nul
