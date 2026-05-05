@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0generate-win.ps1" %*
pause
