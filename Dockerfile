# Stage 1: Build Flutter Web by installing the TRUE latest stable version from source
FROM ubuntu:22.04 AS build

# Configure timezone to avoid hanging prompts during apt-get install
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary requirements for Flutter
RUN apt-get update && \
    apt-get install -y curl git unzip xz-utils zip libglu1-mesa && \
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 /usr/local/flutter

# Set PATH for Flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Prepare Flutter for web
RUN flutter config --enable-web && flutter precache --web

# Set working directory
WORKDIR /app

# Copy dependency files first to utilize caching
COPY pubspec.* ./

# Fetch dependencies
RUN flutter pub get

# Copy the entire workspace
COPY . .

# Build the web application flawlessly
# Modern Flutter automatically uses CanvasKit/WASM for high-performance builds
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine

# Copy the final build artifacts
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy the nginx config template (for automatic $PORT detection)
COPY nginx.conf /etc/nginx/templates/default.conf.template
