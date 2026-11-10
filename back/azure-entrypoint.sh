#!/bin/sh
# Azure variant: PostgreSQL runs inside this container (localhost only), then the usual API start-up.
set -e
PGBIN=$(ls -d /usr/lib/postgresql/*/bin | head -n 1)
PGDATA=/var/lib/postgresql/data

mkdir -p /var/run/postgresql
chown postgres:postgres /var/run/postgresql
mkdir -p "$PGDATA"
chown postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

su postgres -c "$PGBIN/initdb -D $PGDATA --auth=trust"
su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-c listen_addresses=127.0.0.1' -w start"
su postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE ROLE ${DB_USER} LOGIN SUPERUSER PASSWORD '${DB_PASSWORD}'\" -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}\""

alembic upgrade head
python -m app.seed
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
