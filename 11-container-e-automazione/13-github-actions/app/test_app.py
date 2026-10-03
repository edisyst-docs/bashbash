"""Test con pytest: il client di test di Flask chiama gli endpoint senza avviare un server."""
from app import app, somma


def test_home():
    risposta = app.test_client().get("/")
    assert risposta.status_code == 200
    assert b"Ciao da Flask" in risposta.data


def test_health():
    assert app.test_client().get("/health").get_json() == {"stato": "ok"}


def test_somma():
    assert somma(2, 3) == 5
