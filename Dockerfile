FROM elixir:1.13.4-alpine as build

COPY . .

ENV MIX_ENV=prod

RUN apk add git gcc g++ musl-dev make cmake file-dev &&\
	echo "import Config" > config/prod.secret.exs &&\
	mix local.hex --force &&\
	mix local.rebar --force &&\
	mix deps.get --only prod &&\
	mkdir release &&\
	mix release --path release

FROM alpine:3.16

ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="akkoma" \
    org.opencontainers.image.description="Akkoma for Docker" \
    org.opencontainers.image.vendor="akkoma.dev" \
    org.opencontainers.image.documentation="https://docs.akkoma.dev/stable/" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.url="https://akkoma.dev" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

ARG HOME=/opt/akkoma
ARG DATA=/var/lib/akkoma

RUN apk update &&\
	apk add exiftool ffmpeg imagemagick libmagic ncurses postgresql-client &&\
	adduser --system --shell /bin/false --home ${HOME} akkoma &&\
	mkdir -p ${DATA}/uploads &&\
	mkdir -p ${DATA}/static &&\
	chown -R akkoma ${DATA} &&\
	mkdir -p /etc/akkoma &&\
	chown -R akkoma /etc/akkoma

USER akkoma

COPY --from=build --chown=akkoma:0 /release ${HOME}

COPY ./config/docker.exs /etc/akkoma/config.exs
COPY ./docker-entrypoint.sh ${HOME}

EXPOSE 4000

ENTRYPOINT ["/opt/akkoma/docker-entrypoint.sh"]
