@echo off
setlocal
cd /d "%~dp0"

rem EUDA canonical launcher - copy verbatim, do not edit.
rem Finds uv, installs it if missing (no admin needed), then runs the app.
set "UV=uv"
where uv >nul 2>nul && goto :run
if exist "%USERPROFILE%\.local\bin\uv.exe" set "UV=%USERPROFILE%\.local\bin\uv.exe" && goto :run
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" set "UV=%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" && goto :run

echo uv is not installed - installing now (one-time, no admin needed)...
winget install --id=astral-sh.uv -e --silent --accept-source-agreements --accept-package-agreements
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" set "UV=%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe" && goto :run
where uv >nul 2>nul && goto :run

echo winget install did not succeed - trying the official installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
if exist "%USERPROFILE%\.local\bin\uv.exe" set "UV=%USERPROFILE%\.local\bin\uv.exe" && goto :run

echo Could not install uv automatically. Ask IT to install "uv" from the software catalog.
pause
exit /b 1

:run
"%UV%" run app.py
if %ERRORLEVEL% neq 10 exit /b %ERRORLEVEL%

rem Exit code 10 means the app staged an update and asked to be restarted.
rem The launcher does the swap because nothing is reading app.py right now.
if defined EUDA_UPDATED (
  echo Update was already applied once this launch - not repeating.
  exit /b 0
)
set "EUDA_UPDATED=1"
if not exist "app.py.staged" (
  echo No staged update found - nothing to apply.
  exit /b 0
)
if exist "app.py.bak" del "app.py.bak"
move /y "app.py" "app.py.bak" >nul
move /y "app.py.staged" "app.py" >nul
echo Update applied. Restarting...
goto :run
