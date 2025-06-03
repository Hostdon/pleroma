#!/bin/ash

set -e

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:5432/${DB_NAME:-pleroma} -t 1; do
    sleep 1s
done

echo "-- Running migrations..."
mix ecto.migrate

echo "-- Starting!"
elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none" -S mix phx.server
