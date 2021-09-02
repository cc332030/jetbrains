@echo off

title clean workspace

:start
echo.
set /p dir=请选择目录：
cls

cd /d %dir%
rd /s /q .idea
del /f /s /q *.iml

goto start
