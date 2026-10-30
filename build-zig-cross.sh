#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Cross-compile zig-src for TARGET with stage3, statically linking the LLVM built
# by build-llvm-cross.sh. Same flags as zig-bootstrap's final step.
#
# usage: build-zig-cross.sh <target> <cpu>
# output: $ZIG_CROSS_DIR/zig-<target>-<cpu>  (flat layout: zig + lib/)
. ./common.sh
. ./env-setup.sh
. ./cross-sources.sh

TARGET=${1:?usage: build-zig-cross.sh <target> <cpu>}
MCPU=${2:?usage: build-zig-cross.sh <target> <cpu>}

require-stage3

LLVM_PREFIX=$ZIG_CROSS_DIR/$TARGET-$MCPU
OUT=$ZIG_CROSS_DIR/zig-$TARGET-$MCPU
[ -f "$LLVM_PREFIX/lib/cmake/llvm/LLVMConfig.cmake" ] || {
  echo "no cross LLVM at $LLVM_PREFIX; run build-llvm-cross.sh $TARGET $MCPU first" >&2
  exit 1
}

ZIG_VERSION=$("$ZIG_STAGE3_EXE" version) || exit 1

cd "$ZIG_SRC"
"$ZIG_STAGE3_EXE" build \
  --prefix "$OUT" \
  --search-prefix "${LLVM_PREFIX}" \
  -Dflat \
  -Dstatic-llvm \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dtarget="$TARGET" \
  -Dcpu="$MCPU" \
  -Dversion-string="$ZIG_VERSION" \
  || exit 1

echo "Cross zig ready: $OUT ($ZIG_VERSION)"
