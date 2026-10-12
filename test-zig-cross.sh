#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Smoke-test a cross-compiled zig under qemu user-mode emulation. Passing means
# the binary runs on the target and its LLVM backend, clang and lld all work:
#   1. `zig version`
#   2. the cross zig builds a zig hello world for its own target; run it
#   3. the cross zig builds a C hello world with `zig cc`; run it
#
# usage: test-zig-cross.sh <target> <cpu>
. ./common.sh
. ./cross-sources.sh

TARGET=${1:?usage: test-zig-cross.sh <target> <cpu>}
MCPU=${2:?usage: test-zig-cross.sh <target> <cpu>}
ZIG_DIR=$ZIG_CROSS_DIR/zig-$TARGET-$MCPU

case "${TARGET%%-*}" in
  powerpc) QEMU_ARCH=ppc;;
  powerpc64) QEMU_ARCH=ppc64;;
  powerpc64le) QEMU_ARCH=ppc64le;;
  x86) QEMU_ARCH=i386;;
  thumb) QEMU_ARCH=arm;;
  *) QEMU_ARCH=${TARGET%%-*};;
esac
QEMU=$(command -v "qemu-$QEMU_ARCH-static" || command -v "qemu-$QEMU_ARCH") || {
  echo "qemu-$QEMU_ARCH(-static) not found; install qemu-user-static" >&2
  exit 1
}

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
# the emulated zig needs its own caches; the host ones hold host artifacts
export ZIG_GLOBAL_CACHE_DIR=$T/global-cache ZIG_LOCAL_CACHE_DIR=$T/local-cache
# qemu's default cpu model for the arch; set QEMU_CPU to pick another (it reads
# QEMU_CPU from the environment itself)
run () { "$QEMU" "$@"; }

set -x
run "$ZIG_DIR/zig" version || exit 1

cat > "$T/hello.zig" <<'EOF'
const std = @import("std");
pub fn main() void {
    std.debug.print("hello from zig\n", .{});
}
EOF
run "$ZIG_DIR/zig" build-exe "$T/hello.zig" -target "$TARGET" -mcpu="$MCPU" -femit-bin="$T/hello-zig" || exit 1
run "$T/hello-zig" 2>&1 | grep -q "hello from zig" || exit 1

cat > "$T/hello.c" <<'EOF'
#include <stdio.h>
int main(void) { puts("hello from c"); return 0; }
EOF
run "$ZIG_DIR/zig" cc "$T/hello.c" -target "$TARGET" -mcpu="$MCPU" -o "$T/hello-c" || exit 1
run "$T/hello-c" | grep -q "hello from c" || exit 1
set +x

echo "Cross zig smoke test passed for $TARGET ($MCPU)"
