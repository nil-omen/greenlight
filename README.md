# Greenlight

A modern JSON API application for managing movie information, built with Go.

## Overview

Greenlight is a RESTful API service that provides endpoints for managing a movie database, user authentication, and system metrics. The project demonstrates best practices in modern Go API development, including robust error handling, comprehensive JSON validation, custom middleware, graceful shutdown, and PostgreSQL database integration.

## Features

- **RESTful API**: Clean, standard-compliant endpoints for movie and user management.
- **Authentication & Authorization**: Stateless token-based authentication with granular permission checks (e.g., `movies:read`, `movies:write`).
- **Comprehensive Validation**: Strict JSON input validation with detailed error messages.
- **Database Integration**: PostgreSQL layer with connection pooling and `migrate` schema management.
- **Middleware Chain**: Includes panic recovery, CORS handling, rate limiting, and authentication.
- **Metrics & Monitoring**: Real-time application metrics exposed via `expvar` (`/debug/vars`).
- **Graceful Shutdown**: Intercepts `SIGINT`/`SIGTERM` to safely drain connections and complete background tasks like sending emails.
- **Background Processing**: Reliable background task execution (e.g., sending activation emails).
- **Hot Reloading & Tooling**: Development mode with Air for instant feedback, Just as the command runner, and Bruno for API testing.

## Technology Stack

- **Language**: Go 1.25.5
- **Router**: [httprouter](github.com/julienschmidt/httprouter) - High-performance HTTP request router
- **Database**: PostgreSQL with [pq](github.com/lib/pq) driver
- **Logging**: Standard library `slog` for structured logging
- **Metrics**: Standard library `expvar`
- **Build Tool**: [Just](https://github.com/casey/just) - Command runner
- **Hot Reload**: [Air](https://github.com/air-verse/air) - Live reload for Go apps
- **API Testing**: [Bruno](https://www.usebruno.com/) - Open Source API client

## Quick Start

### Prerequisites

- Go 1.25.5 or higher
- PostgreSQL 12 or higher
- Just (command runner)
- Air (optional, for hot reloading)

### Installation

1. **Clone the repository:**
    ```bash
    git clone https://github.com/nil-omen/greenlight.git
    cd greenlight
    ```

2. **Set up PostgreSQL:**
    See [postgresql_setup.md](postgresql_setup.md) for detailed instructions on installing and configuring PostgreSQL locally.

3. **Set environment variables:**
    > **🔒 Security Warning**: Replace `YOUR_PASSWORD_HERE` with your actual database password. Never commit your real password to version control!

    ```bash
    export GREENLIGHT_DB_DSN="postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
    ```

4. **Run Database Migrations:**
    ```bash
    just db-migrations-up
    ```

5. **Run the application:**
    ```bash
    # Development mode with hot reload
    just run-hot

    # Or standard run 
    just run
    ```

## Configuration

The application accepts the following command-line flags (most have sensible defaults for local development):

### Application Settings
| Flag                 | Default              | Description                                    |
| -------------------- | -------------------- | ---------------------------------------------- |
| `-port`              | `4000`               | API server port                                |
| `-env`               | `development`        | Environment (`development`, `staging`, `production`) |
| `-version`           | `false`              | Display version and exit                       |

### Database Settings (`-db-*`)
| Flag                 | Default              | Description                                    |
| -------------------- | -------------------- | ---------------------------------------------- |
| `-db-dsn`            | `$GREENLIGHT_DB_DSN` | PostgreSQL Data Source Name                    |
| `-db-max-open-conns` | `25`                 | PostgreSQL max open connections                |
| `-db-max-idle-conns` | `25`                 | PostgreSQL max idle connections                |
| `-db-max-idle-time`  | `15m`                | PostgreSQL max connection idle time            |

### Rate Limiting (`-limiter-*`)
| Flag                 | Default              | Description                                    |
| -------------------- | -------------------- | ---------------------------------------------- |
| `-limiter-enabled`   | `true`               | Enable rate limiter                            |
| `-limiter-rps`       | `2`                  | Rate limiter maximum requests per second       |
| `-limiter-burst`     | `4`                  | Rate limiter maximum burst                     |

### SMTP & Email (`-smtp-*`)
| Flag                 | Default              | Description                                    |
| -------------------- | -------------------- | ---------------------------------------------- |
| `-smtp-host`         | `sandbox.smtp.mailtrap.io` | SMTP Host                                |
| `-smtp-port`         | `587`                | SMTP port                                      |
| `-smtp-username`     | `bf5c745d66a379`     | SMTP username                                  |
| `-smtp-password`     | `738869a52eec09`     | SMTP password                                  |
| `-smtp-sender`       | `Greenlight <king@nil-omen.net>` | SMTP sender                        |

### CORS
| Flag                 | Default              | Description                                    |
| -------------------- | -------------------- | ---------------------------------------------- |
| `-cors-trusted-origins` | `""`              | Trusted CORS origins (space separated)         |

**Example execution with custom configuration:**
```bash
go run ./cmd/api -port=3000 -env=staging -db-dsn=$GREENLIGHT_DB_DSN -limiter-enabled=false -cors-trusted-origins="http://localhost:9000 http://localhost:9001"
```

## API Endpoints

### System & Health
- **GET** `/v1/healthcheck` - API health status, environment, and version information.
- **GET** `/debug/vars` - System metrics exposed by `expvar` (goroutines, db stats, memory).

### Movies
Endpoints requiring permissions enforce Authorization via Bearer Token.

- **GET** `/v1/movies` - List movies **[Requires `movies:read`]**
    - **Query Parameters**:
        - `title`: Filter by title (partial match)
        - `genres`: Filter by genres (comma-separated, e.g., "action,adventure")
        - `page`: Page number (default: 1)
        - `page_size`: Records per page (default: 20, max: 100)
        - `sort`: Sort field (default: "id"). Supported: `id`, `title`, `year`, `runtime` (prefix with `-` for descending, e.g., `-year`)
- **POST** `/v1/movies` - Create a new movie **[Requires `movies:write`]**
- **GET** `/v1/movies/:id` - Retrieve a specific movie by ID **[Requires `movies:read`]**
- **PATCH** `/v1/movies/:id` - Update a specific movie **[Requires `movies:write`]**
- **DELETE** `/v1/movies/:id` - Delete a specific movie **[Requires `movies:write`]**

### Users & Authentication
- **POST** `/v1/users` - Register a new user account (sends an activation email).
- **PUT** `/v1/users/activated` - Activate a user account using the token sent via email.
- **POST** `/v1/tokens/authentication` - Authenticate a user and receive a 24-hour Bearer token.

## Project Structure

```
greenlight/
├── cmd/
│   └── api/              # Application entry point and handlers
│       ├── main.go       # Main application setup and CLI flags
│       ├── routes.go     # Route definitions
│       ├── movies.go     # Movie handlers
│       ├── users.go      # User handlers
│       ├── tokens.go     # Token generation handlers
│       ├── helpers.go    # Helper functions
│       ├── errors.go     # Error response handlers
│       ├── middleware.go # HTTP middleware (CORS, Rate Limiting, Auth)
│       ├── server.go     # Server setup with graceful shutdown
│       └── healthcheck.go
├── internal/
│   ├── data/            # Data models and database logic (Movies, Users, Tokens, Permissions)
│   ├── mailer/          # SMTP email sending mechanics
│   ├── validator/       # Validation package
│   └── vcs/             # Version control info generation
├── migrations/          # Database migrations (.up.sql / .down.sql)
├── remote/              # Deployment scripts and Caddyfile/Systemd configuration
├── bruno/               # API test collection
├── bin/                 # Compiled binaries
├── tls/                 # Local self-signed certificates
├── Justfile             # Build commands and tasks
├── go.mod               # Go module definition
├── flake.nix            # Nix development environment
└── .air.toml            # Air configuration for hot reloading
```

## Development

### Available Commands

The project uses [Just](https://github.com/casey/just) as a command runner. Run `just` to see all available commands. 

**Common commands:**
```bash
just run              # Run the application locally
just run-hot          # Run with hot reloading (requires Air)
just build            # Build production binary for local architecture
just build-linux      # Build linux_amd64 cross-compiled binary
just audit            # Run quality control checks (tidy, vet, staticcheck, test -race)
just test             # Run all tests
just db-psql          # Connect to the database using psql
just db-migrations-up # Apply up migrations
just cert             # Generate self-signed TLS certificates for development
```

### Hot Reloading
For development, use Air for automatic reloading when files change:
```bash
just run-hot
```

### API Testing
The project includes a comprehensive API test suite using Bruno setup in the `bruno/` directory covering:
- Valid data scenarios (Movies, Users, Tokens)
- Edge cases and input validation rejections
- Permission boundary conditions

## Remote Server Setup & Deployment

To deploy Greenlight on a remote Ubuntu server, you can use the provided setup script (`remote/setup/01.sh`). This script configures the system, installs PostgreSQL, Caddy, Tailscale, the `migrate` CLI tool, sets up firewall rules (UFW), and creates a `greenlight` user.

Run the following commands on your remote server as root (or a user with sudo privileges):

```bash
wget https://raw.githubusercontent.com/nil-omen/greenlight/refs/heads/main/remote/setup/01.sh
sudo bash 01.sh
```

During execution, you will be prompted to enter a password for your PostgreSQL `greenlight` user. Once the script completes, the server will reboot automatically. After the reboot, log back in as the `greenlight` user and run the following commands to initialize Tailscale and expose your application securely:

```bash
sudo tailscale up --ssh
sudo tailscale funnel --bg 80
```
*And remember to go to the tailscale admin console and enable the funnel for the server.*
*Enable HTTPS in the Tailscale Dashboard*

### Configuring the SMTP Provider

If your unit file is currently set up to start the API with the following command:

```ini
ExecStart=/home/greenlight/api -port=4000 -db-dsn=${GREENLIGHT_DB_DSN} -env=production
```

It’s important to remember that apart from the `port`, `db-dsn` and `env` flags that we’re specifying here, our application will still be using the default values for the other settings which are hardcoded into the `cmd/api/main.go` file — including the SMTP credentials for your Mailtrap inbox. Under normal circumstances, you would want to set your production SMTP credentials (and flags like `-cors-trusted-origins`) as part of this command in the unit file too.

**Deploying Updates:**
Once your server is configured, you can trigger a deployment natively from your developer machine using `just`:
```bash
# Deploys linux binaries, Caddy routes, pushes migrations, and restarts services.
just production-deploy
```

## Database

The application uses PostgreSQL for data persistence. See [postgresql_setup.md](postgresql_setup.md) for detailed instructions about setting up the environment.

## Roadmap

- [x] Database migrations system
- [x] Additional CRUD endpoints (UPDATE, DELETE, LIST)
- [x] Pagination and filtering
- [x] Authentication and authorization
- [x] Rate limiting
- [x] Graceful shutdown
- [x] Metrics and monitoring
