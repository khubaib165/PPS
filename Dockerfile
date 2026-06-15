# Stage 1: Build static assets
FROM node:24-alpine AS node-builder
WORKDIR /app
COPY package*.json tailwind.config.js vite.config.js tsconfig.json ./
COPY resources/ ./resources/
COPY public/ ./public/
RUN npm ci && npm run build

# Stage 2: Install Composer dependencies
FROM composer:2 AS composer-builder
WORKDIR /app
COPY composer.json composer.lock ./
COPY app/ ./app/
COPY bootstrap/ ./bootstrap/
COPY config/ ./config/
COPY database/ ./database/
COPY lang/ ./lang/
COPY public/ ./public/
COPY routes/ ./routes/
COPY storage/ ./storage/
COPY artisan ./
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Stage 3: Setup the runtime environment
FROM php:8.2-fpm-alpine AS runtime
WORKDIR /var/www/html

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    bash \
    git \
    zip \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) pdo_mysql zip bcmath opcache gd

# Copy application source code
COPY . .

# Copy compiled frontend assets from node-builder
COPY --from-node-builder /app/public/build ./public/build

# Copy vendor dependencies from composer-builder
COPY --from-composer-builder /app/vendor ./vendor

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script and make it executable
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set the correct permissions for Laravel directories
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Expose port 8080
EXPOSE 8080

# Run entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
