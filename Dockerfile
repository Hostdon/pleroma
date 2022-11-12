FROM hexpm/elixir:1.13.4-erlang-24.3.4.5-alpine-3.15.6

ENV MIX_ENV=prod

ARG HOME=/opt/akkoma

LABEL org.opencontainers.image.title="akkoma" \
    org.opencontainers.image.description="Akkoma for Docker" \
    org.opencontainers.image.vendor="akkoma.dev" \
    org.opencontainers.image.documentation="https://docs.akkoma.dev/stable/" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.url="https://akkoma.dev" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

RUN apk add git gcc g++ musl-dev make cmake file-dev exiftool ffmpeg imagemagick libmagic ncurses postgresql-client

EXPOSE 4000

ARG UID=1000
ARG GID=1000
ARG UNAME=akkoma

RUN addgroup -g $GID $UNAME
RUN adduser -u $UID -G $UNAME -D -h $HOME $UNAME

WORKDIR /opt/akkoma

USER $UNAME
RUN mix local.hex --force &&\
    mix local.rebar --force

CMD ["/opt/akkoma/docker-entrypoint.sh"]
