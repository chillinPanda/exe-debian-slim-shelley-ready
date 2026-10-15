#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
image=${1:-exe-debian-slim-shelley-ready:dev}
platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image")
docker image inspect --format 'Docker-reported image size (bytes; storage-driver dependent): {{.Size}}' "$image"
docker run --rm --platform "$platform" --network none --entrypoint /bin/sh "$image" -ec '
    echo "Filesystem contents (KiB; not an exe.dev disk-usage measurement):"
    du -xsk / 2>/dev/null
    echo "Largest installed packages (KiB):"
    dpkg-query -W -f="\${Installed-Size}\t\${Package}\n" | sort -nr | head -15
'
