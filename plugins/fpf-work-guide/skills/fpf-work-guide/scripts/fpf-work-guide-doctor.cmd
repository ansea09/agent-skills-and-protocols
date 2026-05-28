@echo off
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%fpf-work-guide-doctor.ps1" %*
exit /b %ERRORLEVEL%
