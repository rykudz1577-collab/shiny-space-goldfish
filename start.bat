@echo off
rem Antares Launcher - portable (can Python 3.11+)
cd /d "%~dp0"
where python >nul 2>nul || (echo Python not found in PATH & pause & exit /b 1)
python -m app.main %*
if errorlevel 1 pause
