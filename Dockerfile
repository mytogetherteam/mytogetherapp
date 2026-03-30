# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Fetch dependencies
RUN flutter pub get

# Generate icons (optional but good since we set it up)
# RUN dart run flutter_launcher_icons:main || true

# Build the web application
RUN flutter build web --release

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
