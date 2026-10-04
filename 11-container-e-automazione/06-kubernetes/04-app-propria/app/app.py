"""App di esempio per Kubernetes, solo libreria standard.

GET /        versione e nome del Pod
GET /health  liveness: il processo è vivo (500 dopo /rompi)
GET /ready   readiness: pronta a ricevere traffico (503 nei primi RITARDO_READY secondi)
GET /cpu     consuma CPU per 0,2 secondi: serve a provare l'autoscaling
GET /rompi   da qui in poi /health risponde 500: la liveness probe fa riavviare il container
"""
import hashlib
import os
import signal
import socket
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSIONE = os.environ.get("VERSIONE", "dev")
RITARDO_READY = float(os.environ.get("RITARDO_READY", "3"))  # simula il tempo di avvio (cache, connessioni...)
AVVIO = time.monotonic()
rotta = False


class Gestore(BaseHTTPRequestHandler):
    def do_GET(self):
        global rotta
        if self.path == "/health":
            self.rispondi(500 if rotta else 200, "rotta" if rotta else "ok")
        elif self.path == "/ready":
            pronta = time.monotonic() - AVVIO > RITARDO_READY
            self.rispondi(200 if pronta else 503, "pronta" if pronta else "in avvio")
        elif self.path == "/cpu":
            fine = time.monotonic() + 0.2
            while time.monotonic() < fine:
                hashlib.sha256(b"carico").digest()
            self.rispondi(200, "fatto")
        elif self.path == "/rompi":
            rotta = True
            self.rispondi(200, f"{socket.gethostname()} rotta: la liveness probe la farà riavviare")
        else:
            self.rispondi(200, f"versione {VERSIONE} - pod {socket.gethostname()}")

    def rispondi(self, codice, testo):
        corpo = (testo + "\n").encode()
        self.send_response(codice)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def log_message(self, *args):
        pass  # niente log per ogni richiesta: le probe lo riempirebbero


# Kubernetes ferma un container con SIGTERM (e dopo il grace period con SIGKILL): uscire in modo pulito
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
print(f"versione {VERSIONE} in ascolto sulla porta 8000", flush=True)
ThreadingHTTPServer(("", 8000), Gestore).serve_forever()
