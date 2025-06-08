@echo off
setlocal

REM Configura il path del progetto
set SRC=C:\miei_progetti\progetto1
set DEST=C:\backup\progetto1_backup_%date:~6,4%-%date:~3,2%-%date:~0,2%

echo === Backup di %SRC% in %DEST% ===

xcopy %SRC% %DEST% /E /H /C /I /Y

echo === Backup completato! ===
pause
