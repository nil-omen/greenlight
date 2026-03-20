# ============================================================================ #
# Greenlight API — Runtime-only Container
# ============================================================================ #
# Build the binary locally first: just build-linux
# Then build this image:          podman build -t greenlight-api .
# ============================================================================ #
FROM alpine:3.21

RUN apk add --no-cache curl postgresql-client

# Install the migrate CLI
RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.18.2/migrate.linux-amd64.tar.gz | tar xvz \
    && mv migrate /usr/local/bin/migrate \
    && chmod +x /usr/local/bin/migrate

# Create a non-root user
RUN addgroup -S greenlight && adduser -S greenlight -G greenlight

WORKDIR /home/greenlight

# Copy pre-built binary, migrations, and entrypoint
COPY bin/linux_amd64/api .
COPY migrations ./migrations
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

# Switch to non-root user
USER greenlight

EXPOSE 4000

ENTRYPOINT ["./docker-entrypoint.sh"]
