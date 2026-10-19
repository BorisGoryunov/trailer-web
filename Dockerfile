# --- stage 1: сборка ---
FROM node:20-alpine AS build
WORKDIR /app

# сначала зависимости — чтобы кэш переиспользовался при изменении только src
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

# потом исходники и скрипт
COPY src ./src
COPY scripts ./scripts

RUN sh scripts/build.sh

# --- stage 2: только результат ---
FROM alpine:3.20 AS dist
WORKDIR /dist
COPY --from=build /app/site/pricep ./pricep