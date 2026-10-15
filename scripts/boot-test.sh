#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
image=${1:-exe-debian-slim-shelley-ready:dev}
image_arch=$(docker image inspect --format '{{.Architecture}}' "$image")
host_arch=$(docker info --format '{{.Architecture}}')
case "$host_arch" in
    aarch64) host_arch=arm64 ;;
    x86_64) host_arch=amd64 ;;
esac
if [ "$image_arch" != "$host_arch" ]; then
    echo "Boot checks require native execution: image=$image_arch, Docker host=$host_arch." >&2
    echo "Use a matching Docker host; emulation does not reliably run systemd service isolation." >&2
    exit 1
fi

container=$(docker run -d --platform "linux/$image_arch" --privileged \
    --cgroupns=private --tmpfs /run --tmpfs /run/lock --network none \
    --hostname image-check --add-host image-check:127.0.0.1 "$image")
trap 'docker rm -f "$container" >/dev/null' EXIT HUP INT TERM

attempt=0
while [ "$attempt" -lt 30 ]; do
    if docker exec "$container" systemctl is-active \
        shelley.socket run-browser.mount dbus.service systemd-journald.service user@1000.service >/dev/null 2>&1; then
        docker exec --user exedev --env XDG_RUNTIME_DIR=/run/user/1000 \
            "$container" timeout 30s systemctl --user is-system-running --wait
        node "$(dirname "$0")/browser-test.mjs" --container "$container"
        printf 'Native systemd boot, Shelley socket, D-Bus, journal, and user services passed.\n'
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 1
done
docker logs "$container" >&2
docker exec "$container" systemctl --failed --no-pager >&2 || true
exit 1
