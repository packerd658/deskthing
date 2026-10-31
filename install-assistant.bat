@echo off
cd /d "%~dp0"
echo Installing the Desk Thing assistant and TruckNav voice...
if not exist "%APPDATA%\TruckNav\maps" ( echo TruckNav maps folder not found. Open TruckNav and download the ATS map first. & pause & exit /b 1 )
copy /Y "navvoice.html" "%APPDATA%\TruckNav\maps\navvoice.html" >nul && echo  - voice page added to TruckNav
echo Restarting the PC helper (voice + microphone assistant)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-audio-helper.ps1"
call "%~dp0start-audio-output.bat"
echo Sending the updated Desk Thing to the Pixel 4 XL...
call "%~dp0push-deskthing.bat"
