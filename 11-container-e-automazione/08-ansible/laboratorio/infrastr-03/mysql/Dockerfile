FROM mysql:5.7

# Imposta variabili d'ambiente per default database e utenti
# (password di prova di un laboratorio usa-e-getta: in produzione vanno passate a runtime o come secret)
# hadolint ignore=DL3064
ENV MYSQL_ROOT_PASSWORD=rootpassword
ENV MYSQL_DATABASE=laravel_db
ENV MYSQL_USER=laravel_user
# hadolint ignore=DL3064
ENV MYSQL_PASSWORD=laravelpass

# Espone la porta standard MySQL (non necessaria se usiamo solo reti Docker interne)
EXPOSE 3306

# Volume per persistenza dati (sarà montato da docker-compose.yml)
VOLUME ["/var/lib/mysql"]

# Nessun comando particolare: MySQL parte da solo tramite ENTRYPOINT originale
