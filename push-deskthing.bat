@echo off
cd /d "%~dp0"
adb devices
echo Sending the Desk Thing to the Pixel...
adb push pear-deskthing.html /sdcard/Android/data/de.ozerov.fully/files/
echo Restarting Fully Kiosk...
adb shell am force-stop de.ozerov.fully
adb shell monkey -p de.ozerov.fully -c android.intent.category.LAUNCHER 1 >nul
echo.
echo Done. The Desk Thing should reopen on the Pixel in a few seconds.
pause
