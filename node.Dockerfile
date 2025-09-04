# syntax=docker/dockerfile:1

FROM docker.io/library/alpine:3.22 AS builder
ARG TARGETPLATFORM
ARG RADICLE_VERSION="1.4.0"
ARG RADICLE_SIGNING_IDENTITY="fintan@radicle.xyz"

WORKDIR /artefacts
RUN --mount=type=bind,source=map_target.sh,target=/tmp/map_target.sh --mount=type=bind,source=allowed_signers,target=/tmp/allowed_signers <<-EOF
set -xe
apk add --no-cache curl openssh-keygen
RUST_TARGET="$(sh /tmp/map_target.sh $TARGETPLATFORM)"
RADICLE_ARTEFACT_NAME="radicle-$RADICLE_VERSION-$RUST_TARGET"
curl -LO "https://files.radicle.xyz/releases/latest/$RADICLE_ARTEFACT_NAME.tar.xz"
curl -LO "https://files.radicle.xyz/releases/latest/$RADICLE_ARTEFACT_NAME.tar.xz.sha256"
curl -LO "https://files.radicle.xyz/releases/latest/$RADICLE_ARTEFACT_NAME.tar.xz.sig"

# Verify the integrity of the file
sha256sum -c "$RADICLE_ARTEFACT_NAME.tar.xz.sha256"
rm "$RADICLE_ARTEFACT_NAME.tar.xz.sha256"

# Verify the authenticity of the file
ssh-keygen -Y verify -n file -f "/tmp/allowed_signers" -s "$RADICLE_ARTEFACT_NAME.tar.xz.sig" -I "$RADICLE_SIGNING_IDENTITY" < "$RADICLE_ARTEFACT_NAME.tar.xz"
rm "$RADICLE_ARTEFACT_NAME.tar.xz.sig"

# Rename the artefacts
mv "$RADICLE_ARTEFACT_NAME.tar.xz" "radicle.tar.xz"
EOF

FROM docker.io/library/alpine:3.22
ARG RAD_HOME="/var/lib/radicle"
ARG RAD_NODE_PORT="8776"
VOLUME ["$RAD_HOME"]
EXPOSE "$RAD_NODE_PORT/tcp"
ENV RAD_HOME="$RAD_HOME"
ENV RAD_NODE_PORT="$RAD_NODE_PORT"
ENV RAD_ALIAS=""
ENV RAD_PASSPHRASE=""
ENV RAD_DEFAULT_SEEDING_POLICY="block"
ENV RUST_BACKTRACE="1"
ENV RUST_LOG="info"
RUN --mount=type=bind,from=builder,source=/artefacts/radicle.tar.xz,target=/tmp/radicle.tar.xz <<-EOF
set -xe
addgroup -S -g 10001 radicle
adduser -S -u 10001 -G radicle -h "$RAD_HOME" -g "Radicle Seed Node" -s /bin/sh radicle
apk add --no-cache git uuidgen
tar -xvJf "/tmp/radicle.tar.xz" --strip-components=1 -C /usr/local/
EOF
COPY --link --chmod=0755 docker-entrypoint-node.sh /usr/local/bin/docker-entrypoint.sh
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
