#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Pinned sources for cross builds (sourced by the cross scripts, after common.sh).
#
# LLVM, Clang, LLD, zlib and zstd come from zig-bootstrap rather than upstream
# llvm-project because zig-bootstrap carries the small patches that make a
# static, zig-cc-driven cross build work (see its readme). Only the sources are
# used; the host zig is our stage3. Keep the LLVM major version in step with
# what zig-src expects (find_package(llvm N) in zig-src/CMakeLists.txt) and the
# devkit (DEVKIT_VERSION in common.sh).

# the GitHub mirror of https://codeberg.org/ziglang/zig-bootstrap, kept by
# zig-devkits' Mirror zig-bootstrap workflow (run it if a new pin is missing)
export ZIG_BOOTSTRAP_URL=${ZIG_BOOTSTRAP_URL:-https://github.com/randyos-org/zig-bootstrap.git}
# LLVM/Clang/LLD 23.1.4, zlib 1.3.1, zstd 1.5.2
export ZIG_BOOTSTRAP_COMMIT=2bceaa4ab64ae87a42ca91658a602b63cbac45b4
export ZIG_BOOTSTRAP_SRC=$ZIG_BUILD/zig-bootstrap-${ZIG_BOOTSTRAP_COMMIT:0:12}

export ZIG_CROSS_DIR=$ZIG_BUILD/cross

# codeberg intermittently answers 5xx; retry network steps a few times
retry () {
  local n
  for n in 1 2 3 4 5; do
    "$@" && return 0
    echo "attempt $n failed: $*" >&2
    sleep $((n * 15))
  done
  return 1
}

fetch-zig-bootstrap () {
  [ -f "$ZIG_BOOTSTRAP_SRC/.fetched" ] && return 0
  rm -rf "$ZIG_BOOTSTRAP_SRC"
  # blobless clone + checkout works for any reachable commit, not just branch tips
  retry git clone --filter=blob:none --no-checkout "$ZIG_BOOTSTRAP_URL" "$ZIG_BOOTSTRAP_SRC" || return 1
  retry git -C "$ZIG_BOOTSTRAP_SRC" checkout --quiet "$ZIG_BOOTSTRAP_COMMIT" || return 1
  touch "$ZIG_BOOTSTRAP_SRC/.fetched"
}

# map a zig target's OS to the CMAKE_SYSTEM_NAME value (same table as zig-bootstrap)
cmake-system-name () {
  local os_abi=${1#*-}
  case "${os_abi%-*}" in
    macos*) echo Darwin;;
    freebsd*) echo FreeBSD;;
    netbsd*) echo NetBSD;;
    openbsd*) echo OpenBSD;;
    windows*) echo Windows;;
    linux*) echo Linux;;
    *) echo "no CMAKE_SYSTEM_NAME for $1" >&2; return 1;;
  esac
}

# the cross scripts drive cmake with `zig cc` and small shell wrappers for
# ar/ranlib, which cmake cannot exec on a windows host
require-posix-host () {
  case "$ZIG_HOST_TARGET" in
    *-windows-*) echo "cross builds need a linux/macos/bsd host (host is $ZIG_HOST_TARGET)" >&2; exit 1;;
  esac
}

require-stage3 () {
  [ -x "$ZIG_STAGE3_EXE$EXE_SUFFIX" ] || [ -x "$ZIG_STAGE3_EXE" ] || {
    echo "stage3 zig not found at $ZIG_STAGE3_EXE; run build-stage3.sh first" >&2
    exit 1
  }
}
