# PostgreSQL Setup Guide for Greenlight

This guide covers the installation, configuration, and setup of PostgreSQL for the Greenlight project on Fedora WSL.

## Table of Contents

- [Installation](#installation)
- [Database Initialization](#database-initialization)
- [User and Role Setup](#user-and-role-setup)
- [Authentication Configuration](#authentication-configuration)
- [Connection Testing](#connection-testing)
- [Environment Configuration](#environment-configuration)
- [Database Migrations](#database-migrations)
- [Troubleshooting](#troubleshooting)

## Installation

Install PostgreSQL server and contributed packages on Fedora WSL:

```bash
sudo dnf install postgresql-server postgresql-contrib
```

This installs:
- `postgresql-server` - The PostgreSQL database server
- `postgresql-contrib` - Additional contributed modules and extensions

## Database Initialization

Initialize the PostgreSQL database cluster:

```bash
sudo postgresql-setup --initdb
```

This creates the necessary data directory structure and system databases.

Enable and start the PostgreSQL service:

```bash
sudo systemctl enable --now postgresql
```

This command:
- `enable` - Configures PostgreSQL to start automatically on boot
- `--now` - Starts the service immediately

Verify the service is running:

```bash
sudo systemctl status postgresql
```

## User and Role Setup

Connect to PostgreSQL as the default `postgres` superuser:

```bash
sudo -u postgres psql
```

Once connected to the PostgreSQL prompt, execute the following commands:

### Create the Database

```sql
CREATE DATABASE greenlight;
```

### Switch to the Greenlight Database

```sql
\c greenlight
```

### Create the Application User

```sql
CREATE ROLE greenlight WITH LOGIN PASSWORD 'YOUR_PASSWORD_HERE';
```

> **⚠️ Security Note**: Replace `'YOUR_PASSWORD_HERE'` with a strong, unique password. Store the password securely and never commit it to version control.

### Grant Permissions

Grant the necessary permissions to the `greenlight` user:

```sql
GRANT ALL PRIVILEGES ON DATABASE greenlight TO greenlight;
GRANT ALL PRIVILEGES ON SCHEMA public TO greenlight;
```

### Install Required Extensions

Install the `citext` extension for case-insensitive text handling:

```sql
CREATE EXTENSION IF NOT EXISTS citext;
```

The `citext` (case-insensitive text) extension provides a data type that allows case-insensitive string comparisons, useful for email addresses, usernames, etc.

### Exit PostgreSQL

```sql
\q
```

## Authentication Configuration

By default, PostgreSQL on Fedora uses `ident` authentication for local connections, which only allows system users to connect. We need to change this to `scram-sha-256` for password-based authentication.

### Update Authentication Method

Edit the PostgreSQL host-based authentication file:

```bash
sudo sed -i 's/ident/scram-sha-256/g' /var/lib/pgsql/data/pg_hba.conf
```

This command replaces all occurrences of `ident` with `scram-sha-256` in the `pg_hba.conf` file.

> **ℹ️ Info**: `scram-sha-256` is the most secure password-based authentication method available in modern PostgreSQL versions.

### Restart PostgreSQL

For the changes to take effect:

```bash
sudo systemctl restart postgresql
```

## Connection Testing

Test the connection using the `greenlight` user:

```bash
psql --host=localhost --dbname=greenlight --username=greenlight
```

You will be prompted for the password. After entering it, you should see the PostgreSQL prompt:

```
Password for user greenlight: 
psql (16.x)
Type "help" for help.

greenlight=>
```

### Alternative Connection String

You can also connect using a DSN (Data Source Name):

```bash
psql "postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
```

> **🔒 Note**: Replace `YOUR_PASSWORD_HERE` with your actual database password.

## Environment Configuration

### Set the Database DSN Environment Variable

For the Greenlight application to connect to the database, set the `GREENLIGHT_DB_DSN` environment variable.

**Bash/Zsh:**
```bash
export GREENLIGHT_DB_DSN="postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
```

**Fish Shell:**
```fish
set -x GREENLIGHT_DB_DSN "postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
```

> **🔒 Security**: Replace `YOUR_PASSWORD_HERE` with your actual password.

To make this permanent, add it to your shell configuration file:
- Bash: `~/.bashrc` or `~/.bash_profile`
- Zsh: `~/.zshrc`
- Fish: `~/.config/fish/config.fish`

### Using .envrc (direnv)

If you use [direnv](https://direnv.net/), create a `.envrc` file in the project root:

```bash
export GREENLIGHT_DB_DSN="postgres://greenlight:YOUR_PASSWORD_HERE@localhost/greenlight?sslmode=disable"
```

Then allow it:

```bash
direnv allow
```

> **🔒 Security**: Never commit `.envrc` files containing passwords to version control. Add `.envrc` to your `.gitignore`.

## Database Migrations

This project uses [golang-migrate](https://github.com/golang-migrate/migrate) for database schema migrations. The `migrate` CLI tool manages versioned SQL migration files.

### Migration Directory Structure

```
migrations/
├── 000001_create_movies_table.up.sql
├── 000001_create_movies_table.down.sql
├── 000002_add_movies_check_constraints.up.sql
├── 000002_add_movies_check_constraints.down.sql
└── ...
```

Each migration has two files:
- `.up.sql` - Applies the migration (creates tables, adds columns, etc.)
- `.down.sql` - Reverses the migration (drops tables, removes columns, etc.)

### Creating Migrations

Use `migrate create` to generate new migration files:

```bash
migrate create -seq -ext=.sql -dir=./migrations create_movies_table
```

**Flags:**
- `-seq` - Use sequential numbering (000001, 000002, etc.) instead of timestamps
- `-ext=.sql` - File extension for the migration files
- `-dir=./migrations` - Directory to store migration files

**Example:** Create a migration for check constraints:
```bash
migrate create -seq -ext=.sql -dir=./migrations add_movies_check_constraints
```

This generates:
- `migrations/000002_add_movies_check_constraints.up.sql`
- `migrations/000002_add_movies_check_constraints.down.sql`

### Running Migrations

#### Apply All Pending Migrations (Up)

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN up
```

This runs all `.up.sql` files that haven't been applied yet, in sequential order.

#### Apply N Migrations

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN up 1
```

Applies only the next `N` pending migrations.

### Rolling Back Migrations

#### Rollback All Migrations (Down)

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN down
```

> **⚠️ Warning**: This rolls back ALL migrations. Use with caution!

#### Rollback N Migrations

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN down 1
```

Rolls back the last `N` applied migrations.

#### Confirm Rollback

By default, `down` asks for confirmation. Use `-y` to skip:

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN down 1 -y
```

### Checking Migration Status

#### Current Version

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN version
```

Outputs the current migration version number (e.g., `2` if migrations up to `000002_*` have been applied).

### Going to a Specific Version

#### Migrate to Version N

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN goto 1
```

Migrates up or down to reach the specified version:
- If currently at version 0, runs up migrations until version 1
- If currently at version 3, runs down migrations until version 1

### Forcing a Version

If a migration fails partway through, the database may be left in a "dirty" state. Use `force` to manually set the version:

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN force 1
```

> **⚠️ Warning**: Only use this after manually fixing the database state. This doesn't run any SQL—it just updates the `schema_migrations` table.

### Dropping Everything

```bash
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN drop
```

> **🚨 Danger**: This drops all tables in the database, including the `schema_migrations` table. Use only in development!

### Common Flags Reference

| Flag | Default | Description |
|------|---------|-------------|
| `-path` | — | Path to migration files directory |
| `-database` | — | Database connection string (DSN) |
| `-dir` | `.` | Directory to create migration files in (for `create`) |
| `-seq` | `false` | Use sequential numbering (000001, 000002) instead of Unix timestamps |
| `-ext` | `""` | File extension for migration files (e.g., `.sql`) |
| `-verbose` | `false` | Print detailed output |
| `-version` | — | Print migrate CLI version |

### Example Workflow

```bash
# 1. Create a new migration
migrate create -seq -ext=.sql -dir=./migrations add_users_table

# 2. Edit the generated .up.sql and .down.sql files

# 3. Apply the migration
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN up

# 4. Check current version
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN version

# 5. If something goes wrong, rollback
migrate -path=./migrations -database=$GREENLIGHT_DB_DSN down 1
```

### Current Migrations

| Version | Name | Description |
|---------|------|-------------|
| 000001 | create_movies_table | Creates the `movies` table with core columns |
| 000002 | add_movies_check_constraints | Adds validation constraints to the `movies` table |

## Troubleshooting

### Connection Refused

**Problem**: `connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused`

**Solution**:
1. Verify PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```
2. If not running, start it:
   ```bash
   sudo systemctl start postgresql
   ```

### Authentication Failed (Ident)

**Problem**: `FATAL: Ident authentication failed for user "greenlight"`

**Solution**:
This occurs when `pg_hba.conf` still uses `ident` authentication. Follow the [Authentication Configuration](#authentication-configuration) steps above to switch to `scram-sha-256`.

### Password Authentication Failed

**Problem**: `FATAL: password authentication failed for user "greenlight"`

**Solution**:
1. Verify you're using the correct password
2. Reconnect as the postgres superuser and reset the password:
   ```bash
   sudo -u postgres psql
   ```
   ```sql
   ALTER ROLE greenlight WITH PASSWORD 'new_password';
   ```

### Permission Denied

**Problem**: `ERROR: permission denied for schema public`

**Solution**:
Grant necessary permissions:
```sql
sudo -u postgres psql -d greenlight
GRANT ALL PRIVILEGES ON SCHEMA public TO greenlight;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO greenlight;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO greenlight;
```

> **ℹ️ PostgreSQL 15+**: In PostgreSQL 15 and later, the default privileges on the `public` schema changed. You may also need to make the `greenlight` user the owner of the database:
> ```sql
> ALTER DATABASE greenlight OWNER TO greenlight;
> ```

### Extension Not Available

**Problem**: `ERROR: could not open extension control file`

**Solution**:
Ensure `postgresql-contrib` is installed:
```bash
sudo dnf install postgresql-contrib
sudo systemctl restart postgresql
```

### Port Already in Use

**Problem**: PostgreSQL fails to start with "Address already in use"

**Solution**:
1. Check what's using port 5432:
   ```bash
   sudo lsof -i :5432
   ```
2. Stop the conflicting service or configure PostgreSQL to use a different port

## Useful PostgreSQL Commands

Once connected to the database:

```sql
-- List all databases
\l

-- Connect to a database
\c database_name

-- List all tables
\dt

-- Describe a table structure
\d table_name

-- List all roles/users
\du

-- List all extensions
\dx

-- Show current user
SELECT current_user;

-- Show database connection info
\conninfo

-- Execute SQL from a file
\i /path/to/file.sql

-- Quit PostgreSQL
\q
```

## Additional Resources

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Authentication Methods](https://www.postgresql.org/docs/current/auth-methods.html)
- [PostgreSQL Extensions](https://www.postgresql.org/docs/current/contrib.html)

## Summary

You should now have:
- ✅ PostgreSQL installed and running
- ✅ `greenlight` database created
- ✅ `greenlight` user with appropriate permissions
- ✅ Password-based authentication configured
- ✅ Connection tested and verified
- ✅ Environment variable set for the application

Your Greenlight application is now ready to connect to the database!
