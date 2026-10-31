@echo off
cd /d "%~dp0"
echo Reading the current Windows audio output...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0audio-output-server.ps1" -Once
echo.
echo Done. Saved audio-output-test.txt
pause
