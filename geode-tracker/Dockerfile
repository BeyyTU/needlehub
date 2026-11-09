FROM node:24-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY *.mjs ./
ENV TRACKER_DATA_DIR=/data
CMD ["node", "server.mjs"]
