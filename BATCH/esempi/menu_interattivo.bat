@echo off
:MENU
cls
echo =============================
echo        MENU PRINCIPALE
echo =============================
echo 1. Clonare repo Laravel
echo 2. Fare backup progetto
echo 3. Pulire file temporanei
echo 4. Uscire
echo.
set /p scelta=Inserisci scelta [1-4]:

if "%scelta%"=="1" goto CLONA
if "%scelta%"=="2" goto BACKUP
if "%scelta%"=="3" goto PULIZIA
if "%scelta%"=="4" exit

goto MENU

:CLONA
echo Clono repo...
REM qui metti il codice per clonare
pause
goto MENU

:BACKUP
echo Backup in corso...
REM qui metti il codice di backup
pause
goto MENU

:PULIZIA
echo Pulizia in corso...
REM qui metti il codice di pulizia
pause
goto MENU
