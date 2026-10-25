@echo off
set "PATH=C:\Users\RCS\Downloads\node-v24.21.0-win-x64\node-v24.21.0-win-x64;%PATH%"
cd /d "%~dp0"
powershell.exe -NoProfile -STA -File "%~dp0widget.ps1"
if errorlevel 1 pause
