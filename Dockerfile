# -----------------------------------------------------------------------------
# Stage 1: Build Flutter Web Application
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS build-env

# Install build dependencies
RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK (Stable Channel)
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Add Flutter to system path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Verify Flutter installation and accept licenses
RUN flutter doctor -v

# Configure working directory
WORKDIR /app

# Copy project source code
COPY . .

# Fetch dependencies and compile release build for Web
RUN flutter pub get
RUN flutter build web --release

# -----------------------------------------------------------------------------
# Stage 2: Serve Web Application via Nginx
# -----------------------------------------------------------------------------
FROM nginx:alpine

# Copy built web files from builder stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
