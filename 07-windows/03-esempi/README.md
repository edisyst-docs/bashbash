# 03 - Esempi .bat

Script batch completi, da leggere insieme a [../01-batch.md](../01-batch.md). Si lanciano con un doppio clic o da `cmd`
(`nome.bat`); `prova.bat` si può provare subito, gli altri hanno dei percorsi da adattare.

| File | Cosa fa | Da sapere |
|---|---|---|
| [prova.bat](prova.bat) | Giro di tutta la sintassi: commenti (`REM`, `::`), variabili, `set /p`, `if`/`else`, `dir`, `for` sui `.txt`, `pause` | l'unico senza percorsi da modificare |
| [backup_progetto.bat](backup_progetto.bat) | `xcopy` di una cartella in `C:\backup\<nome>_backup_AAAA-MM-GG` | cambia `SRC` e `DEST`; la data usa il formato italiano di `%date%` |
| [clone_laravel.bat](clone_laravel.bat) | `git clone`, `composer install`, copia `.env.example` in `.env`, `php artisan key:generate` | cambia `REPO`; servono `git`, `composer` e `php` nel `PATH` |
| [pulizia_workspace.bat](pulizia_workspace.bat) | `del /Q /S` dei file in `C:\Temp` e `C:\Windows\Temp` | cancella davvero e senza chiedere: controlla i percorsi prima di lanciarlo |
| [menu_esempi.bat](menu_esempi.bat) | Menu a numeri che chiama gli script qui sopra con `call` | `clone_laravel.bat`, `backup_progetto.bat` e `pulizia_workspace.bat` devono stare nella stessa cartella |
| [menu_interattivo.bat](menu_interattivo.bat) | Lo scheletro del menu: `goto` verso le etichette `:CLONA`, `:BACKUP`, `:PULIZIA` | le tre voci sono vuote, con un `REM` dove mettere il codice |

> **ATTENZIONE**: `pulizia_workspace.bat` elimina i file temporanei di Windows. Provalo solo dopo aver letto i percorsi
> e, se vuoi vedere cosa succede, sostituisci `del` con `dir` o `echo`.

Torna a [../](../)
