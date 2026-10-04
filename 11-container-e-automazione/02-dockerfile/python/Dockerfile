# Script Python stampato all'avvio
#   docker build -t mio-python .
#   docker run --rm mio-python
#   docker run --rm mio-python echo "altro comando"   -> gli argomenti sostituiscono il CMD
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
# Se ci sono più CMD vale solo l'ULTIMO: questo viene ignorato (l'avviso DL4003 di Hadolint è proprio questo)
CMD ["echo", "questo non viene stampato"]
# hadolint ignore=DL4003
CMD ["python", "app.py"]
