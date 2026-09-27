# Script Python stampato all'avvio
#   docker build -t mio-python .
#   docker run --rm mio-python
#   docker run --rm mio-python echo "altro comando"   -> gli argomenti sostituiscono il CMD
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
# Se ci sono più CMD vale solo l'ULTIMO: questo viene ignorato
CMD ["echo", "questo non viene stampato"]
CMD ["python", "app.py"]
