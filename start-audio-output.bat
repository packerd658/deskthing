@echo off
rem Starts the Desk Thing audio output helper in the background.
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0audio-output-server.ps1"
