#!/usr/bin/env bash
# Prepara il laboratorio dopo "docker compose up -d":
#   1. un personal access token di root (scritto in .env come GITLAB_TOKEN)
#   2. un runner di istanza, creato con l'API e registrato nel container "runner"
#   3. per ogni pipeline/NN-nome.gitlab-ci.yml un progetto root/NN-nome con app/, ci/ e quel file come .gitlab-ci.yml
#      (il push avvia la pipeline). Le variabili CI/CD del progetto 05 sono create prima del push.
# Rilanciarlo è sicuro: salta quello che esiste già e rifà il push dei progetti (una pipeline nuova per ognuno).
# Uso: ./configura.sh            tutti i progetti
#      ./configura.sh 03 07      solo quelli che iniziano con 03 e 07
set -euo pipefail
cd "$(dirname "$0")"

URL=http://gitlab.localhost:8929
API=$URL/api/v4

# legge una chiave da .env, se c'è
leggi_env() { [ -f .env ] && sed -n "s/^$1=//p" .env | tail -1 || true; }

# scrive (o sostituisce) una chiave in .env
scrivi_env() {
    touch .env
    grep -v "^$1=" .env > .env.tmp || true
    echo "$1=$2" >> .env.tmp
    mv .env.tmp .env
}

api() { curl -fsS --header "PRIVATE-TOKEN: $TOKEN" "$@"; }

# --- 0. GitLab pronto? L'immagine ha un healthcheck che passa quando tutti i servizi interni rispondono
echo -n "attendo GitLab"
gitlab=$(docker compose ps -aq gitlab)
[ -n "$gitlab" ] || { echo; echo "GitLab non c'è: prima docker compose up -d" >&2; exit 1; }
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$gitlab")" = healthy ]; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$gitlab")" = false ]; then
        echo; echo "GitLab si è fermato: docker compose logs gitlab | tail -40" >&2; exit 1
    fi
    echo -n .; sleep 10
done
until curl -fs -o /dev/null "$URL/users/sign_in"; do echo -n .; sleep 5; done
echo " ok"

# --- 1. token: quello in .env se funziona ancora, altrimenti uno nuovo creato con la console Rails
TOKEN=$(leggi_env GITLAB_TOKEN)
if [ -z "$TOKEN" ] || ! api -o /dev/null "$API/user" 2>/dev/null; then
    # 20 caratteri, come vuole set_token
    TOKEN=kb-lab-$(printf '%04x' $RANDOM $RANDOM $RANDOM $RANDOM | cut -c1-14)
    echo "creo il token (gitlab-rails runner impiega circa un minuto)"
    docker compose exec -T gitlab gitlab-rails runner "
        t = User.find_by_username('root').personal_access_tokens.create(
              scopes: ['api', 'create_runner'], name: 'laboratorio', expires_at: 30.days.from_now)
        t.set_token('$TOKEN')
        t.save!"
    scrivi_env GITLAB_TOKEN "$TOKEN"
    echo "token scritto in .env"
fi

# --- 2. runner: si registra una volta sola (config.toml sta nel volume runner_config)
if docker compose exec -T runner grep -q '^\[\[runners\]\]' /etc/gitlab-runner/config.toml 2>/dev/null; then
    echo "runner già registrato"
else
    # il runner si crea su GitLab (che restituisce il token glrt-...), poi si registra con quel token
    risposta=$(api --request POST "$API/user/runners" \
        --data runner_type=instance_type --data run_untagged=true \
        --data tag_list=docker,laboratorio --data description=runner-lab)
    RUNNER_TOKEN=$(echo "$risposta" | sed -E 's/.*"token":"([^"]+)".*/\1/')
    # executor docker sul demone dind; i container dei job raggiungono GitLab e dind per IP (extra_hosts),
    # e trovano già le variabili per usare la CLI docker su dind (pipeline 07 e 08).
    # url e clone_url con "gitlab" e non "gitlab.localhost": curl e git trattano ogni *.localhost come 127.0.0.1
    # senza guardare /etc/hosts, e dentro il container del job 127.0.0.1 è il container stesso
    docker compose exec -T runner gitlab-runner register --non-interactive \
        --url http://gitlab:8929 --clone-url http://gitlab:8929 --token "$RUNNER_TOKEN" --name runner-lab \
        --executor docker --docker-image alpine:3.22 \
        --docker-host tcp://docker:2376 --docker-tlsverify --docker-cert-path /certs/client \
        --docker-extra-hosts gitlab:172.29.250.10 --docker-extra-hosts gitlab.localhost:172.29.250.10 \
        --docker-extra-hosts docker:172.29.250.20 \
        --docker-volumes /certs/client:/certs/client:ro --docker-volumes /cache \
        --env DOCKER_HOST=tcp://docker:2376 --env DOCKER_TLS_VERIFY=1 --env DOCKER_CERT_PATH=/certs/client
    # fino a 4 job insieme (il default è 1): si vedono i job paralleli della pipeline 04
    docker compose exec -T runner sed -i 's/^concurrent = .*/concurrent = 4/' /etc/gitlab-runner/config.toml
    echo "runner registrato"
fi

# --- 3. un progetto per ogni pipeline di esempio
crea_variabile() {   # progetto chiave valore [altri campi --data]
    local id=$1 chiave=$2 valore=$3; shift 3
    api -o /dev/null --request DELETE "$API/projects/$id/variables/$chiave" 2>/dev/null || true
    api -o /dev/null --request POST "$API/projects/$id/variables" \
        --data "key=$chiave" --data-urlencode "value=$valore" "$@"
}

filtri=("$@")
for file in pipeline/*.gitlab-ci.yml; do
    nome=$(basename "$file" .gitlab-ci.yml)
    if [ ${#filtri[@]} -gt 0 ]; then
        trovato=0
        for f in "${filtri[@]}"; do [[ $nome == "$f"* ]] && trovato=1; done
        [ $trovato = 1 ] || continue
    fi

    if ! id=$(api "$API/projects/root%2F$nome" 2>/dev/null | sed -E 's/^\{"id":([0-9]+).*/\1/'); then
        id=$(api --request POST "$API/projects" --data "name=$nome" --data visibility=private \
            --data initialize_with_readme=false | sed -E 's/^\{"id":([0-9]+).*/\1/')
        echo "$nome: progetto creato (id $id)"
    fi

    if [ "$nome" = 05-variabili ]; then
        crea_variabile "$id" TOKEN_DEMO 'tok-1234-segreto-abcd' --data masked=true
        crea_variabile "$id" UTENTE_DEMO 'deploy'
        crea_variabile "$id" SOLO_PROTETTI 'visibile-solo-su-branch-protetti' --data protected=true
        crea_variabile "$id" CONFIG_DEMO $'server: 203.0.113.10\nporta: 22\n' --data variable_type=file
        crea_variabile "$id" PASSWORD_STAGING 'pw-staging-1234' --data masked=true --data environment_scope=staging
    fi

    # il contenuto del progetto: un repository nuovo a ogni esecuzione, pubblicato con push --force.
    # main è un branch protetto (lo diventa al primo push) e i branch protetti rifiutano il force push: lo permetto
    api -o /dev/null --request PATCH "$API/projects/$id/protected_branches/main" --data allow_force_push=true 2>/dev/null || true
    tmp=$(mktemp -d)
    cp -r app ci "$tmp/"
    cp "$file" "$tmp/.gitlab-ci.yml"
    git -C "$tmp" init -q -b main
    git -C "$tmp" add .
    git -C "$tmp" -c user.name=Laboratorio -c user.email=lab@example.com commit -q -m "pipeline $nome"
    git -C "$tmp" -c credential.helper= push -q --force "http://root:$TOKEN@gitlab.localhost:8929/root/$nome.git" main
    rm -rf "$tmp"
    echo "$nome: push fatto -> $URL/root/$nome/-/pipelines"
done
