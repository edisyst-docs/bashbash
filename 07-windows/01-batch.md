Un file batch è un semplice file di testo con estensione .bat o .cmd che contiene comandi  
da eseguire in sequenza tramite il prompt di comando di Windows (cmd.exe).
È come uno "script" per automatizzare operazioni.

# Consigli pratici
✅ Usa sempre @echo off all’inizio per rendere l’output più pulito
✅ Quando provi cicli for da prompt singolo, ricordati che usi %F e non %%F
✅ Puoi concatenare comandi con &&
✅ Puoi rendere i tuoi batch interattivi con set /p

# Struttura base
```batch    
@echo off
REM Commento

:: Altro commento
echo Ciao Mondo
pause
```

## Variabili
```batch    
set VAR=Valore
echo %VAR%
```

## Parametri negli script
```batch    
mioscript.bat parametro1 parametro2

REM All'interno di mioscript.bat
echo Primo parametro: %1
echo Secondo parametro: %2
```

## Input utente
```batch    
set /p NOME=Inserisci nome:
echo %NOME%
```

## Condizioni (if)
```batch    
if "%NOME%"=="Mario" echo Sei Mario!
if not "%NOME%"=="Mario" echo Non sei Mario!
```

## Goto e label
```batch    
goto INIZIO

:INIZIO
echo Siamo all'inizio
```

## Ciclo for
```batch    
for %%F in (*.txt) do echo File trovato: %%F
```

## Eseguire un altro script o comando
```batch    
call prova.bat
```

## Operazioni sui file/cartelle
```batch    
mkdir nuova_cartella
copy file.txt nuova_cartella\
del file.txt
rmdir nuova_cartella
```

## Delay / sleep (senza tool esterni, con ping "fake")
```batch    
ping 127.0.0.1 -n 6 > nul
REM aspetta circa 5 secondi (il ping parte da 1), posso simulare uno sleep
```

## Uscire dallo script
```batch    
exit /b
```

### Esempio completo
```batch        
@echo off
set /p NOME=Inserisci il tuo nome:
if "%NOME%"=="Mario" (
    echo Ciao Mario!
) else (
    echo Ciao %NOME%!
)
echo Inizio ciclo for:
for %%F in (*.txt) do (
    echo File trovato: %%F
)
echo Fine dello script.
pause
exit /b
```


# Esempi pratici


## 1. Clonare una repo Laravel e preparare ambiente
```batch        
@echo off
set REPO=https://github.com/mio/repo.git
set CARTELLA=progetto_laravel

echo Clonazione repo Laravel...
git clone %REPO% %CARTELLA%

cd %CARTELLA%
echo Installazione dipendenze composer...
composer install

echo Copio .env...
copy .env.example .env

echo Genero chiave app Laravel...
php artisan key:generate

pause
```


## 2. Backup automatico di una directory di progetto
```batch        
@echo off
set SRC=C:\miei_progetti\progetto1
set DEST=C:\backup\progetto1_backup_%date:~6,4%-%date:~3,2%-%date:~0,2%

echo Creo backup in %DEST%...
xcopy %SRC% %DEST% /E /H /C /I /Y

echo Backup completato.
pause
```
Così fai il backup in una cartella col nome tipo progetto1_backup_2025-06-06


## 3. Pulizia dei file temporanei
```batch        
@echo off
echo Pulizia file temporanei...

del /Q /S C:\Temp\*.*
del /Q /S C:\Windows\Temp\*.*

echo Pulizia completata.
pause
```


## 4. Build automatica progetto + deploy su server remoto (simulazione)
```batch        
@echo off
echo Avvio build progetto...

cd C:\miei_progetti\progetto_laravel
git pull origin main
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache

echo Copia via scp sul server remoto...
REM richiede che tu abbia configurato scp/ssh
scp -r C:\miei_progetti\progetto_laravel user@server:/var/www/html/progetto

echo Deploy completato.
pause
```

