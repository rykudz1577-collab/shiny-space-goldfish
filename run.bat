@echo off
REM ============================================================
REM Antares Launcher 1.0 — chạy trực tiếp từ source (Windows)
REM
REM Lần đầu: tự tạo venv + cài dependencies (cần internet).
REM Các lần sau: chạy luôn.
REM
REM   run.bat            -> GUI (cửa sổ launcher)
REM   run.bat --headless -> khong cua so (kiem tra boot)
REM   run.bat --dev      -> dev mode (verbose log + devtools)
REM ============================================================
setlocal
cd /d "%~dp0"

set VENV=%~dp0.venv
set PY=python

where python >nul 2>nul || (
  echo [Loi] Khong tim thay Python. Cai Python 3.11+ tu python.org
  echo       Nho tick "Add Python to PATH" khi cai.
  pause
  exit /b 1
)

REM 1. Venv
if not exist "%VENV%\Scripts\python.exe" (
  echo ==^> [1/2] Tao moi truong ao (lan dau)...
  %PY% -m venv "%VENV%" || (echo [Loi] Tao venv that bai & pause & exit /b 1)
  "%VENV%\Scripts\python.exe" -m pip install --upgrade pip --quiet
  echo ==^> Cai dependencies (mot lan duy nhat)...
  "%VENV%\Scripts\python.exe" -m pip install --quiet -r requirements.txt || (
    echo [Loi] Cai dependencies that bai - kiem tra internet & pause & exit /b 1)
)

REM 2. Chay
echo ==^> Khoi dong Antares Launcher...
"%VENV%\Scripts\python.exe" -m app.main %*
if errorlevel 1 pause
