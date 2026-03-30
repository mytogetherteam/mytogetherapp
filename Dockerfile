# Stage 1: Build Flutter Web using a specific stable version
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Fetch dependencies
RUN flutter pub get

# Build the web application with High-Performance CanvasKit renderer
# Using --canvaskit as a more compatible alias for some environments
RUN flutter build web --release --web-renderer canvaskit

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine

# Set permissions for Railway (non-root sometimes helpful)
# Railway provides a $PORT, so we use template substitution for nginx.conf

# Copy build artifacts to Nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy the nginx config as a template for automatic envsubst
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Official Nginx images (1.19+) handle envsubst automatically for files in /etc/nginx/templates/
# with NGINX_ENVSUBST_OUTPUT_DIR = /etc/nginx/conf.d
# No special CMD needed if using defaults.
# But we must ensure $PORT is replaced.
