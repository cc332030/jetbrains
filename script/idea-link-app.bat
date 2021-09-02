@echo off

echo.
set /p idea_home=请输入 idea 地址：

echo.

set local=%~dp0

set local_app=%local%app
set local_data=%local%data

set idea_app=%idea_home%\app
set idea_data=%idea_home%\data

if not exist %idea_app% (
  echo.
  echo 不存在文件 %idea_app%
  pause >nul
  exit 0
)

if not exist %idea_data% (
  mkdir %idea_data%
)

rd /q %local_app% >nul 2>&1
rd /q %local_data% >nul 2>&1

mklink /h /j %local_app% %idea_app%
mklink /h /j %local_data% %idea_data%

pause >nul
