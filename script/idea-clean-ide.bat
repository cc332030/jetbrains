@echo off

title clean ide

echo.
set /p dir=请选择目录：
cls

if not exist "%dir%" (
  echo.
  echo 不存在文件夹 "%dir%"
  pause >nul
  exit 0
)

echo.
echo 即将关闭 idea 及所有 java 程序！
pause

cls
echo.
echo 请勿关闭，清理完将自动退出！

taskkill /f /im idea.exe 2>nul
taskkill /f /im idea64.exe 2>nul
taskkill /f /im java.exe 2>nul

cd /d %dir%

rd /s /q log

cd config
rd /s /q ^
  tasks ^
  workspace

cd ../system
rd /s /q ^
  caches ^
  compiler ^
  compile-server ^
  conversion ^
  database-log ^
  event-log-data ^
  external_build_system ^
  frameworks ^
  index ^
  LocalHistory ^
  Maven ^
  projects ^
  projectModelCache ^
  recommenders-java ^
  stat ^
  terminal ^
  testHistory ^
  tmp ^
  tomcat ^
  vcs ^
  vcsCache ^
  vcs-log ^
  vcs-users ^
  workspace

del /f /s /q ^
  .pid ^
  .home
