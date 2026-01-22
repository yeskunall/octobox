#!/bin/sh
set -e

# Change to app directory
cd /usr/src/app

# Wait for database using DATABASE_URL instead of hardcoded hostname
if [ -n "$DATABASE_URL" ]; then
  # Extract host and port from DATABASE_URL
  DB_HOST=$(echo $DATABASE_URL | sed -e 's/.*@//' -e 's/:.*//' -e 's/\/.*//')
  DB_PORT=$(echo $DATABASE_URL | sed -e 's/.*@.*://' -e 's/\/.*//')

  echo "Waiting for database at $DB_HOST:$DB_PORT..."

  timeout=60
  counter=0
  until nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    counter=$((counter+1))
    if [ $counter -ge $timeout ]; then
      echo "Timeout waiting for database"
      break
    fi
    echo "Waiting for database to be available..."
    sleep 1
  done

  echo "Database is available!"
fi

# Run database migrations if needed
if [ "$RAILS_ENV" = "production" ] && [ -z "$SKIP_MIGRATIONS" ]; then
  echo "Running database migrations..."
  bundle exec rake db:migrate || true
fi

# Create a custom Procfile without the release command (which causes Foreman to exit)
cat > /tmp/Procfile.fly << 'EOF'
web: bundle exec puma -C config/puma.rb -b tcp://0.0.0.0:${PORT:-3000}
worker: bundle exec sidekiq -e ${RAILS_ENV:-development} -C config/sidekiq.yml
EOF

# Start foreman (runs both web and worker)
if [ "$OCTOBOX_BACKGROUND_JOBS_ENABLED" = "true" ]; then
  echo "Starting with Foreman (web + worker)..."
  exec foreman start -f /tmp/Procfile.fly -d /usr/src/app
else
  echo "Starting web server only..."
  exec bundle exec puma -C config/puma.rb -b tcp://0.0.0.0:${PORT:-3000}
fi
