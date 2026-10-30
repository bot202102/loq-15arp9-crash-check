@echo off
chcp 65001 >nul
echo Optional active test, about 23 minutes, MAY CRASH an affected PC. Read README first.
echo Prueba activa opcional, unos 23 minutos, PUEDE COLGAR un equipo afectado. Lee el README antes.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0loq-vmin-test.ps1"
echo.
echo If the PC crashed during the test: log in and run  loq-vmin-test.ps1 -Report
echo Si el equipo se colgo durante la prueba: inicia sesion y ejecuta  loq-vmin-test.ps1 -Report
pause
