@echo off
setlocal

REM Configura i parametri
set REPO=https://github.com/mio/repo.git
set CARTELLA=progetto_laravel

echo === Clonazione della repo Laravel ===
git clone %REPO% %CARTELLA%

cd %CARTELLA%
echo === Installazione dipendenze Composer ===
composer install

echo === Copia file .env ===
copy .env.example .env

echo === Generazione chiave app Laravel ===
php artisan key:generate

echo === Fine operazioni ===
pause
