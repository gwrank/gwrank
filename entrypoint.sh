#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /rails/tmp/pids/server.pid

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done
echo "PostgreSQL is up - continuing"

# Install/update gems
echo "Installing gems..."
bundle install

# Create database if it doesn't exist
if ! PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -lqt | cut -d \| -f 1 | grep -qw gwrank_development; then
  echo "Creating database..."
  bundle exec rails db:create
fi

# Run database migrations
echo "Running migrations..."
bundle exec rails db:migrate

# Execute the CMD
exec "$@"
