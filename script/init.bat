@echo off

call link-dir %~dp0project %userprofile%\IdeaProjects

call link-dir %~dp0cache %userprofile%\AppData\Local\JetBrains
call link-dir %~dp0data %userprofile%\AppData\Roaming\JetBrains

pause