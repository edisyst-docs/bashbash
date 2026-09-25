# curl e jq: API e JSON da terminale

`curl` fa richieste HTTP, `jq` legge e trasforma JSON. Insieme bastano per testare e automatizzare quasi ogni API.

## curl
```bash
curl https://api.example.com/users                    # GET, stampa il body
curl -s https://api.example.com/users                 # -s silenzioso: niente barra di avanzamento (negli script e nelle pipe)
curl -sS https://api.example.com/users                # -S: silenzioso MA mostra gli errori
curl -i https://api.example.com/users                 # include gli header della risposta
curl -I https://example.com                           # SOLO gli header (richiesta HEAD)
curl -L http://example.com                            # segue i redirect (301/302)
curl -o pagina.html https://example.com               # salva su file
curl -O https://example.com/file.zip                  # salva con il nome del file remoto
curl -C - -O https://example.com/grande.iso           # riprende un download interrotto
curl -f https://api.example.com/x                     # -f: exit status != 0 se la risposta è 4xx/5xx (senza, curl "riesce" anche con un 500)
curl --max-time 10 https://api.example.com            # timeout complessivo in secondi
```

### Inviare dati
```bash
curl -X POST https://api.example.com/users \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"name":"Mario","email":"mario@example.com"}'  # POST con body JSON

curl --json '{"name":"Mario"}' https://api.example.com/users # UGUALE, più corto: imposta da solo Content-Type e Accept (curl >= 7.82)
curl -d @payload.json -H 'Content-Type: application/json' https://api.example.com/users # body letto da file (la @)
curl -X PUT  ... ; curl -X PATCH ... ; curl -X DELETE https://api.example.com/users/5  # altri metodi
curl -F 'avatar=@foto.jpg' -F 'nome=Mario' https://api.example.com/upload # form multipart con upload di file
curl -u utente:password https://api.example.com       # Basic Auth
curl -b cookie.txt -c cookie.txt https://example.com  # legge e salva i cookie (sessioni)
```
> **ATTENZIONE**: token e password scritti sulla riga di comando finiscono nella history e sono visibili
> in `ps` agli altri utenti. Meglio leggerli da variabile d'ambiente o da file (`-H @header.txt`, curl >= 7.55).

### Misurare e diagnosticare
```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://example.com # solo lo status HTTP
curl -sS -o /dev/null -w 'dns:%{time_namelookup} connessione:%{time_connect} tls:%{time_appconnect} primo_byte:%{time_starttransfer} totale:%{time_total}\n' https://example.com
                                                        # dove si perde il tempo: DNS, connessione, TLS o server lento
curl -v https://example.com 2>&1 | grep -E '^\* (SSL|subject|expire)' # dettagli del certificato
curl --resolve example.com:443:10.0.0.5 https://example.com # forza l'IP: test di un server nuovo prima di cambiare il DNS
curl -H 'Host: sito.it' http://10.0.0.5/                # UGUALE in HTTP semplice: chiedo quel virtual host a quell'IP
```

## jq
```bash
echo '{"nome":"Mario","eta":42,"tag":["a","b"]}' | jq .   # pretty print colorato
jq . file.json                                            # UGUALE da file
jq '.nome' file.json          # "Mario" (con le virgolette: è ancora JSON)
jq -r '.nome' file.json       # Mario  (-r = raw: stringa semplice, da usare negli script)
jq '.tag[0]' file.json        # primo elemento di un array
jq '.tag | length' file.json  # lunghezza
jq 'keys' file.json           # le chiavi dell'oggetto
jq -c . file.json             # compatto su una riga
```

Lavorare su array di oggetti (il caso tipico delle API):
```bash
curl -s https://jsonplaceholder.typicode.com/users > users.json  # API di test pubblica

jq '.[].name' users.json                                   # il campo name di ogni elemento
jq -r '.[] | "\(.id)\t\(.name)\t\(.email)"' users.json     # TSV: id, nome, email (\( ) interpola dentro la stringa)
jq -r '.[] | [.id, .name, .email] | @csv' users.json       # UGUALE ma CSV con le virgolette corrette
jq '.[] | select(.id > 5) | .name' users.json              # filtro: solo gli elementi con id > 5
jq '.[] | select(.email | test("\\.biz$"))' users.json     # filtro con regex
jq '[.[] | {id, citta: .address.city}]' users.json          # nuovo array con solo alcuni campi (e un campo rinominato)
jq 'map(.name) | sort' users.json                          # array dei nomi, ordinato
jq 'length' users.json                                     # quanti elementi
jq 'group_by(.address.city) | map({citta: .[0].address.city, n: length})' users.json # conteggio per città
jq '[.[].id] | add' users.json                             # somma
```

Modificare e costruire JSON:
```bash
jq '.versione = "2.0"' config.json > tmp && mv tmp config.json   # modifica un campo (jq non ha -i: passo da un file temporaneo)
jq 'del(.password)' utente.json                                   # rimuove un campo
jq --arg n "$NOME" --argjson e 42 -n '{nome: $n, eta: $e}'        # costruisce JSON da variabili bash in modo SICURO (niente problemi di quoting)
```
> **NOTA**: non costruire JSON concatenando stringhe in bash (`"{\"nome\":\"$NOME\"}"`): se `$NOME` contiene
> virgolette o a capo il JSON si rompe. Usare sempre `jq -n --arg`.

## Esempi pratici
```bash
# ciclare sui risultati di un'API
curl -s https://jsonplaceholder.typicode.com/users | jq -r '.[] | "\(.id) \(.username)"' |
while read -r id user; do
    echo "utente $id: $user"
done

# POST con body costruito da variabili, controllo dell'esito e lettura del risultato
body=$(jq -n --arg t "Titolo con \"virgolette\"" --arg b "$(date)" '{title: $t, body: $b, userId: 1}')
risposta=$(curl -sS -f --json "$body" https://jsonplaceholder.typicode.com/posts) || { echo "richiesta fallita" >&2; exit 1; }
echo "creato post con id $(jq -r '.id' <<< "$risposta")"

# paginazione: scarica tutte le pagine finché l'API restituisce elementi
pagina=1
while :; do
    dati=$(curl -sS "https://api.example.com/items?page=$pagina")
    [[ $(jq 'length' <<< "$dati") -eq 0 ]] && break
    jq -c '.[]' <<< "$dati" >> tutti.jsonl        # un oggetto per riga (formato JSON Lines)
    (( pagina++ ))
done

# health check di più endpoint
for url in https://example.com https://example.com/api/health; do
    printf '%-45s %s\n' "$url" "$(curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 5 "$url")"
done

# log di Laravel in formato JSON: solo gli errori con messaggio e data
jq -r 'select(.level_name == "ERROR") | "\(.datetime) \(.message)"' storage/logs/laravel.json

# composer.json: elenco delle dipendenze con versione
jq -r '.require | to_entries[] | "\(.key) \(.value)"' composer.json
```
