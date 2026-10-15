#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
bundle=/headless-shell
if [ "$#" -eq 1 ] && [ "$1" = --version ]; then
    cat "$bundle/version"
    exit 0
fi
if [ "$(id -u)" -eq 0 ]; then
    exec runuser -u exedev -- "$0" "$@"
fi
cache=/run/browser
if [ ! -d "$cache" ] || [ ! -w "$cache" ] || [ "$(stat -f -c %T "$cache")" != tmpfs ]; then
    echo 'Browser requires the writable /run/browser tmpfs. Start run-browser.mount first.' >&2
    exit 1
fi
version=$(cat "$bundle/binary.sha256")
case "$version" in ''|*[!a-f0-9]*) echo 'Invalid browser cache identity.' >&2; exit 1 ;; esac
cached="$cache/$version"
(
    flock 9
    if [ ! -x "$cached/headless-shell" ]; then
        temporary=$(mktemp -d "$cache/.unpack.XXXXXX")
        trap 'rm -rf "$temporary"' EXIT HUP INT TERM
        zstd --decompress --stdout --quiet "$bundle/headless-shell.zst" > "$temporary/headless-shell"
        printf '%s  %s\n' "$version" "$temporary/headless-shell" | sha256sum --check --status
        chmod 0755 "$temporary/headless-shell" "$temporary"
        for resource in "$bundle"/*; do
            case "$resource" in "$bundle/headless-shell"|"$bundle/headless-shell.zst"|"$bundle/binary.sha256") continue ;; esac
            ln -s "$resource" "$temporary/$(basename "$resource")"
        done
        mv "$temporary" "$cached"
        trap - EXIT HUP INT TERM
    fi
) 9> "$cache/.lock"
exec "$cached/headless-shell" "$@"
