#!/usr/bin/env bash
#cSpell:enableCompoundWords
. ./common.sh
. ./env-setup.sh
. ./build-devkit.sh

# stage 1: devkit zig builds zig1/zig2
cd "$ZIGROOT"
# "$DEVKIT_ZIG_EXE" build -p "$ZIGROOT" --verbose-cc --verbose-link 2>&1 | tee -a "$ZIG_BUILD_LOG" || exit 1
"$DEVKIT_ZIG_EXE" build -p "$ZIGROOT" $@ || exit 1
echo Build stage 2 complete

# stage 2: zig2 builds stage3
# NOTE: -Dstatic-llvm implies -Denable-llvm and makes zig-src/build.zig
# derive its own LLVM/clang/lld linking (recompiles the zig_cpp shim sources
# and links devkit libs by bare name) instead of reading a generated
# config.h -- avoids duplicating that logic outside zig-src. Requires
# --search-prefix so linkSystemLibrary can find devkit/lib/*.lib by name.
# NOTE: If any -Dllvm-has-* experimental target flags (m68k/csky/arc/xtensa)
# were passed in stage 1, pass the same ones here too.
cd "$ZIG_SRC"
"$ZIGROOTBIN/zig2.exe" build \
  --prefix "$ZIG_STAGE3_PREFIX" \
  $ZIG_BUILD_TYPE_RELWITHDEBINFO \
  -Dtarget=native \
  -Dcpu=native \
  -Duse-zig-libcxx \
  -Dno-lib \
  -Dstatic-llvm \
  --search-prefix "${DEVKIT_WIN:-$DEVKIT}" \
  $@ \
  || exit 1
  # "--zig-lib-dir lib" \
  # --verbose-cc --verbose-link 2>&1 | tee -a "$ZIG_BUILD_LOG" \

# zig-src/build.zig hardcodes the exe name "zig"; rename so plain zig stays
# reserved for stage 4.
# mv -f "$ZIGROOTBIN/zig" "$ZIGROOTBIN/zig3" || exit 1
echo Build stage 3 complete

echo Testing stage 3...
if [ "$FULLTESTFLAG" -eq 1 ]; then
  "$ZIG_STAGE3_EXE" build test || exit 1
else
  "$ZIG_STAGE3_EXE" build test-modules -Dskip-release -Dskip-non-native || exit 1
fi
echo Testing stage 3 complete.
