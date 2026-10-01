@echo off
rem Antares Launcher - cai dat + chay (tu source)
setlocal
cd /d "%~dp0"
where python >nul 2>nul || (echo [LOI] Khong tim thay Python. Cai Python 3.11+ & pause & exit /b 1)
python -m pip install --quiet --user "minecraft-launcher-lib>=8.0" "httpx>=0.27" "psutil>=5.9" "pywebview>=5.0"
python -m app.main --diagnose
python -m app.main %*
if errorlevel 1 pause
