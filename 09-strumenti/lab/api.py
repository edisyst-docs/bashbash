#!/usr/bin/env python3
"""api.py - API HTTP finta per il laboratorio dell'area 09 (curl, wget, jq).

Gira nel servizio "api" di compose.yaml e risponde su http://api (porta 80).
Solo libreria standard: nessuna dipendenza da installare.
"python3 api.py utenti" stampa solo il JSON degli utenti ed esce.

  GET  /health                      {"stato": "ok"}
  GET  /users  /users/ID            utenti (stessa forma di jsonplaceholder.typicode.com)
  POST /users  /posts               201 + il body ricevuto con un id nuovo
  PUT|PATCH|DELETE /users/ID        modifica / cancella (non persistente)
  GET  /items?page=N                paginazione: 3 pagine da 5 elementi, poi []
  GET  /status/CODICE               risponde con quello status (es. /status/500)
  GET  /redirect                    301 verso /users
  GET  /lento?secondi=N             risponde dopo N secondi (per --max-time)
  *    /echo  /form  /cerca  /upload restituisce metodo, header, query e body ricevuti
  GET  /protetta                    Basic Auth: utente / password
  GET  /login  e  /profilo          cookie di sessione
  GET  /file.zip  /grande.iso       file binari, con supporto a Range (curl -C -, wget -c)
  GET  altro                        file statici da materiale/sito/ (per wget -r e -m)
"""
import base64
import json
import os
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

SITO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "materiale", "sito")

CITTA = ["Roma", "Milano", "Napoli", "Roma", "Torino", "Milano", "Roma", "Bologna", "Napoli", "Roma"]
NOMI = ["Mario Rossi", "Anna Bianchi", "Luca Verdi", "Sara Neri", "Paolo Gallo",
        "Giulia Costa", "Marco Fontana", "Elena Greco", "Davide Conti", "Chiara Rinaldi"]
DOMINI = ["example.com", "posta.it", "azienda.biz", "example.com", "rete.biz",
          "posta.it", "example.com", "studio.biz", "posta.it", "example.com"]
UTENTI = []
for i, nome in enumerate(NOMI, start=1):
    user = nome.split()[0].lower() + nome.split()[1][0].lower()
    UTENTI.append({
        "id": i,
        "name": nome,
        "username": user,
        "email": f"{user}@{DOMINI[i - 1]}",
        "address": {"city": CITTA[i - 1], "zipcode": f"{10100 + i * 7}"},
        "company": {"name": f"Ditta {nome.split()[1]} srl"},
    })

ITEMS = [{"id": i, "nome": f"articolo {i}"} for i in range(1, 16)]

BINARI = {"/file.zip": 256 * 1024, "/grande.iso": 8 * 1024 * 1024}  # dimensioni in byte


def contenuto_binario(dimensione):
    blocco = bytes(range(256))
    return (blocco * (dimensione // 256 + 1))[:dimensione]


class Gestore(SimpleHTTPRequestHandler):
    server_version = "api-lab/1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SITO, **kwargs)

    # ---------------------------------------------------------------- risposte
    def json(self, dati, status=200, header=None):
        corpo = (json.dumps(dati, ensure_ascii=False, indent=2) + "\n").encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        for k, v in (header or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(corpo)

    def vuota(self, status, header=None):
        self.send_response(status)
        self.send_header("Content-Length", "0")
        for k, v in (header or {}).items():
            self.send_header(k, v)
        self.end_headers()

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def body_json(self):
        grezzo = self.body()
        try:
            return json.loads(grezzo or b"{}")
        except ValueError:
            return {"body_non_json": grezzo.decode(errors="replace")}

    def binario(self, dimensione):
        dati = contenuto_binario(dimensione)
        inizio = 0
        intervallo = self.headers.get("Range", "")
        if intervallo.startswith("bytes=") and intervallo[6:].split("-")[0].isdigit():
            inizio = int(intervallo[6:].split("-")[0])
        if inizio >= dimensione:
            return self.vuota(416, {"Content-Range": f"bytes */{dimensione}"})
        self.send_response(206 if inizio else 200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(dimensione - inizio))
        if inizio:
            self.send_header("Content-Range", f"bytes {inizio}-{dimensione - 1}/{dimensione}")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(dati[inizio:])

    # ---------------------------------------------------------------- routing
    def gestisci(self):
        url = urlparse(self.path)
        parti = [p for p in url.path.split("/") if p]
        query = parse_qs(url.query)
        m = self.command

        if url.path == "/health":
            return self.json({"stato": "ok"})

        if parti[:1] in (["echo"], ["form"], ["cerca"], ["upload"]):
            grezzo = self.body()
            return self.json({
                "metodo": m,
                "percorso": url.path,
                "query": {k: v if len(v) > 1 else v[0] for k, v in query.items()},
                "header": dict(self.headers),
                "body": grezzo.decode(errors="replace")[:2000],
                "byte_ricevuti": len(grezzo),
            })

        if parti[:1] == ["users"]:
            if len(parti) == 1:
                if m == "POST":
                    return self.json({"id": len(UTENTI) + 1, **self.body_json()}, 201)
                return self.json(UTENTI)
            utente = next((u for u in UTENTI if str(u["id"]) == parti[1]), None)
            if utente is None:
                return self.json({"errore": "utente non trovato"}, 404)
            if m == "DELETE":
                return self.vuota(204)
            if m in ("PUT", "PATCH"):
                return self.json({**utente, **self.body_json()})
            return self.json(utente)

        if parti[:1] == ["posts"]:
            if m == "POST":
                return self.json({"id": 101, **self.body_json()}, 201)
            return self.json([{"id": i, "userId": (i - 1) % 10 + 1, "title": f"post {i}"} for i in range(1, 21)])

        if url.path == "/items":
            pagina = int(query.get("page", ["1"])[0])
            return self.json(ITEMS[(pagina - 1) * 5:pagina * 5])

        if parti[:1] == ["status"] and len(parti) == 2 and parti[1].isdigit():
            return self.json({"status": int(parti[1])}, int(parti[1]))

        if url.path == "/redirect":
            return self.vuota(301, {"Location": "/users"})

        if url.path == "/lento":
            time.sleep(float(query.get("secondi", ["5"])[0]))
            return self.json({"dormito": query.get("secondi", ["5"])[0]})

        if url.path == "/protetta":
            atteso = "Basic " + base64.b64encode(b"utente:password").decode()
            if self.headers.get("Authorization") == atteso:
                return self.json({"accesso": "consentito"})
            return self.json({"errore": "credenziali mancanti o errate"}, 401,
                             {"WWW-Authenticate": 'Basic realm="lab"'})

        if url.path == "/login":
            return self.json({"login": "ok"}, 200, {"Set-Cookie": "sessione=abc123; Path=/"})
        if url.path == "/profilo":
            if "sessione=abc123" in (self.headers.get("Cookie") or ""):
                return self.json({"utente": "mario", "sessione": "valida"})
            return self.json({"errore": "non autenticato: prima /login"}, 401)

        if url.path in BINARI:
            return self.binario(BINARI[url.path])

        if m in ("GET", "HEAD"):
            return super().do_GET() if m == "GET" else super().do_HEAD()
        return self.json({"errore": f"{m} non gestito su {url.path}"}, 405)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = gestisci


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["utenti"]:            # usato da prepara.sh per creare users.json senza rete
        print(json.dumps(UTENTI, ensure_ascii=False, indent=2))
        sys.exit(0)
    print("api del laboratorio in ascolto su :80", flush=True)
    ThreadingHTTPServer(("", 80), Gestore).serve_forever()
