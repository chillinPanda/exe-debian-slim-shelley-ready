# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0
ARG BROWSER_IMAGE=chromedp/headless-shell:stable@sha256:f70908c8020555a3bf89a070140913b443a03ead28c1a66563c3912a3b32b08d
ARG DEBIAN_IMAGE=debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f
FROM ${BROWSER_IMAGE} AS browser
RUN rm -f /headless-shell/libVkLayer_khronos_validation.so /headless-shell/libVkICD_mock_icd.so \
    && /headless-shell/headless-shell --version > /headless-shell/version

FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS browser-pack
RUN apt-get update && apt-get install -y --no-install-recommends zstd
COPY --from=browser /headless-shell/ /headless-shell/
RUN cd /headless-shell \
    && sha256sum headless-shell | cut -d' ' -f1 > binary.sha256 \
    && zstd -T2 -19 --rm headless-shell

FROM ${DEBIAN_IMAGE} AS git-build
RUN sed -i 's/Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential libcurl4-openssl-dev libexpat1-dev zlib1g-dev libssl-dev libpcre2-dev ca-certificates
WORKDIR /src
COPY build/git-minimal.sh /build/git-minimal.sh
RUN sh /build/git-minimal.sh

FROM scratch AS git-sources
COPY --from=git-build /src/git_* /
COPY Dockerfile /build/Dockerfile
COPY build/git-minimal.sh /build/build/git-minimal.sh

FROM ${DEBIAN_IMAGE} AS runtime

LABEL org.opencontainers.image.source="https://github.com/chillinPanda/exe-debian-slim-shelley-ready" \
      org.opencontainers.image.description="Small Debian Slim VM image for exe.dev with headless Chromium and Shelley support" \
      org.opencontainers.image.licenses="Apache-2.0" \
      exe.dev/login-user="exedev" \
      exe.dev/install-shelley="true"

ENV LANG=C.UTF-8

# Runtime packages only. Git is built from Debian-patched sources in a disposable stage.
# Update the base packages too: a digest alone does not provide security updates.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates curl zstd libnspr4 libnss3 libexpat1 libfontconfig1 libuuid1 \
        dbus dbus-user-session fonts-dejavu-core fonts-noto-color-emoji \
        libcurl4t64 libpcre2-8-0 zlib1g iproute2 jq openssh-client ripgrep sudo \
        systemd systemd-sysv tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/sbin/policy-rc.d

RUN --mount=type=bind,from=git-build,source=/git-minimal.deb,target=/tmp/git-minimal.deb \
    printf 'path-include=/usr/share/doc/git-minimal/*\n' > /etc/dpkg/dpkg.cfg.d/git-minimal-docs \
    && dpkg -i /tmp/git-minimal.deb
COPY --from=browser-pack /headless-shell/ /headless-shell/
COPY browser/launcher.sh /headless-shell/headless-shell
RUN chmod 0755 /headless-shell/headless-shell \
    && ln -s /headless-shell/headless-shell /usr/local/bin/headless-shell \
    && chmod -R a+rX /headless-shell

RUN useradd --create-home --uid 1000 --shell /bin/bash exedev \
    && usermod -aG sudo,systemd-journal exedev \
    && printf 'exedev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/exedev \
    && chmod 0440 /etc/sudoers.d/exedev \
    && mkdir -p /home/exedev/.config/shelley /var/lib/systemd/linger \
    && chown -R exedev:exedev /home/exedev \
    && touch /var/lib/systemd/linger/exedev \
    && printf 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"\n' >> /home/exedev/.profile \
    && printf '/dev/vda / ext4 defaults,x-systemd.growfs 0 1\n' > /etc/fstab

COPY vm/ /
COPY LICENSE NOTICE /usr/share/doc/exe-debian-slim-shelley-ready/
COPY licenses/ /usr/share/doc/exe-debian-slim-shelley-ready/licenses/

# exe.dev provides SSH itself. Mask units that conflict with its VM environment.
# Platform integration is adapted from boldsoftware/exeuntu; see NOTICE.
RUN chmod 0755 /usr/local/bin/init /usr/local/libexec/exe-setup \
    && chown -R exedev:exedev /home/exedev \
    && systemctl mask -- \
        getty.target console-getty.service \
        ssh.service ssh.socket systemd-resolved.service \
        systemd-remount-fs.service systemd-sysusers.service \
        systemd-update-done.service systemd-update-utmp.service \
        systemd-journal-catalog-update.service systemd-random-seed.service \
        systemd-modules-load.service modprobe@.service \
        systemd-udevd.service systemd-udevd-control.socket \
        systemd-udevd-kernel.socket systemd-udev-trigger.service \
        systemd-udev-settle.service systemd-hwdb-update.service \
        systemd-ask-password-console.path systemd-ask-password-wall.path \
        apt-daily.timer apt-daily-upgrade.timer \
        -.mount etc-resolv.conf.mount etc-hosts.mount etc-hostname.mount \
    && systemctl disable systemd-firstboot.service systemd-machine-id-commit.service \
    && systemctl set-default multi-user.target \
    && systemctl enable shelley.socket exe-setup.service run-browser.mount \
    && visudo -c \
    && : > /etc/machine-id \
    && ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Port 8000 is reserved for user applications; no placeholder web server runs.
EXPOSE 8000 9999
WORKDIR /home/exedev
CMD ["/usr/local/bin/init"]
