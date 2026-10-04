@echo off
:MENU
cls
echo =============================
echo         MENU UTILITA'
echo =============================
echo 1. Clonare progetto Laravel
echo 2. Backup progetto
echo 3. Pulizia workspace
echo 4. Esci
echo.
set /p scelta=Inserisci scelta [1-4]:

if "%scelta%"=="1" call clone_laravel.bat
if "%scelta%"=="2" call backup_progetto.bat
if "%scelta%"=="3" call pulizia_workspace.bat
if "%scelta%"=="4" exit

goto MENU
