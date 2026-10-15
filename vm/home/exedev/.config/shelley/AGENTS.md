# VM environment

This is a minimal Debian 13 VM on exe.dev. The login user is `exedev`,
with passwordless sudo. exe.dev installs Shelley when it creates the VM.

Headless Chromium is already installed. Use `headless-shell` from PATH.
The default image keeps the browser compressed under `/headless-shell` and
extracts its executable to the private `/run/browser` tmpfs on first use.
`run-browser.mount` must be active. Browser version checks do not unpack it.
Do not install another browser or put an unpacked browser copy on disk.
Update the browser by rebuilding the image and creating a new VM.
The upstream Shelley browser updater replaces the compact layout with an
unpacked bundle, increasing persistent disk usage.

Git, Bash, curl, jq, ripgrep, and SSH client tools are available.
Git is a dpkg-managed minimal build from Debian-patched sources. Core Git
workflows are supported; Perl/Tcl/Python extras and translations are omitted.
`sudo apt-get install git` replaces it with the full Debian Git package if needed.
Language runtimes and compilers are deliberately not preinstalled.
Install additional tools only when the task requires them, using
`apt-get install --no-install-recommends` where appropriate. Remove downloaded
apt lists after installing packages to keep disk usage small.

Use systemd for services. User services can use `/run/user/1000` as
XDG_RUNTIME_DIR. Bind application HTTP services to `0.0.0.0:8000` for the
default exe.dev proxy. No placeholder application server is installed.

Preserve Shelley conversations and user files. Diagnose disk growth before
deleting anything. Keep secrets out of repositories, shell output, and images.
