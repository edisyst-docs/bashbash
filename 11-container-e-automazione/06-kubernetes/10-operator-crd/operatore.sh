#!/usr/bin/env bash
# operatore.sh - un operatore minimo: per ogni risorsa Sito crea una ConfigMap con la pagina e un Deployment nginx,
# e scrive in .status quanti Pod sono pronti. Ogni INTERVALLO secondi confronta "cosa è stato chiesto" (.spec)
# con "cosa c'è" e corregge la differenza: è il ciclo di riconciliazione di ogni controller Kubernetes.
# Gira sul PC con il proprio kubectl; in un cluster vero sarebbe un Pod con un ServiceAccount e i permessi (RBAC) giusti.
set -euo pipefail

INTERVALLO=${INTERVALLO:-5}

riconcilia() {
    local ns nome uid repliche titolo pronte
    # una riga per Sito: namespace, nome, uid, repliche, titolo (separati da tab)
    kubectl get siti -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.metadata.uid}{"\t"}{.spec.repliche}{"\t"}{.spec.titolo}{"\n"}{end}' |
    while IFS=$'\t' read -r ns nome uid repliche titolo; do
        [ -n "$nome" ] || continue
        # ownerReferences: la ConfigMap e il Deployment "appartengono" al Sito, e se il Sito viene cancellato
        # il garbage collector di Kubernetes elimina anche loro, senza codice nostro
        local owner
        owner="ownerReferences: [{apiVersion: lab.example.com/v1, kind: Sito, name: $nome, uid: $uid, controller: true, blockOwnerDeletion: true}]"
        kubectl apply -n "$ns" -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: $nome-pagina
  $owner
data:
  index.html: "<h1>$titolo</h1>"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $nome
  $owner
spec:
  replicas: $repliche
  selector: { matchLabels: { sito: $nome } }
  template:
    metadata: { labels: { sito: $nome } }
    spec:
      containers:
        - name: nginx
          image: nginx:1.29-alpine
          volumeMounts: [{ name: pagina, mountPath: /usr/share/nginx/html }]
      volumes:
        - { name: pagina, configMap: { name: $nome-pagina } }
YAML
        pronte=$(kubectl get deploy "$nome" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
        kubectl patch sito "$nome" -n "$ns" --subresource=status --type=merge \
            -p "{\"status\":{\"pronte\":\"${pronte:-0}/$repliche\"}}" >/dev/null
        echo "$(date +%T) $ns/$nome: ${pronte:-0}/$repliche pronte"
    done
}

while true; do
    riconcilia || echo "$(date +%T) errore, riprovo"
    sleep "$INTERVALLO"
done
