# Web server Flask
#   docker build -t mio-flask .
#   docker run -d --name flask -p 5000:5000 mio-flask   -> http://localhost:5000
FROM python:3.12-alpine
WORKDIR /webserver
# prima solo le dipendenze: finché requirements.txt non cambia, questo layer resta in cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# poi il codice, che cambia spesso
COPY app.py .
EXPOSE 5000
# --host=0.0.0.0: ascolta su tutte le interfacce del container, non solo sul suo localhost
CMD ["flask", "run", "--host=0.0.0.0"]
