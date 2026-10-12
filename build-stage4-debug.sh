#!/usr/bin/env bash
#cSpell:enableCompoundWords
ZIGROOT=${ZIGROOT:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)}
. "$ZIGROOT/common.sh"

echo Building stage 4...

cd "$ZIG_SRC"
"$ZIG_STAGE3_EXE" build \
  -p "$ZIG_STAGE4_PREFIX" \
  -Dtarget="$ZIG_HOST_TARGET" \
  -Dcpu="$ZIG_HOST_CPU" \
  -Dstatic-llvm \
  --search-prefix "${DEVKIT_WIN:-$DEVKIT}" \
  -Dno-lib \
  $@ \
  || exit 1
  # -Denable-llvm \

echo Build stage 4 complete, testing...
if [ "$FULLTESTFLAG" -eq 1 ]; then
  "$ZIG_STAGE4_EXE" build test \
    -Dtarget="$ZIG_HOST_TARGET" \
    -Dcpu="$ZIG_HOST_CPU" \
    -Dstatic-llvm \
    --search-prefix "${DEVKIT_WIN:-$DEVKIT}" \
    || exit 1
    # -Denable-llvm \
else
  # "test-std" isn't a real step in this zig-src; the matching one is test-modules
  "$ZIG_STAGE4_EXE" build test-modules -Dskip-release -Dskip-non-native || exit 1
fi

echo Zig debug stage 4 successfully built!
