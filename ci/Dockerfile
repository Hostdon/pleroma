ARG TAG
FROM docker.io/hexpm/elixir:${TAG}
RUN apk update
RUN apk add git gcc g++ musl-dev make cmake file-dev rclone wget zip imagemagick ffmpeg perl-image-exiftool exiftool
RUN mkdir /src
WORKDIR /src
