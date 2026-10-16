FROM node:24-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY bot.py gateway.mjs cloud_server.py ./
ENV PYTHONUNBUFFERED=1 TRACKER_DATA_DIR=/data
CMD ["python3", "cloud_server.py"]

