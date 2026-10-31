@echo off
set "PS1=%~dp0voice-sample.ps1"
if not exist "%PS1%" set "PS1=%~dp0DeskThing-voice\voice-sample.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
pause
