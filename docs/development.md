# Development and tests

The root Dockerfile defines one supported configuration: compressed Chromium
and minimal Git. `build/git-minimal.sh` builds the Debian-sourced Git package.
`browser/launcher.sh` manages the executable cache. `vm/` contains VM integration.

## Local checks

Run the build and checks from the README. Check shell files with ShellCheck:

```sh
shellcheck build/*.sh scripts/*.sh browser/launcher.sh \
  vm/usr/local/bin/init vm/usr/local/libexec/exe-setup
```

The smoke test checks labels, permissions, systemd unit definitions, browser
JavaScript, keyboard input, mouse clicks, Canvas, WebGL pixels, and screenshots.
Git tests cover commit, branch, merge, rebase, clone, push, worktree, submodule,
archive, PCRE search, garbage collection, and repository integrity.

The native boot test checks systemd, the browser mount, D-Bus, journald, user
services, and browser actions in the booted container. It requires native AMD64
and privileged Docker. Local checks do not install Shelley or make LLM calls.

## Real exe.dev verification

Docker cannot verify platform installation, proxy authentication, or `/dev/vda`
filesystem growth. Use a disposable VM for these checks. Do not restart or
replace a VM holding user work to validate an image change.

Verify automatic Shelley installation, platform metadata, authenticated API,
browser actions through Shelley, Git, restart persistence, and disk/RAM usage.
Check the dashboard button visually before claiming its UI was verified.

The same standalone browser checks can run over SSH:

```sh
node scripts/browser-test.mjs --ssh <ssh_dest> screenshot.png
```

SSH mode also checks HTTPS navigation. Optional `sh scripts/git-test.sh --https`
inside a disposable environment checks public GitHub access.

## Updating dependencies

Update the Debian and browser digest arguments in the Dockerfile deliberately.
Use `docker build --pull --no-cache --platform linux/amd64 ...` to refresh apt
packages and Git sources on a persistent builder. Scheduled CI rebuilds validate
the pinned images; they do not automatically advance either digest.

Keep browser graphics resources and bundled attribution intact. Run the full
checks after dependency changes. Compare actual `df -B1 /` readings on fresh
VMs; local `du` and Docker-reported sizes measure different things.
