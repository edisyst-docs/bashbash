@echo off
setlocal

echo === Pulizia workspace temporaneo ===

REM Modifica il path in base alle tue cartelle di temp / cache
del /Q /S C:\Temp\*.*
del /Q /S C:\Windows\Temp\*.*

echo === Pulizia completata! ===
pause
