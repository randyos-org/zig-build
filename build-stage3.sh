#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Bootstrap a release zig (stage3) from the upstream devkit.
# Extra arguments (e.g. -Dllvm-has-m68k) are passed to both zig builds.
. ./common.sh
. ./env-setup.sh
. ./fetch-devkit.sh

# stage 1 and stage 3 both bake `git describe` into the version string;
# stage4 needs no fetch of its own since it always follows this script
fetch-upstream-tags "$ZIG_SRC" "$ZIG_UPSTREAM_URL" ||
  echo "warning: could not fetch zig tags; version string may lack the dev suffix" >&2

# stage 1: devkit zig builds zig1/zig2
# every stage targets the devkit's triple, like upstream ci passes
# -target/-mcpu to cmake's zig cc (on linux that means musl, not glibc)
cd "$ZIGROOT"
"$DEVKIT_ZIG_EXE" build -p "$ZIGROOT" \
  -Dtarget="$ZIG_HOST_TARGET" \
  -Dcpu="$ZIG_HOST_CPU" \
  $@ \
  || exit 1
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
"$ZIGROOTBIN/zig2$EXE_SUFFIX" build \
  --prefix "$ZIG_STAGE3_PREFIX" \
  $ZIG_BUILD_TYPE_RELWITHDEBINFO \
  -Dtarget="$ZIG_HOST_TARGET" \
  -Dcpu="$ZIG_HOST_CPU" \
  -Duse-zig-libcxx \
  -Dno-lib \
  -Dstatic-llvm \
  --search-prefix "${DEVKIT_WIN:-$DEVKIT}" \
  $@ \
  || exit 1
echo Build stage 3 complete

if [ "$STAGE3_TESTS" = 0 ]; then
  echo "Skipping stage 3 tests (STAGE3_TESTS=0)"
  exit 0
fi
echo Testing stage 3...
if [ "$FULLTESTFLAG" -eq 1 ]; then
  "$ZIG_STAGE3_EXE" build test || exit 1
else
  "$ZIG_STAGE3_EXE" build test-modules -Dskip-release -Dskip-non-native || exit 1
fi
echo Testing stage 3 complete.
