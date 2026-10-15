# Publishing and VM creation

## Release checks

Before publishing, review changes and run the image workflow successfully on
GitHub. Local tests and real VM observations do not establish GitHub CI status.
Record the commit, build identifier, image digest, and matching Git source tag.
Use the image digest when creating a VM; mutable tags can be cached.

The workflow checks pull requests, main, weekly builds, and manual runs.
Only a manual run on `main` with `publish` selected can publish to GHCR.
The publishing job receives package write permission after checks pass.
It loads the exact tested image and corresponding source image from artifacts;
it does not rebuild them during publication.

Tags are `build-<run>-<attempt>`, `git-sources-build-<run>-<attempt>`, and `latest`.
A build tag identifies a particular run; the digest identifies its content.
The same commit can resolve newer Debian packages on another build.

## Corresponding Git sources

The `git-sources` target contains Debian source archives, the Dockerfile, and
the Git build script. Export from the same cached build that produced the image:

```sh
docker build --platform linux/amd64 --target git-sources \
  --output type=local,dest=.artifacts/git-sources .
```

Do not refresh apt inputs between the runtime and source builds. Retain source
artifacts and make them available alongside every distributed runtime build.
CI uploads the exported sources for seven days and publishes a paired source
image when asked. The temporary tested-image transfer artifact expires after
one day. Published registry images and paired sources have no automatic expiry.
For public distribution, ensure both registry packages and sources are accessible.

## Create a VM

Publish and make the image accessible before using the exe.dev HTTPS API.
The example assumes an existing local API token. Keep it on your own machine.
Replace the image digest and choose an available VM name:

```sh
curl -fsS https://exe.dev/exec \
  -H "Authorization: Bearer $(cat ~/.config/exe.dev/token)" \
  --data-raw 'new --name=shelley-slim --cpu=1 --memory=2GB --disk=10GB --image=ghcr.io/chillinpanda/exe-debian-slim-shelley-ready@sha256:<digest>'
```

Verify the returned VM name and `ssh_dest`. Connect using that SSH destination.
Open Shelley from the VM overview or the returned `shelley_url`.
Disk capacity and used disk space are different measurements.
