#!/usr/bin/env bash
# Xodus Nexus Post-Install für Fedora
# Installiert die nötigen Libs (FUSE 2, OpenSSL 3 Kompat, D-Bus) und dann Xodus Nexus.
set -euo pipefail

echo "==> Abhängigkeiten installieren (fuse-libs, openssl3-libs, dbus-libs)"
sudo dnf install -y fuse-libs openssl3-libs dbus-libs

echo "==> Libs prüfen"
for lib in libfuse.so.2 libssl.so.3 libcrypto.so.3 libdbus-1.so.3; do
  if ldconfig -p | grep -q "$lib"; then
    echo "  OK      $lib"
  else
    echo "  FEHLT   $lib" >&2
    exit 1
  fi
done

echo "==> Xodus Nexus installieren"
curl -fsSL https://raw.githubusercontent.com/domsvoboda/xodus-nexus/main/scripts/install.sh | bash

echo "==> Fertig. Im Nexus ggf. 'Install backend' klicken."
