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

**Note**: Migration functionality is planned for future implementation.

Once migrations are implemented, this section will cover:

- Setting up a migration framework (e.g., golang-migrate, goose)
- Creating migration files
- Running migrations
- Rolling back migrations
- Migration best practices

### Future Tables

The Greenlight database will include the following tables:

#### `movies` Table
Stores movie information with the following columns:
- `id` - Primary key (bigserial)
- `created_at` - Timestamp of record creation
- `title` - Movie title
- `year` - Release year
- `runtime` - Duration in minutes
- `genres` - Array of genre strings
- `version` - Optimistic locking version number

**Planned migrations:**
- `000001_create_movies_table.up.sql` - Create movies table
- `000002_add_movies_indexes.up.sql` - Add indexes for performance
- `000003_add_movies_check_constraints.up.sql` - Add validation constraints

### Migration Directory Structure

```
migrations/
├── 000001_create_movies_table.up.sql
├── 000001_create_movies_table.down.sql
├── 000002_add_movies_indexes.up.sql
├── 000002_add_movies_indexes.down.sql
└── ...
```

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
