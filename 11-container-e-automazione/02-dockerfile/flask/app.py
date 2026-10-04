from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return "Ciao da Flask dentro un container!\n"
