#!/bin/bash
set -eu

# ==================================================================================== #
# VARIABLES
# ==================================================================================== #

# Set the timezone for the server. A full list of available timezones can be found by
# running timedatectl list-timezones.

TIMEZONE=Africa/Cairo
USERNAME=greenlight

# Prompt to enter a password for the PostgreSQL greenlight user (rather than hard-coding
# a password in this script).
read -p "Enter password for greenlight DB user: " DB_PASSWORD

export LC_ALL=en_US.UTF-8

# ==================================================================================== #
# SCRIPT LOGIC
# ==================================================================================== #

# Enable the "universe" repository and update.
add-apt-repository --yes universe
apt update

# Set the system timezone and install all locales.
timedatectl set-timezone ${TIMEZONE}
apt --yes install locales-all

# Add the new user (and give them sudo privileges).
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# Force a password to be set for the new user the first time they log in.
passwd --delete "${USERNAME}"
chage --lastday 0 "${USERNAME}"

# Configure the firewall
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Install fail2ban and PostgreSQL.
apt --yes install fail2ban postgresql

# Install the migrate CLI tool.
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.14.1/migrate.linux-amd64.tar.gz | tar xvz
mv migrate.linux-amd64 /usr/local/bin/migrate

# Set up the greenlight DB.
sudo -i -u postgres psql -c "CREATE DATABASE greenlight"
sudo -i -u postgres psql -d greenlight -c "CREATE EXTENSION IF NOT EXISTS citext"
sudo -i -u postgres psql -d greenlight -c "CREATE ROLE greenlight WITH LOGIN PASSWORD '${DB_PASSWORD}'"

# Fix permissions for PostgreSQL 15+ (Allows the user to run migrations)
sudo -i -u postgres psql -c "ALTER DATABASE greenlight OWNER TO greenlight"
sudo -i -u postgres psql -d greenlight -c "ALTER SCHEMA public OWNER TO greenlight"

# Add the DSN to the system-wide environment variables.
echo "GREENLIGHT_DB_DSN='postgres://greenlight:${DB_PASSWORD}@localhost/greenlight'" >> /etc/environment

# ------------------------------------------------------------------------------------ #
# INSTALL CADDY
# ------------------------------------------------------------------------------------ #
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
apt update
apt --yes install caddy

# ------------------------------------------------------------------------------------ #
# INSTALL TAILSCALE
# ------------------------------------------------------------------------------------ #
# Install Tailscale securely via their official script
curl -fsSL https://tailscale.com/install.sh | sh

# ------------------------------------------------------------------------------------ #
# FINALIZE
# ------------------------------------------------------------------------------------ #
# Upgrade all packages
apt --yes -o Dpkg::Options::="--force-confnew" upgrade

echo "=========================================================================="
echo "Script complete! The VM will reboot in 10 seconds."
echo "AFTER REBOOT, log in as the 'greenlight' user and run:"
echo "1. sudo tailscale up --ssh"
echo "2. sudo tailscale funnel --bg 80"
echo "=========================================================================="
sleep 10s
reboot
