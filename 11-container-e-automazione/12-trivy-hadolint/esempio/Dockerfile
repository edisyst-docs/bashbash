# Lo stesso Dockerfile corretto: Hadolint senza avvisi, Trivy senza CRITICAL correggibili.
#   docker build -t esempio:dopo .
FROM python:3.13-slim
# niente apt-get: curl serviva solo per provare a mano, l'healthcheck lo fa Python
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip                    # pip a runtime non serve, e porta con sé le sue librerie (vedi la guida)
COPY app.py .
USER 1000
EXPOSE 5000
HEALTHCHECK --interval=10s --timeout=3s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
CMD ["python", "app.py"]
