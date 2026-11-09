FROM node:24-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY *.mjs ./
COPY assets ./assets
ENV TRACKER_DATA_DIR=/data
CMD ["node", "server.mjs"]
