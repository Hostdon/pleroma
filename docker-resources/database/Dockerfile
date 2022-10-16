FROM postgres:14-alpine

ARG UID=1000
ARG GID=1000
ARG UNAME=akkoma

RUN addgroup -g $GID $UNAME
RUN adduser -u $UID -G $UNAME -D -h $HOME $UNAME

USER akkoma
