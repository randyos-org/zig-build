#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Download and unpack the upstream devkit for this host (DEVKIT_VERSION in
# common.sh) unless the right version is already in place.
. ./common.sh
. ./env-setup.sh

DEVKIT_ARCHIVE=$DOWNLOADS/$DEVKIT_LONGNAME.$DEVKIT_EXT

[ -x "$DEVKIT_ZIG_EXE" ] && DEVKIT_VER_TMP=$("$DEVKIT_ZIG_EXE" version)
if [ "$DEVKIT_VER_TMP" != "$DEVKIT_VERSION" ]; then
  [ -f "$DEVKIT_ARCHIVE" ] || curl -o "$DEVKIT_ARCHIVE" -fL "https://ziglang.org/deps/$DEVKIT_LONGNAME.$DEVKIT_EXT" || exit 1
  rm -rf "$DEVKIT"
  extract-archive "$DEVKIT_ARCHIVE" "$ZIGROOT" || exit 1
  mv "$ZIGROOT/$DEVKIT_LONGNAME" "$DEVKIT" || exit 1
fi
echo "Devkit ready ($ZIG_HOST_TARGET)"
