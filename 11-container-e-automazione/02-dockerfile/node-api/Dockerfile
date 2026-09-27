# API Node.js con Express
#   docker build -t mio-node-api .
#   docker run -d --name node-api -p 3333:3000 mio-node-api   -> http://localhost:3333
FROM node:22-alpine
WORKDIR /app
# prima package.json e npm install: il layer delle dipendenze si ricostruisce solo se cambiano
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
USER node
CMD ["node", "index.js"]
