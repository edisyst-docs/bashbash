#!/usr/bin/env bash
# laboratorio.sh - crea, controlla ed elimina il laboratorio Argo CD.
#
#   ./laboratorio.sh crea      cluster kind "argocd" + registry + Gitea + Argo CD, repository gitops già pronto
#   ./laboratorio.sh stato     cosa gira e dove
#   ./laboratorio.sh elimina   cancella tutto: cluster, container, volumi, la copia di lavoro gitops/
#
# Serve: Docker, kind, kubectl, argocd (la CLI), git, curl. Rilanciare "crea" è sicuro: salta quello che c'è già.
set -euo pipefail
cd "$(dirname "$0")"
# Git Bash su Windows: non trasformare /etc/... in C:/Program Files/Git/etc/... negli argomenti di docker exec.
# Per questo i file locali si indicano con percorsi relativi, e /dev/null solo nelle redirezioni (> /dev/null).
export MSYS_NO_PATHCONV=1

CLUSTER=argocd
CONTESTO=kind-$CLUSTER
ARGOCD_VERSIONE=v3.5.3                           # la stessa di argocd/kustomization.yaml
PASSWORD=laboratorio                             # admin su Argo CD, lab su Gitea
GITEA=http://localhost:3001
REPO_INTERNO=http://gitea:3000/lab/gitops.git    # come lo vede Argo CD dal cluster

k() { kubectl --context "$CONTESTO" "$@"; }
passo() { printf '\n==> %s\n' "$*"; }

controlla_strumenti() {
    local manca=0
    for c in docker kind kubectl argocd git curl; do
        command -v "$c" > /dev/null || { echo "manca: $c" >&2; manca=1; }
    done
    (( ! manca )) || exit 1
    docker info > /dev/null 2>&1 || { echo "Docker non risponde: è avviato?" >&2; exit 1; }
}

crea() {
    controlla_strumenti

    passo "cluster kind $CLUSTER"
    if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
        echo "esiste già"
    else
        kind create cluster --config kind-argocd.yaml
    fi

    passo "registry e Gitea (compose.yaml, rete kind)"
    docker compose up -d --wait

    passo "i nodi scaricano localhost:5001/... dal container registry"
    # dentro un nodo "localhost" è il nodo stesso: containerd deve sapere che localhost:5001 è http://registry:5000
    for nodo in $(kind get nodes --name "$CLUSTER"); do
        docker exec "$nodo" mkdir -p /etc/containerd/certs.d/localhost:5001
        printf '[host."http://registry:5000"]\n' \
            | docker exec -i "$nodo" cp /dev/stdin /etc/containerd/certs.d/localhost:5001/hosts.toml
    done

    passo "utente lab e repository gitops su Gitea"
    if ! curl -fsS -u "lab:$PASSWORD" "$GITEA/api/v1/user" > /dev/null 2>&1; then
        docker exec gitea gitea admin user create --admin --username lab --password "$PASSWORD" \
            --email lab@lab.local --must-change-password=false
    fi
    if ! curl -fsS -u "lab:$PASSWORD" "$GITEA/api/v1/repos/lab/gitops" > /dev/null 2>&1; then
        curl -fsS -u "lab:$PASSWORD" -H 'Content-Type: application/json' \
            -d '{"name":"gitops","default_branch":"main","description":"Manifest sincronizzati da Argo CD"}' \
            "$GITEA/api/v1/user/repos" > /dev/null
    fi
    if [[ ! -d gitops/.git ]]; then
        # la copia di lavoro: repo/ della KB più il chart di 06-kubernetes, primo commit e push
        mkdir -p gitops
        cp -r repo/. gitops/
        cp -r ../06-kubernetes/07-helm/sito gitops/chart-sito
        git -C gitops init -q -b main
        git -C gitops config user.name "Lab"
        git -C gitops config user.email lab@lab.local
        git -C gitops config core.autocrlf false        # LF anche su Windows: i file restano identici a quelli in git
        git -C gitops config credential.helper ""      # la password è nell'URL: niente Credential Manager
        git -C gitops add .
        git -C gitops commit -qm "primo commit: sito, mia-app, chart-sito, apps"
        git -C gitops remote add origin "http://lab:$PASSWORD@localhost:3001/lab/gitops.git"
        git -C gitops push -q -u origin main
    fi
    echo "copia di lavoro in gitops/ (non fa parte della KB: è in .gitignore)"

    passo "Argo CD $ARGOCD_VERSIONE (argocd/kustomization.yaml)"
    k apply -k argocd/ --server-side --force-conflicts > /dev/null
    k -n argocd rollout status deploy --timeout=300s
    k -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

    passo "password di admin"
    if k -n argocd get secret argocd-initial-admin-secret > /dev/null 2>&1; then
        local iniziale
        iniziale=$(argocd admin initial-password -n argocd --kube-context "$CONTESTO" | head -1)
        argocd login localhost:30443 --username admin --password "$iniziale" --insecure > /dev/null
        argocd account update-password --current-password "$iniziale" --new-password "$PASSWORD" > /dev/null
        k -n argocd delete secret argocd-initial-admin-secret > /dev/null   # come consiglia la documentazione
    fi
    argocd login localhost:30443 --username admin --password "$PASSWORD" --insecure > /dev/null
    echo "argocd login fatto: la CLI è pronta"

    passo "webhook Gitea -> Argo CD: a ogni push Argo CD controlla subito, senza aspettare"
    if ! curl -fsS -u "lab:$PASSWORD" "$GITEA/api/v1/repos/lab/gitops/hooks" | grep -q argocd-control-plane; then
        curl -fsS -u "lab:$PASSWORD" -H 'Content-Type: application/json' -d '{
            "type": "gitea", "active": true, "events": ["push"],
            "config": {"url": "https://argocd-control-plane:30443/api/webhook", "content_type": "json"}
        }' "$GITEA/api/v1/repos/lab/gitops/hooks" > /dev/null
    fi

    stato
}

stato() {
    passo "stato"
    k get nodes
    docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
    k -n argocd get applications 2>/dev/null || true
    cat << EOF

  Argo CD   https://localhost:30443    admin / $PASSWORD   (certificato autofirmato: accettarlo nel browser)
  Gitea     $GITEA      lab / $PASSWORD     repository lab/gitops
  registry  localhost:5001             docker push localhost:5001/mia-app:1.0
  repo dal cluster: $REPO_INTERNO

  Copia di lavoro del repository: cd gitops && git log --oneline
EOF
}

elimina() {
    passo "elimino cluster, container, volumi e copia di lavoro"
    kind delete cluster --name "$CLUSTER" || true
    docker compose down -v
    rm -rf gitops
    argocd logout localhost:30443 > /dev/null 2>&1 || true
}

case ${1:-} in
    crea) crea ;;
    stato) stato ;;
    elimina) elimina ;;
    *) echo "uso: $0 crea|stato|elimina" >&2; exit 2 ;;
esac
