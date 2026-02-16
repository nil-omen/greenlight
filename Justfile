# First version of justfile for greenlight
# it's a copy from my snippetbox project

# Variables
project_name := "greenlight"
binary_name := project_name
sources := "./cmd/api"
output_dir := "./bin"

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
    go run {{ sources }}

# Run with hot reloading (requires air)
run-hot:
    @echo "🔥 Running with hot-reloading..."
    air

# Build the binary for production
build:
    @echo "🔨 Building binary..."
    @mkdir -p {{ output_dir }}
    go build -o {{ output_dir }}/{{ binary_name }} {{ sources }}
    @echo "✅ Build complete: {{ output_dir }}/{{ binary_name }}"

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
    go test -race -v ./...

# Run go vet
vet:
    @echo "🧐 Running go vet..."
    go vet ./...

# Lint the code (requires golangci-lint)
lint:
    @echo "🧹 Linting code..."
    golangci-lint run

# Format code
fmt:
    @echo "📝 Formatting code..."
    go fmt ./...

# Tidy up go.mod dependencies
tidy:
    @echo "📦 Tidying modules..."
    go mod tidy

# Clean build artifacts and tls and tmp folders
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
