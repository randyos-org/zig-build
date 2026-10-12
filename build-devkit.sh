#!/usr/bin/env bash
#cSpell:enableCompoundWords
. ./common.sh
. ./env-setup.sh

DEVKIT_ARCHIVE=$DOWNLOADS/$DEVKIT_LONGNAME.$DEVKIT_EXT

# devkits used to unpack to devkit-$DEVKIT_VERSION (windows only); adopt one
# instead of downloading it again
LEGACY_DEVKIT=$ZIGROOT/devkit-$DEVKIT_VERSION
if [ ! -d "$DEVKIT" ] && [ -d "$LEGACY_DEVKIT" ] && [ "$ZIG_HOST_TARGET" = x86_64-windows-gnu ]; then
  mv "$LEGACY_DEVKIT" "$DEVKIT" || exit 1
fi

[ -x "$DEVKIT_ZIG_EXE" ] && DEVKIT_VER_TMP=$("$DEVKIT_ZIG_EXE" version)
if [ "$DEVKIT_VER_TMP" != "$DEVKIT_VERSION" ]; then
  [ -f "$DEVKIT_ARCHIVE" ] || curl -o "$DEVKIT_ARCHIVE" -fL "https://ziglang.org/deps/$DEVKIT_LONGNAME.$DEVKIT_EXT" || exit 1
  rm -rf "$DEVKIT"
  extract-archive "$DEVKIT_ARCHIVE" "$ZIGROOT" || exit 1
  mv "$ZIGROOT/$DEVKIT_LONGNAME" "$DEVKIT" || exit 1
fi
echo "Devkit ready ($ZIG_HOST_TARGET)"
