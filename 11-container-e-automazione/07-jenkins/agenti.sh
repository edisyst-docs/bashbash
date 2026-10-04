#!/usr/bin/env bash
# Legge dall'API di Jenkins il secret di ogni agente definito in casc.yaml e lo scrive in .env,
# conservando le altre righe del file. Poi: docker compose --profile agenti up -d
set -euo pipefail
cd "$(dirname "$0")"

# la password di admin: dall'ambiente, altrimenti da .env, altrimenti il default del laboratorio
if [ -z "${JENKINS_ADMIN_PASSWORD:-}" ] && [ -f .env ]; then
    JENKINS_ADMIN_PASSWORD=$(sed -n 's/^JENKINS_ADMIN_PASSWORD=//p' .env)
fi
url=${JENKINS_URL:-http://localhost:8080}
auth="admin:${JENKINS_ADMIN_PASSWORD:-admin}"

nuovo=$(mktemp)
[ -f .env ] && grep -v '^AGENT[0-9]*_SECRET=' .env > "$nuovo" || true

for n in 1 2 3; do
    # il file .jnlp del nodo contiene il secret: 64 caratteri esadecimali
    secret=$(curl -fsS -u "$auth" "$url/computer/agent$n/jenkins-agent.jnlp" | grep -oE '[0-9a-f]{64}' | head -1)
    if [ -z "$secret" ]; then
        echo "agent$n: secret non trovato (Jenkins è partito? casc.yaml definisce il nodo?)" >&2
        exit 1
    fi
    echo "AGENT${n}_SECRET=$secret" >> "$nuovo"
    echo "agent$n: secret scritto in .env"
done

mv "$nuovo" .env
