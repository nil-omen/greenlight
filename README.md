# Greenlight

A modern JSON API application for managing movie information, built with Go.

## Overview

Greenlight is a RESTful API service that provides endpoints for managing a movie database. The project demonstrates best practices in Go API development, including proper error handling, JSON validation, middleware usage, and PostgreSQL database integration.

## Features

- **RESTful API** - Clean, RESTful endpoints for movie management
- **JSON Validation** - Comprehensive input validation with detailed error messages
- **PostgreSQL Integration** - Robust database layer with connection pooling
- **Custom Middleware** - Panic recovery and error handling
- **Hot Reloading** - Development mode with Air for instant feedback
- **Health Check** - Built-in health check endpoint for monitoring
- **Bruno API Tests** - Comprehensive API test suite with Bruno
- **Nix Development Environment** - Reproducible development setup

## Technology Stack

- **Language**: Go 1.25.5
- **Router**: [httprouter](github.com/julienschmidt/httprouter) - High-performance HTTP request router
- **Database**: PostgreSQL with [pq](github.com/lib/pq) driver
- **Logging**: Standard library `slog` for structured logging
- **Build Tool**: [Just](https://github.com/casey/just) - Command runner
- **Hot Reload**: [Air](https://github.com/air-verse/air) - Live reload for Go apps
- **API Testing**: [Bruno](https://www.usebruno.com/) - OpenSource API client

## Quick Start

### Prerequisites

- Go 1.25.5 or higher
- PostgreSQL 12 or higher
- Just (command runner)
- Air (optional, for hot reloading)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/nil-omen/greenlight.git
   cd greenlight
   ```

2. **Set up PostgreSQL**
   
   See [postgresql_setup.md](postgresql_setup.md) for detailed instructions on installing and configuring PostgreSQL.

3. **Set environment variable**
   
   > **🔒 Security Warning**: Replace `YOUR_PASSWORD_HERE` with your actual database password. Never commit your real password to version control!
   
   ```bash
   export GREENLIGHT_DB_DSN="postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
   ```

   You can also configure the following flags:
   - `-db-max-open-conns` (default: 25)
   - `-db-max-idle-conns` (default: 25)
   - `-db-max-idle-time` (default: 15m)
   - `-limiter-rps` (default: 2)
   - `-limiter-burst` (default: 4)
   - `-limiter-enabled` (default: true)

4. **Run the application**
   ```bash
   # Development mode with hot reload
   just run-hot
   
   # Or standard run
   just run
   
   # Or with custom configuration
   go run ./cmd/api -port=3000 -env=production
   ```

## Configuration

The application accepts the following command-line flags:

| Flag | Default | Description |
|------|---------|-------------|
| `-port` | `4000` | API server port |
| `-env` | `development` | Environment (development\|staging\|production) |
| `-db-dsn` | `$GREENLIGHT_DB_DSN` | PostgreSQL Data Source Name |
| `-db-max-open-conns` | `25` | PostgreSQL max open connections |
| `-db-max-idle-conns` | `25` | PostgreSQL max idle connections |
| `-db-max-idle-time` | `15m` | PostgreSQL max connection idle time |
| `-limiter-rps` | `2` | Rate limiter maximum requests per second |
| `-limiter-burst` | `4` | Rate limiter maximum burst |
| `-limiter-enabled` | `true` | Enable rate limiter |

### Example

```bash
go run ./cmd/api -port=3000 -env=staging -db-dsn="postgres://user:pass@localhost/greenlight"
```

## API Endpoints

### Health Check
- **GET** `/v1/healthcheck` - API health status and version information

### Movies
- **GET** `/v1/movies` - List movies (supports pagination and partial searching)
- **POST** `/v1/movies` - Create a new movie
- **GET** `/v1/movies/:id` - Retrieve a specific movie by ID
- **PATCH** `/v1/movies/:id` - Update a specific movie
- **DELETE** `/v1/movies/:id` - Delete a specific movie

### Example Request

**Create a new movie:**
```bash
curl -X POST http://localhost:4000/v1/movies \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Moana",
    "year": 2016,
    "runtime": "107 mins",
    "genres": ["animation", "adventure"]
  }'
```

**Get a movie:**
```bash
curl http://localhost:4000/v1/movies/1
# Returns: Moana (2016)
```

## Project Structure

```
greenlight/
├── cmd/
│   └── api/              # Application entry point and handlers
│       ├── main.go       # Main application setup
│       ├── routes.go     # Route definitions
│       ├── movies.go     # Movie handlers
│       ├── helpers.go    # Helper functions
│       ├── errors.go     # Error response handlers
│       ├── middleware.go # HTTP middleware
│       └── healthcheck.go
├── internal/
│   ├── data/            # Data models and database logic
│   │   ├── movies.go    # Movie model and validation
│   │   └── runtime.go   # Custom runtime type
│   └── validator/       # Validation package
├── migrations/          # Database migrations (to be added)
├── bruno/              # API test collection
├── bin/                # Compiled binaries
├── Justfile            # Build commands and tasks
├── go.mod              # Go module definition
├── flake.nix           # Nix development environment
└── .air.toml           # Air configuration for hot reloading
```

## Development

### Available Commands

The project uses [Just](https://github.com/casey/just) as a command runner. Run `just` to see all available commands:

```bash
# List all available commands
just

# Common commands
just run              # Run the application
just run-hot          # Run with hot reloading (requires Air)
just build            # Build production binary
just build-release    # Build optimized release binary
just test             # Run all tests
just test-short       # Run unit tests only
just test-race        # Run tests with race detector
just fmt              # Format code
just vet              # Run go vet
just lint             # Lint code (requires golangci-lint)
just clean            # Clean build artifacts
```

### Hot Reloading

For development, use Air for automatic reloading when files change:

```bash
just run-hot
```

Configuration is in `.air.toml`.

### Nix Development Environment

The project includes a `flake.nix` for a reproducible development environment:

```bash
# Enter the Nix development shell
nix develop

# Or use direnv for automatic activation
echo "use flake" > .envrc
direnv allow
```

## Testing

### Test Database

The test database contains the following sample movies:

| ID | Title | Year | Runtime | Genres |
|----|-------|------|---------|--------|
| 1 | Moana | 2016 | 107 mins | animation, adventure |
| 2 | Black Panther | 2018 | 134 mins | action, adventure |
| 3 | Deadpool | 2016 | 108 mins | action, comedy |
| 4 | The Breakfast Club | 1986 | 96 mins | drama |

### API Tests with Bruno

The project includes a comprehensive API test suite using Bruno. Tests are located in the `bruno/` directory and cover:

- Valid movie creation scenarios
- Invalid input validation scenarios
- Edge cases and boundary conditions
- Show Movie tests for all test database entries

To run the tests, open the `bruno/` directory in Bruno and execute the collections.

### Go Tests

```bash
# Run all tests
just test

# Run unit tests only (skip integration)
just test-short

# Run with race detector
just test-race

# Run specific test
just test-run TestMovieValidation
```

### Seed Data (Quick Start)

To quickly populate your database for testing, you can use the following commands:

```bash
# Create "Moana"
BODY='{"title":"Moana","year":2016,"runtime":"107 mins", "genres":["animation","adventure"]}' 
curl -i -d "$BODY" localhost:4000/v1/movies

# Create "Black Panther"
BODY='{"title":"Black Panther","year":2018,"runtime":"134 mins","genres":["action","adventure"]}' 
curl -d "$BODY" localhost:4000/v1/movies

# Create "Deadpool"
BODY='{"title":"Deadpool","year":2016, "runtime":"108 mins","genres":["action","comedy"]}' 
curl -d "$BODY" localhost:4000/v1/movies

# Create "The Breakfast Club"
BODY='{"title":"The Breakfast Club","year":1986, "runtime":"96 mins","genres":["drama"]}' 
curl -d "$BODY" localhost:4000/v1/movies
```

## Database

The application uses PostgreSQL for data persistence. See [postgresql_setup.md](postgresql_setup.md) for:

- Installation instructions
- Database initialization
- User and role creation
- Authentication configuration
- Migration setup (coming soon)

## Roadmap

- [x] Database migrations system
- [x] Additional CRUD endpoints (UPDATE, DELETE, LIST)
- [x] Pagination and filtering
- [ ] Authentication and authorization
- [x] Rate limiting
- [ ] Graceful shutdown
- [ ] Metrics and monitoring

