# exe-debian-slim-shelley-ready

A small Debian Slim VM image for [exe.dev](https://exe.dev), with headless
Chromium and automatic Shelley installation by the platform.

## Published image

The [v0.1.0 release](https://github.com/chillinPanda/exe-debian-slim-shelley-ready/releases/tag/v0.1.0)
uses this tested Linux AMD64 image:

```text
ghcr.io/chillinpanda/exe-debian-slim-shelley-ready:build-38796576596-1
```

For VM creation, pin the exact content:

```text
ghcr.io/chillinpanda/exe-debian-slim-shelley-ready@sha256:de5a483e368fd7d6a32c707bd25e8435d8c5caf804cf60e53a1729529bd0b256
```

The image is public and requires no registry login. Follow
[publishing and VM creation](docs/publishing.md#create-a-vm) to create a VM.
See [release verification](docs/releases/v0.1.0.md) for measurements and limits.

## Why this image exists

We want Shelley and its browser tools without a full development workstation
on every VM. The priority is **used VM disk space**, rather than compressed
image download size. Install project-specific runtimes and compilers as needed.

This is an independent community project, not an official exe.dev image.
The supported and tested target is **Linux AMD64**, with 1 CPU and 2 GiB RAM.

## Shelley integration

The image carries `exe.dev/install-shelley="true"`. When a VM starts from this
image, exe.dev installs its current Shelley binary. We do not bundle Shelley.
The label also identifies Shelley support in the VM overview, enabling the
Shelley button. Installing a binary alone does not provide that metadata.
See the [exe.dev image contract](https://exe.dev/docs/customization).

New VMs get the version supplied by exe.dev at creation. This label does not
automatically upgrade existing VMs. The image provides the `exedev` login user,
writable home directory, systemd service/socket, and browser integration.

Use the platform's authenticated Shelley route. The service requires the
`X-Exedev-Userid` header; do not expose its local port 9999 directly.

## What is included

- Debian 13 Slim, apt, systemd, D-Bus, and passwordless sudo for `exedev`.
- One pinned Chromium headless-shell bundle, with software graphics support.
- DejaVu and Noto Color Emoji fonts; full CJK coverage is not included.
- A dpkg-managed minimal Git build from Debian-patched sources.
- Bash, curl, jq, ripgrep, OpenSSH client, certificates, and timezone data.

The runtime has no desktop, compiler, language runtime, or Docker engine.
exe.dev supplies the SSH server. Port 8000 is available for your application.

## Disk and RAM tradeoff

The browser executable stays compressed on disk. First use extracts and
checksums it into a private `/run/browser` tmpfs. Later launches reuse it;
reboot clears it. Version queries do not unpack the executable.

The cache currently uses about **232 MiB RAM**, with a **320 MiB ceiling**.
This limit is not preallocated at boot. Browser processes need additional RAM.
Resources and profiles remain on disk. Conversations, installed tools, logs,
and application data increase disk usage over time.

In the original experiment, the fresh VM used about **331 MiB including Shelley**,
compared with about **841 MiB** for the Debian-browser baseline. These are
individual filesystem observations, not guaranteed sizes for future builds.
See [measurements and verification](docs/measurements.md).

## Build and check

Install Docker with Linux container support and Node.js 22 or newer on the host.
Node is needed only for browser tests.

```sh
docker build --platform linux/amd64 -t shelley-ready:dev .
sh scripts/smoke-test.sh shelley-ready:dev
docker run --rm --platform linux/amd64 --network none --user exedev \
  --entrypoint /bin/sh -i shelley-ready:dev < scripts/git-test.sh
sh scripts/measure.sh shelley-ready:dev
```

On a native AMD64 Docker host, also run `sh scripts/boot-test.sh shelley-ready:dev`.
It starts and removes a temporary privileged container. ARM emulation can run
browser checks, but does not reliably reproduce systemd service isolation.

See [development and tests](docs/development.md) and
[publishing and VM creation](docs/publishing.md). No release image is published
by ordinary checks or scheduled builds.

## Updates

Base and browser images are pinned by digest. Debian packages and Git sources
are resolved at build time, so builds are not bit-for-bit reproducible.
Maintainers must refresh pins, rebuild, and test new images for updates.

`apt-get dist-upgrade` updates Debian runtime packages on existing VMs. It does
**not** update the bundled browser or custom Git build. Rebuild the image for
those updates. Shelley's browser updater replaces the compressed layout with
an unpacked browser and increases disk usage.

Minimal Git omits Perl/Tcl/Python extras and translations. To replace it with
the full Debian package:

```sh
sudo apt-get update
sudo apt-get install git
sudo rm -rf /var/lib/apt/lists/*
```

Automatic apt timers are disabled. Journald has a 32 MiB persistent budget,
a 16 MiB runtime budget, and seven-day retention. Active journal files can
temporarily exceed these limits. Setup scripts must be safe to run repeatedly.

## License

Project build files and scripts use [Apache-2.0](LICENSE). Bundled software
retains its own licenses. See [NOTICE](NOTICE), [licenses](licenses), and
package copyright files inside the image. The `git-sources` build target
exports matching Git source archives and the build recipe. Publish those
sources alongside images containing the custom Git package.
