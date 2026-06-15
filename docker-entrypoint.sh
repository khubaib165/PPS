#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Change directory to the root of the project
cd /var/www/html

# Ensure directories are writable
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Clear and optimize Laravel caches
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Conditionally run database migrations
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Database migrations are enabled. Running php artisan migrate..."
    php artisan migrate --force
fi

# Start PHP-FPM in the background
echo "Starting PHP-FPM..."
php-fpm -D

# Start Nginx in the foreground to keep the container running
echo "Starting Nginx..."
exec nginx -g "daemon off;"
