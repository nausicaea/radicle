#!/bin/sh

set -xe

# Create a radicle identity (or do nothing if one exists already)
if ! rad self --alias 2>&1 > /dev/null; then
    if [ -n "$RAD_ALIAS" ]; then
        rad auth --alias "$RAD_ALIAS"
    else
        RA="$(uuidgen -6 | sed -e 's/-//g' | tail -c32)"
        rad auth --alias "$RA"
    fi
fi

exec rad "$@"
