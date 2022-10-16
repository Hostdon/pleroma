#!/bin/sh

docker-compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g) akkoma
docker-compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g) db
