@echo off
REM Questo è un commento
:: Anche questo è un commento

set AMMINISTRATORE_NOME=Mario
echo Il capo qui si chiama %AMMINISTRATORE_NOME%

echo Premi un tasto per andare avanti ogni volta

pause

set /p NOME=Tu come ti chiami? 
echo Ciao %NOME%!

pause

if "%NOME%"=="%AMMINISTRATORE_NOME%" (
    echo Sei l'amministratore.
) else (
    echo Utente normale.
)

pause

echo Elenco file della cartella corrente:
dir

pause

for %%F in (*.txt) do echo Trovato file di testo: %%F

pause
