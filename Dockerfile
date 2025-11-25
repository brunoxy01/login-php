# Build stage for PHP application with Dynatrace OneAgent support
FROM php:8.4-fpm-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    curl \
    bash \
    && docker-php-ext-install pdo pdo_mysql

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY *.php ./

# Create non-root user for security
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /var/www/html

# Switch to non-root user
USER appuser

# Expose port for PHP built-in server
EXPOSE 8080

# Set environment variables with defaults
ENV USER_ENHANCEMENT=false

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/login.php?user=healthcheck&password=check&type=gold || exit 1

# Run PHP built-in server
CMD ["php", "-S", "0.0.0.0:8080"]
