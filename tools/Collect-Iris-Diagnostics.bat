@echo off
setlocal
set "SCRIPT=%~dp0collect_iris_diagnostics.py"
py -3 "%SCRIPT%" %*
if errorlevel 1 (
  echo.
  echo If Python is installed but the py command is unavailable, run:
  echo python "%SCRIPT%"
  pause
  exit /b 1
)
echo.
pause
