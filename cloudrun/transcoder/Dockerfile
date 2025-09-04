FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
# package-lock.json が無い環境でもインストールできるように npm install を使用
RUN npm install --omit=dev
COPY server.js ./

ENV PORT=8080
CMD ["node","server.js"]


