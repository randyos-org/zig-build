#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Download and unpack this host's devkit (DEVKIT_VERSION from DEVKIT_URL; see
# common.sh) unless the right version is already in place.
. ./common.sh
. ./env-setup.sh

DEVKIT_ARCHIVE=$DOWNLOADS/$DEVKIT_LONGNAME.$DEVKIT_EXT

# sha256 of a file, with whichever tool the host has
sha256-of () {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

[ -x "$DEVKIT_ZIG_EXE" ] && DEVKIT_VER_TMP=$("$DEVKIT_ZIG_EXE" version)
if [ "$DEVKIT_VER_TMP" != "$DEVKIT_VERSION" ]; then
  [ -f "$DEVKIT_ARCHIVE" ] || curl -o "$DEVKIT_ARCHIVE" -fL "$DEVKIT_URL" || exit 1
  if [ -n "$DEVKIT_SHA256" ] && [ "$(sha256-of "$DEVKIT_ARCHIVE")" != "$DEVKIT_SHA256" ]; then
    echo "$DEVKIT_ARCHIVE does not match the sha256 in $DEVKITS_JSON; deleted it, so rerun to download it again" >&2
    rm -f "$DEVKIT_ARCHIVE"
    exit 1
  fi
  rm -rf "$DEVKIT"
  extract-archive "$DEVKIT_ARCHIVE" "$ZIGROOT" || exit 1
  mv "$ZIGROOT/$DEVKIT_LONGNAME" "$DEVKIT" || exit 1
fi
echo "Devkit ready ($ZIG_HOST_TARGET, $DEVKIT_VERSION)"
