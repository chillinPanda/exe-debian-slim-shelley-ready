#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
image=${1:-exe-debian-slim-shelley-ready:dev}
platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image")

test "$(docker image inspect --format '{{index .Config.Labels "exe.dev/install-shelley"}}' "$image")" = true
test "$(docker image inspect --format '{{index .Config.Labels "exe.dev/login-user"}}' "$image")" = exedev

# This temporary container has no network access, injected Shelley, or credentials.
docker run --rm --platform "$platform" --network none --user exedev --shm-size=256m \
    --tmpfs /run/browser:rw,exec,nosuid,nodev,uid=1000,gid=1000,mode=0700,size=320m \
    --hostname image-check --add-host image-check:127.0.0.1 \
    --entrypoint /bin/sh -i "$image" <<'CONTAINER'
set -eu
test "$(id -u)" = 1000
test -w /home/exedev
test -w /home/exedev/.config/shelley
test ! -e /usr/local/bin/shelley
sudo -n true
git --version
headless-shell --version
test -L /etc/systemd/system/sockets.target.wants/shelley.socket
test -L /etc/systemd/system/multi-user.target.wants/exe-setup.service
CONTAINER

# systemd verifies executable paths too. Supply only a disposable validation stub.
docker run --rm --platform "$platform" --network none --entrypoint /bin/sh "$image" -ec '
    printf "#!/bin/sh\nexit 0\n" > /usr/local/bin/shelley
    chmod 755 /usr/local/bin/shelley
    systemd-analyze verify shelley.service shelley.socket exe-setup.service run-browser.mount
'
node "$(dirname "$0")/browser-test.mjs" "$image"
printf 'Image metadata, permissions, browser, and systemd checks passed.\n'
