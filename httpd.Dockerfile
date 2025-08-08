# syntax=docker/dockerfile:1

FROM docker.io/library/alpine:3.22 AS builder
ARG TARGETPLATFORM
ARG RADICLE_HTTPD_VERSION="0.20.0"
ARG RADICLE_SIGNING_IDENTITY="fintan@radicle.xyz"

WORKDIR /artefacts
RUN --mount=type=bind,source=map_target.sh,target=/tmp/map_target.sh --mount=type=bind,source=allowed_signers,target=/tmp/allowed_signers <<-EOF
set -xe
apk add --no-cache curl openssh-keygen
RUST_TARGET="$(sh /tmp/map_target.sh $TARGETPLATFORM)"
RADICLE_ARTEFACT_NAME="radicle-httpd-$RADICLE_HTTPD_VERSION-$RUST_TARGET"
curl -LO "https://files.radicle.xyz/releases/radicle-httpd/latest/$RADICLE_ARTEFACT_NAME.tar.xz"
curl -LO "https://files.radicle.xyz/releases/radicle-httpd/latest/$RADICLE_ARTEFACT_NAME.tar.xz.sha256"
curl -LO "https://files.radicle.xyz/releases/radicle-httpd/latest/$RADICLE_ARTEFACT_NAME.tar.xz.sig"

# Verify the integrity of the file
sha256sum -c "$RADICLE_ARTEFACT_NAME.tar.xz.sha256"
rm "$RADICLE_ARTEFACT_NAME.tar.xz.sha256"

# Verify the authenticity of the file
ssh-keygen -Y verify -n file -f "/tmp/allowed_signers" -s "$RADICLE_ARTEFACT_NAME.tar.xz.sig" -I "$RADICLE_SIGNING_IDENTITY" < "$RADICLE_ARTEFACT_NAME.tar.xz"
rm "$RADICLE_ARTEFACT_NAME.tar.xz.sig"

# Rename the artefacts
mv "$RADICLE_ARTEFACT_NAME.tar.xz" "radicle-httpd.tar.xz"
EOF

FROM docker.io/library/alpine:3.22
ARG RAD_HOME="/var/lib/radicle"
ARG RAD_HTTPD_PORT="80"
VOLUME ["$RAD_HOME"]
EXPOSE "$RAD_HTTPD_PORT/tcp"
ENV RAD_HOME="$RAD_HOME"
ENV RAD_HTTPD_PORT="$RAD_HTTPD_PORT"
ENV RUST_BACKTRACE="1"
ENV RUST_LOG="info"
RUN --mount=type=bind,from=builder,source=/artefacts/radicle-httpd.tar.xz,target=/tmp/radicle-httpd.tar.xz <<-EOF
set -xe
addgroup -S -g 10001 radicle
adduser -S -u 10001 -G radicle -h "$RAD_HOME" -g "Radicle HTTP Daemon" -s /bin/sh radicle
apk add --no-cache git
tar -xvJf "/tmp/radicle-httpd.tar.xz" --strip-components=1 -C /usr/local/
EOF
COPY --link --chmod=0755 docker-entrypoint-httpd.sh /usr/local/bin/docker-entrypoint.sh
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
