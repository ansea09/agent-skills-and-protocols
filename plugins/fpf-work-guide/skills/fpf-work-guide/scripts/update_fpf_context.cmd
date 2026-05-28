@echo off
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update_fpf_context.ps1" %*
exit /b %ERRORLEVEL%
