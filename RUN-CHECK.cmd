@echo off
chcp 65001 >nul
echo Read-only check (changes nothing) / Revision de solo lectura (no cambia nada)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0loq-crash-signature.ps1"
echo.
echo Report saved next to this file (loq-report-*.md). Please paste it in a GitHub issue.
echo Reporte guardado junto a este archivo (loq-report-*.md). Pegalo en un issue de GitHub.
pause
