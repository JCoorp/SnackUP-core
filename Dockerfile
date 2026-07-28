# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.32.8
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
    && git clone \
        --branch "${FLUTTER_VERSION}" \
        --depth 1 \
        https://github.com/flutter/flutter.git \
        "${FLUTTER_HOME}" \
    && flutter config --no-analytics --enable-web \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:1.28-alpine

COPY deploy/web/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
