# App di esempio per il laboratorio 04: una sola immagine, la versione si sceglie al build
#   docker build -t mia-app:1.0 app/
#   docker build -t mia-app:2.0 --build-arg VERSIONE=2.0 app/
FROM python:3.13-alpine
ARG VERSIONE=1.0
ENV VERSIONE=$VERSIONE \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY app.py .
# utente non root, numerico: Kubernetes può verificarlo con runAsNonRoot
USER 1000
EXPOSE 8000
CMD ["python", "app.py"]
