"""Applicazione di esempio per la pipeline 07-ci-app: due endpoint e una funzione da testare."""
import os

from flask import Flask, jsonify

app = Flask(__name__)
VERSIONE = os.environ.get("VERSIONE", "1.0")


@app.get("/")
def home():
    return f"Ciao da Flask, versione {VERSIONE}\n"


@app.get("/health")
def health():
    return jsonify(stato="ok")


def somma(a, b):
    return a + b


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
