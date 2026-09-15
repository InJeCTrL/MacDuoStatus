#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/Duo Status.app"
mkdir -p "$APP/Contents/MacOS"
architectures=("$(uname -m)")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  architectures=(arm64 x86_64)
fi
binaries=()
for arch in "${architectures[@]}"; do
  binary="$PWD/build/DuoStatusIcon-$arch"
  swiftc Sources/*.swift -O -swift-version 5 -target "$arch-apple-macosx13.0" \
    -framework AppKit -framework CoreWLAN -framework IOKit \
    -o "$binary"
  binaries+=("$binary")
done
lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/DuoStatusIcon"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    printf 'VERSION must have the form 1.2.3\n' >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
