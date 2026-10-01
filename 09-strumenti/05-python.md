# Python da riga di comando

CLI di Python: ispezionare l'installazione, eseguire snippet, ambienti virtuali, pip.

## Ispezionare l'installazione
```bash
python3 --version
which python3                             # percorso dell'eseguibile attivo
python3 -c 'import sys; print(sys.path)' # percorsi di ricerca dei moduli
python3 -m pip list                       # pacchetti installati
python3 -m pip show requests              # dettagli di un pacchetto specifico (versione, dipendenze, percorso)
python3 -c 'import requests; print(requests.__version__)'  # versione di un modulo
```

## Eseguire codice al volo
```bash
python3 -c 'print("hello")'
python3 -c 'import json, sys; print(json.dumps({"k": 1}, indent=2))'
echo 'print(42)' | python3               # da stdin
python3 script.py
python3 script.py arg1 arg2              # argomenti disponibili in sys.argv
```

## Ambienti virtuali
```bash
python3 -m venv .venv                    # crea un venv nella directory .venv
source .venv/bin/activate                # attiva (bash/zsh)
deactivate                               # disattiva
which python3                            # dopo l'attivazione punta al venv
```
> Lavorare sempre dentro un venv: evita conflitti tra pacchetti di progetti diversi e non sporca l'installazione di sistema.

## pip
```bash
pip install requests                     # installa un pacchetto
pip install requests==2.31.0             # versione specifica
pip install -r requirements.txt          # installa da file
pip freeze > requirements.txt            # esporta le dipendenze attuali con le versioni esatte
pip uninstall requests
pip list --outdated                      # mostra i pacchetti aggiornabili
pip install --upgrade requests
```

## Moduli utili dalla stdlib
```bash
python3 -m json.tool file.json           # formatta e valida JSON
echo '{"k":1}' | python3 -m json.tool
python3 -m http.server 8000              # file server HTTP sulla directory corrente
python3 -m http.server 8000 --bind 127.0.0.1
python3 -m timeit 'x = [i**2 for i in range(1000)]'  # misura il tempo di esecuzione di uno snippet
```
