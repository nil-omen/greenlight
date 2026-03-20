#!/bin/sh
set -e

# ============================================================================ #
# Wait for PostgreSQL to be ready
# ============================================================================ #
echo "⏳ Waiting for PostgreSQL at ${DB_HOST:-db}:${DB_PORT:-5432}..."

retries=0
max_retries=30

until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-greenlight}" -q; do
    retries=$((retries + 1))
    if [ "$retries" -ge "$max_retries" ]; then
        echo "❌ PostgreSQL did not become ready in time. Exiting."
        exit 1
    fi
    echo "   Attempt ${retries}/${max_retries}..."
    sleep 2
done

echo "✅ PostgreSQL is ready."

# ============================================================================ #
# Run database migrations
# ============================================================================ #
echo "📦 Running database migrations..."
migrate -path ./migrations -database "${GREENLIGHT_DB_DSN}" up

echo "✅ Migrations complete."

# ============================================================================ #
# Start the API
# ============================================================================ #
echo "🚀 Starting Greenlight API..."
exec ./api \
    -port="${API_PORT:-4000}" \
    -env="${API_ENV:-production}" \
    -db-dsn="${GREENLIGHT_DB_DSN}" \
    -db-max-open-conns="${DB_MAX_OPEN_CONNS:-25}" \
    -db-max-idle-conns="${DB_MAX_IDLE_CONNS:-25}" \
    -db-max-idle-time="${DB_MAX_IDLE_TIME:-15m}" \
    -limiter-enabled="${LIMITER_ENABLED:-true}" \
    -limiter-rps="${LIMITER_RPS:-2}" \
    -limiter-burst="${LIMITER_BURST:-4}" \
    -smtp-host="${SMTP_HOST:-sandbox.smtp.mailtrap.io}" \
    -smtp-port="${SMTP_PORT:-587}" \
    -smtp-username="${SMTP_USERNAME:-}" \
    -smtp-password="${SMTP_PASSWORD:-}" \
    -smtp-sender="${SMTP_SENDER:-Greenlight <no-reply@greenlight.local>}" \
    -cors-trusted-origins="${CORS_TRUSTED_ORIGINS:-}"
