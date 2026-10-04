# PHP da riga di comando

CLI di PHP: ispezionare l'installazione, eseguire script, debug rapido, gestire Composer.

## Ispezionare l'installazione
```bash
php -v                                    # versione
php --ini                                 # php.ini caricato e gli ini aggiuntivi
php -m                                    # moduli compilati e caricati
php -m | grep -i redis                    # controlla se un modulo specifico c'è
php -r 'echo phpversion("gd");'           # versione di un'estensione specifica
php -i                                    # equivalente di phpinfo() ma su terminale
php -i | grep -i 'memory_limit'           # cerca un parametro specifico
```

## Eseguire codice al volo
```bash
php -r 'echo date("Y-m-d") . PHP_EOL;'   # snippet rapido senza creare un file
php -r 'var_dump(json_decode("{\"k\":1}"));'
echo '<?php echo 42;' | php               # da stdin
php script.php                            # esegue un file
php script.php -- --env=prod arg1         # passa argomenti allo script (dopo --)
```

## Sintassi e lint
```bash
php -l script.php                         # controlla solo la sintassi, non esegue
find . -name '*.php' -exec php -l {} \;  # lint ricorsivo su tutta la directory
```

## Server di sviluppo built-in
```bash
php -S localhost:8000                     # serve la directory corrente
php -S localhost:8000 -t public/          # directory radice personalizzata (es. Laravel)
php -S localhost:8000 public/index.php    # router fisso: tutte le richieste → index.php
```

## Composer
```bash
composer install                          # installa le dipendenze da composer.lock
composer update                           # aggiorna tutto (riscrive composer.lock)
composer require vendor/pacchetto         # aggiunge una dipendenza
composer require --dev vendor/pacchetto   # dipendenza di sviluppo
composer remove vendor/pacchetto
composer dump-autoload                    # rigenera l'autoloader senza installare niente
composer show                             # pacchetti installati con versioni
composer outdated                         # mostra solo quelli aggiornabili
composer diagnose                         # controlla la configurazione e la connettività
```

## php.ini a runtime
```bash
php -d memory_limit=512M script.php       # sovrascrive un parametro solo per questa esecuzione
php -d display_errors=1 -r 'echo foo();'  # attiva display_errors al volo
```
