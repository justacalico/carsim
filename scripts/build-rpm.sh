#!/usr/bin/env bash
# Package a built Flutter Linux bundle as an RPM.
# Installs to /opt/carsim with a /usr/bin/carsim symlink, matching the deb.
#
# Usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
VERSION="${2:?usage}"
ARCH="${3:?usage}"
OUT="${4:?usage}"
RELEASE="${5:-1}"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "build-rpm: rpmbuild not found (install the rpm package)" >&2
  exit 1
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "build-rpm: bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi

BUNDLE_DIR="$(cd "$BUNDLE_DIR" && pwd)"
RPM_VERSION="$(printf '%s' "$VERSION" | tr '-' '~')"

TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cat > "$TOPDIR/SPECS/carsim.spec" <<'EOF'
Name: carsim
Version: %{pkg_version}
Release: %{pkg_release}%{?dist}
Summary: High-fidelity car simulator
License: AGPL-3.0-only
URL: https://gitlab.com/HttpAnimations/carsim

%global debug_package %{nil}
%global __os_install_post %{nil}
%global __provides_exclude_from ^/opt/carsim/.*

%description
Per-piston engine dynamics, drivetrain, tires, suspension, aerodynamics
and gusty wind, all simulated live.

%install
mkdir -p %{buildroot}/opt/carsim %{buildroot}/usr/bin %{buildroot}/usr/share/applications %{buildroot}/usr/share/icons/hicolor/512x512/apps
cp -a %{bundle_dir}/. %{buildroot}/opt/carsim/
ln -sf /opt/carsim/carsim %{buildroot}/usr/bin/carsim
cat > %{buildroot}/usr/share/applications/carsim.desktop <<'DESKTOP'
[Desktop Entry]
Name=carsim
Exec=carsim
Type=Application
Icon=carsim
Categories=Game;Simulation;
DESKTOP
cp %{icon_path} %{buildroot}/usr/share/icons/hicolor/512x512/apps/carsim.png || true

%files
/opt/carsim
/usr/bin/carsim
/usr/share/applications/carsim.desktop
/usr/share/icons/hicolor/512x512/apps/carsim.png
EOF

rpmbuild -bb \
  --define "pkg_version $RPM_VERSION" \
  --define "pkg_release $RELEASE" \
  --define "bundle_dir $BUNDLE_DIR" \
  --define "icon_path $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/linux/carsim.png" \
  --define "_topdir $TOPDIR" \
  "$TOPDIR/SPECS/carsim.spec"

find "$TOPDIR/RPMS" -name '*.rpm' -exec cp {} "$OUT" \;
echo "RPM written to $OUT"
