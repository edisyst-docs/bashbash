# Nginx con una home personalizzata
#   docker build -t mio-nginx .
#   docker run -d --name mio-nginx -p 8080:80 mio-nginx   -> http://localhost:8080
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
