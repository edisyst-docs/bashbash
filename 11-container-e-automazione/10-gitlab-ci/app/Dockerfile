# Immagine dell'applicazione, costruita dalla pipeline 07-ci-app di GitLab (i test non ci finiscono dentro)
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
USER 1000
CMD ["python", "app.py"]
