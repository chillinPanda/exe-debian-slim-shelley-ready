#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Runs in the disposable Debian builder, with /src as its working directory.
set -eu

apt-get source git
cd git-*/
set -- prefix=/usr/local CFLAGS=-Os LDFLAGS=-s \
    NO_PERL=YesPlease NO_TCLTK=YesPlease NO_PYTHON=YesPlease \
    NO_GETTEXT=YesPlease USE_LIBPCRE2=YesPlease
make -j4 "$@" all
make "$@" DESTDIR=/out install

metadata=/out/usr/share/doc/git-minimal
mkdir -p "$metadata"
cp COPYING debian/copyright "$metadata/"
dpkg-parsechangelog -SVersion > "$metadata/source-version"
apt-get source --print-uris git > "$metadata/source-uris.txt"

deps=$(dpkg-shlibdeps -O /out/usr/local/bin/git \
    /out/usr/local/libexec/git-core/git-remote-http | sed -n 's/^shlibs:Depends=//p')
version=$(cat "$metadata/source-version")
arch=$(dpkg --print-architecture)
size=$(du -sk /out | cut -f1)
mkdir -p /out/DEBIAN
cat > /out/DEBIAN/control <<CONTROL
Package: git-minimal
Version: $version
Architecture: $arch
Installed-Size: $size
Maintainer: exe-debian-slim-shelley-ready contributors
Depends: $deps, openssh-client, ca-certificates
Provides: git (= $version)
Conflicts: git
Replaces: git
Description: Core Git built from Debian sources without Perl, Tcl, or gettext
CONTROL
dpkg-deb --build --root-owner-group /out /git-minimal.deb
