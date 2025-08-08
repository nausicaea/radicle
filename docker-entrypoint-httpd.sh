#!/bin/sh

set -xe

exec radicle-httpd --listen "0.0.0.0:$RAD_HTTPD_PORT" "$@"
