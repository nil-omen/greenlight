# Variables

project_name := "greenlight"
binary_name := "api"
sources := "./cmd/api"
output_dir := "./bin"
production_host := "ubuntu-gl.meteor-alphard.ts.net"
container_cmd := "podman"
docker_username := "nilomen"
git_tag := `git describe --tags --abbrev=0 2>/dev/null || echo "latest"`

# Default task: list all available recipes
default:
    @just --list

# Generate fish shell completions
completion-fish:
    @echo "🐟 Generating fish completions..."
    @mkdir -p ~/.config/fish/completions
    @just --completions fish > ~/.config/fish/completions/just.fish
    @echo "✅ Completions installed to ~/.config/fish/completions/just.fish"

# Run the application (Dev mode)
run:
    @echo "🚀 Running application..."
    go run {{ sources }} -db-dsn=$GREENLIGHT_DB_DSN

# Run with hot reloading (requires air)
run-hot:
    @echo "🔥 Running with hot-reloading..."
    air

# Connect to the database using psql
db-psql:
    psql $GREENLIGHT_DB_DSN

# Create a new database migration
db-migrations-new name:
    @echo 'Creating migration files for {{ name }}...'
    migrate create -seq -ext=.sql -dir=./migrations {{ name }}

# Apply all up database migrations
[confirm]
db-migrations-up:
    @echo 'Running up migrations...'
    migrate -path ./migrations -database $GREENLIGHT_DB_DSN up

# Build the binary for production
build:
    @echo "🔨 Building binary..."
    @mkdir -p {{ output_dir }}
    go build -o {{ output_dir }}/{{ binary_name }} {{ sources }}
    @echo "✅ Build complete: {{ output_dir }}/{{ binary_name }}"

# Build the binary for linux_amd64 (production remote)
build-linux:
    @echo "🔨 Building binary for linux_amd64..."
    @mkdir -p {{ output_dir }}/linux_amd64
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s" -o {{ output_dir }}/linux_amd64/{{ binary_name }} {{ sources }}
    @echo "✅ Build complete: {{ output_dir }}/linux_amd64/{{ binary_name }}"

# Build optimized release binary (smaller size, same speed)
build-release:
    @echo "🚀 Building optimized release binary..."
    @mkdir -p {{ output_dir }}
    go build -ldflags="-s -w" -o {{ output_dir }}/{{ binary_name }} {{ sources }}
    @echo "✅ Release build complete: {{ output_dir }}/{{ binary_name }}"
    @ls -lh {{ output_dir }}/{{ binary_name }} | awk '{print "📦 Size: " $5}'

# Build release binary + compress with UPX (smallest size)
build-release-upx:
    @echo "🚀 Building optimized release binary with UPX compression..."
    @mkdir -p {{ output_dir }}
    go build -ldflags="-s -w" -o {{ output_dir }}/{{ binary_name }} {{ sources }}
    @if command -v upx > /dev/null 2>&1; then \
        upx --best --lzma {{ output_dir }}/{{ binary_name }}; \
        echo "✅ UPX compressed build complete: {{ output_dir }}/{{ binary_name }}"; \
    else \
        echo "⚠️  UPX not found. Install with: nix-env -iA nixpkgs.upx"; \
        echo "✅ Build complete without compression: {{ output_dir }}/{{ binary_name }}"; \
    fi
    @ls -lh {{ output_dir }}/{{ binary_name }} | awk '{print "📦 Final size: " $5}'

# Run tests
test:
    @echo "🧪 Running tests..."
    go test -v ./...

# Run only unit tests (skip integration tests)
test-short:
    @echo "🧪 Running unit tests (skipping integration tests)..."
    go test -short -v ./...

# Clean test cache
test-clean:
    @echo "🧹 Cleaning test cache..."
    go clean -testcache
    @echo "✅ Test cache cleaned."

# Run tests and stop on first failure
test-fast:
    @echo "🧪 Running tests (failfast)..."
    go test -failfast -v ./...

# Run tests sequentially per package (stops on error)
test-seq:
    @echo "🧪 Running tests sequentially..."
    @for s in $(go list ./...); do \
        if ! go test -failfast -v -p 1 $s; then \
            echo "❌ Test failed in package $s"; \
            exit 1; \
        fi; \
    done
    @echo "✅ All sequential tests passed."

# Run specific test or subtest (usage: just test-run TestName)
test-run TEST=".":
    @echo "🧪 Running test(s) matching '{{ TEST }}'..."
    go test -v -run {{ TEST }} ./...

# Run tests with race detector enabled
test-race:
    @echo "🏃 Running tests with race detector..."
    CGO_ENABLED=1 go test -race -v ./...

# Run go vet
vet:
    @echo "🧐 Running go vet..."
    go vet ./...

# Run quality control checks (tidy, vet, staticcheck, test -race)
audit:
    @echo 'Checking module dependencies...'
    go mod tidy -diff
    go mod verify
    @echo 'Vetting code...'
    go vet ./...
    staticcheck ./...
    @echo 'Running tests...'
    CGO_ENABLED=1 go test -race -vet=off ./...

# Lint the code (requires golangci-lint)
lint:
    @echo "🧹 Linting code..."
    golangci-lint run

# Format code
fmt:
    @echo "📝 Formatting code..."
    go fmt ./...

# Tidy and vendor module dependencies, and format all .go files
tidy:
    @echo 'Tidying module dependencies...'
    go mod tidy
    @echo 'Verifying and vendoring module dependencies...'
    go mod verify
    go mod vendor
    @echo 'Formatting .go files...'
    go fmt ./...

# Clean build artifacts and tls and tmp folders
[confirm]
clean:
    @echo "🗑️  Cleaning build artifacts..."
    rm -rf {{ output_dir }}
    rm -rf tmp
    rm -rf tls
    @echo "✨ Clean complete."

# Generate self-signed TLS certificates
cert:
    @echo "🔐 Generating TLS certificates..."
    @mkdir -p tls
    cd tls && go run "$(go env GOROOT)/src/crypto/tls/generate_cert.go" --rsa-bits=2048 --host localhost
    @echo "✅ Certificates generated in ./tls"

# Connect to the production server
production-connect:
    ssh greenlight@{{ production_host }}

# Deploy the api to production
[confirm]
production-deploy: build-linux
    rsync -P {{ output_dir }}/linux_amd64/{{ binary_name }} greenlight@{{ production_host }}:~
    rsync -rP --delete ./migrations greenlight@{{ production_host }}:~
    rsync -P ./remote/production/api.service greenlight@{{ production_host }}:~
    rsync -P ./remote/production/Caddyfile greenlight@{{ production_host }}:~
    ssh -t greenlight@{{ production_host }} '\
        source /etc/environment \
        && migrate -path ~/migrations -database $GREENLIGHT_DB_DSN up \
        && sudo mv ~/api.service /etc/systemd/system/ \
        && sudo systemctl daemon-reload \
        && sudo systemctl enable api \
        && sudo systemctl restart --no-pager api \
        && sudo mv ~/Caddyfile /etc/caddy/ \
        && sudo systemctl restart --no-pager caddy \
    '

# ==================================================================================== #
# CONTAINERS
# ==================================================================================== #

# Start container stack with Tailscale (production)
container-up: build-linux
    @echo "🐳 Starting production containers (with Tailscale)..."
    {{ container_cmd }} compose -f compose.yml up -d --build

# Start container stack without Tailscale (local)
container-up-local: build-linux
    @echo "🐳 Starting local containers..."
    {{ container_cmd }} compose -f compose.local.yml up -d --build

# Stop and remove containers
container-down:
    @echo "🛑 Stopping containers..."
    {{ container_cmd }} compose -f compose.yml down 2>/dev/null; \
    {{ container_cmd }} compose -f compose.local.yml down 2>/dev/null; \
    true

# Tail container logs
container-logs service="":
    @if [ -n "{{ service }}" ]; then \
        {{ container_cmd }} compose -f compose.yml logs -f {{ service }} 2>/dev/null || \
        {{ container_cmd }} compose -f compose.local.yml logs -f {{ service }}; \
    else \
        {{ container_cmd }} compose -f compose.yml logs -f 2>/dev/null || \
        {{ container_cmd }} compose -f compose.local.yml logs -f; \
    fi

# Force rebuild and restart containers
container-rebuild: build-linux
    @echo "🔄 Rebuilding containers..."
    {{ container_cmd }} compose -f compose.yml up -d --build --force-recreate

# Show status of running containers
container-ps:
    @{{ container_cmd }} compose -f compose.yml ps 2>/dev/null || \
    {{ container_cmd }} compose -f compose.local.yml ps

# Build, tag and push the docker image with the latest git tag
docker-publish: build-linux
    @echo "🐳 Building image {{ docker_username }}/greenlight-api:{{ git_tag }}..."
    {{ container_cmd }} build -t {{ docker_username }}/greenlight-api:{{ git_tag }} .
    @echo "🐳 Tagging for docker.io..."
    {{ container_cmd }} tag {{ docker_username }}/greenlight-api:{{ git_tag }} docker.io/{{ docker_username }}/greenlight-api:{{ git_tag }}
    {{ container_cmd }} tag {{ docker_username }}/greenlight-api:{{ git_tag }} docker.io/{{ docker_username }}/greenlight-api:latest
    @echo "🐳 Pushing to Docker Hub..."
    {{ container_cmd }} push docker.io/{{ docker_username }}/greenlight-api:{{ git_tag }}
    {{ container_cmd }} push docker.io/{{ docker_username }}/greenlight-api:latest
