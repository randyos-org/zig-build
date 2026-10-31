#!/usr/bin/env bash
#cSpell:enableCompoundWords
set -o pipefail

# Test depth after building stage3/stage4: 0 = quick (test-modules, native
# only), 1 = the full `zig build test`. STAGE3_TESTS=0 skips stage3's tests.
export FULLTESTFLAG=${FULLTESTFLAG:-0}
export STAGE3_TESTS=${STAGE3_TESTS:-1}

# Upstream devkit to bootstrap from. Keep in step with the tarball version in
# zig-src/ci/*.ps1 and ci/*.sh.
# check these versions before running!
# export DEVKIT_VERSION=0.16.0-dev.104+689461e31
# export DEVKIT_VERSION=0.17.0-dev.203+073889523
export DEVKIT_VERSION=0.18.0-dev.92+1e1964473

export NINJA_VERSION=1.13.2
export CMAKE_VERSION=4.3.3
# export ZIG_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DZIG_NO_LIB=ON"
# export ZIG_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo -DZIG_NO_LIB=ON -DCMAKE_VERBOSE_MAKEFILE=ON"
# export ZIG_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo -DZIG_NO_LIB=ON -DZIG_EXTRA_BUILD_ARGS=-j1"
# export ZIG_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo -DZIG_NO_LIB=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DZIG_EXTRA_BUILD_ARGS=--verbose-cc\;--verbose-link\;-fincremental"
export ZIG_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo -DZIG_NO_LIB=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DZIG_EXTRA_BUILD_ARGS=--verbose-cc\;--verbose-link"
# export NINJA_ARGS="-v -d explain"
export NINJA_ARGS="-v"

export ZIG_BUILD_TYPE_DEBUG=
export ZIG_BUILD_TYPE_RELWITHDEBINFO="-Doptimize=ReleaseFast"
export ZIG_BUILD_TYPE_RELEASE="-Doptimize=ReleaseFast -Dstrip"
export ZIG_BUILD_TYPE_MINSIZEREL="-Doptimize=ReleaseSmall"

# export ZIG_BUILD_TYPE="$ZIG_BUILD_TYPE_RELWITHDEBINFO"

# Host toolchain target, named like upstream's devkits (zig-src/ci/*): musl on
# linux, gnu on windows, none on macos and the BSDs. Every stage builds for this
# triple so it matches the devkit's LLVM libs. Override ZIG_HOST_TARGET for an
# unusual host, and set ZIG_HOST_CPU=baseline for binaries that leave this
# machine (CI artifacts); native is fine for local use.
detect-host-target () {
  local arch os
  case "$(uname -m)" in
    x86_64|amd64) arch=x86_64;;
    aarch64|arm64) arch=aarch64;;
    ppc64le) arch=powerpc64le;;
    *) arch=$(uname -m);;
  esac
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) os=windows-gnu;;
    Linux) os=linux-musl;;
    Darwin) os=macos-none;;
    FreeBSD) os=freebsd-none;;
    NetBSD) os=netbsd-none;;
    OpenBSD) os=openbsd-none;;
    *) echo "unsupported host OS: $(uname -s); set ZIG_HOST_TARGET" >&2; return 1;;
  esac
  echo "$arch-$os"
}
if [ -z "$ZIG_HOST_TARGET" ]; then
  ZIG_HOST_TARGET=$(detect-host-target) || exit 1
fi
export ZIG_HOST_TARGET
export ZIG_HOST_CPU=${ZIG_HOST_CPU:-native}

case "$ZIG_HOST_TARGET" in
  *-windows-*) export DEVKIT_EXT=zip EXE_SUFFIX=.exe;;
  *) export DEVKIT_EXT=tar.xz EXE_SUFFIX=;;
esac

# precompute paths and file names
export DEVKIT_LONGNAME=zig+llvm+lld+clang-$ZIG_HOST_TARGET-$DEVKIT_VERSION
export DEVKIT_NAME=devkit-$ZIG_HOST_TARGET-$DEVKIT_VERSION
export CMAKE_NAME=cmake-$CMAKE_VERSION

export ZIGROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
export ZIGROOTBIN=$ZIGROOT/bin

export DOWNLOADS=$ZIGROOT/downloads
export DEVKIT=$ZIGROOT/$DEVKIT_NAME
export CMAKE_DIR=$ZIGROOTBIN/$CMAKE_NAME
export CMAKE_BIN=$CMAKE_DIR/bin

export ZIG_SRC=$ZIGROOT/zig-src
export ZIG_UPSTREAM_URL=https://codeberg.org/ziglang/zig.git
export ZIG_BUILD=$ZIGROOT/build
export ZIG_STAGE3_PREFIX=$ZIGROOTBIN/stage3
export ZIG_STAGE3_BIN=$ZIG_STAGE3_PREFIX/bin
export ZIG_STAGE4_PREFIX=$ZIGROOTBIN/stage4
export ZIG_STAGE4_BIN=$ZIG_STAGE4_PREFIX/bin

export NINJA_EXE=$ZIGROOTBIN/ninja
export CMAKE_EXE=$CMAKE_BIN/cmake
export DEVKIT_ZIG_EXE=$DEVKIT/bin/zig
export ZIG_STAGE3_EXE=$ZIG_STAGE3_BIN/zig
export ZIG_STAGE4_EXE=$ZIG_STAGE4_BIN/zig

# Windows (Git Bash/MSYS)
if command -v cygpath >/dev/null 2>&1; then
  export DEVKIT_ZIG_EXE_WIN="$(cygpath -wa "$DEVKIT_ZIG_EXE")"
  export DEVKIT_ZIG_EXE="$DEVKIT_ZIG_EXE_WIN"
  # native zig.exe cannot open msys /c/... paths; -m keeps forward slashes
  # so config.h stays valid as a C string
  export DEVKIT_WIN="$(cygpath -ma "$DEVKIT")"
fi
# end windows weirdo overrides

export ZLS_SRC=$ZIGROOT/zls
export ZLS_UPSTREAM_URL=https://github.com/zigtools/zls.git
export ZLS_BUILD=$ZIG_BUILD/zls
export ZLS_PREFIX=$ZIGROOTBIN/zls
export ZLS_BIN=$ZLS_PREFIX/bin
export ZLS_EXE=$ZLS_BIN/zls

# :: set PATH to a very minimal set of values to limit bad dependency resolution
# :: I think something in my path on work laptop is polluting dependencies,
# :: probably zlib since that has caused problems for me in the past on this PC
# set WINSYS32=%SystemRoot%\System32
# set PATH=%ZIGROOTBIN_WIN%;%ZIGROOTBIN_WIN%\%CMAKE_NAME%\bin;%WINSYS32%;%SystemRoot%;%WINSYS32%\Wbem;%WINSYS32%\WindowsPowerShell\v1.0\;%WINSYS32%\OpenSSH\;%ProgramFiles%\dotnet\;%LOCALAPPDATA%\Microsoft\WindowsApps;%LOCALAPPDATA%\Programs\Git\bin;%ProgramFiles%\Git\cmd
# export PATH="$ZIG_STAGE3_BIN:$ZIGROOTBIN:$CMAKE_BIN:$PATH"

# Override the cache directories because they won't actually help other Zig runs outside of this repo.
# Runs of this script, however, will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason for other unrelated jobs otherwise.
export ZIG_GLOBAL_CACHE_DIR=$ZIG_BUILD/zig-global-cache
export ZIG_LOCAL_CACHE_DIR=$ZIG_BUILD/zig-local-cache

# Every build command tees its output here so a crash that gives nothing
# but "process exited with code N" can still be picked apart afterward,
# e.g. with rerun-failed-step.sh.
export ZIG_BUILD_LOG_DIR=$ZIG_BUILD/logs
export ZIG_BUILD_LOG="$ZIG_BUILD_LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"

# The zig-src and zls forks carry no release tags, so `git describe` (which
# both build.zig files use for the dev version string) needs upstream's.
# Blobless clones (ci-sources.sh) must keep the filter, but git refuses
# --filter in a full clone.
fetch-upstream-tags () {
  local dir=$1 url=$2 filter=
  git -C "$dir" config --get extensions.partialClone >/dev/null && filter=--filter=blob:none
  git -C "$dir" fetch --quiet $filter --tags "$url"
}

pause () {
  # cmd //c pause
  read -n 1 -s -r -p "Press any key to continue..."
  echo
}

safe-unzip () {
  local zip_file=$1
  local dest_dir=$2
  unzip "$zip_file" -d "$dest_dir"
  local STATUS=$?
  if [ $STATUS -gt 1 ]; then
      echo "Unzip failed with a critical error code: $STATUS"
      exit $STATUS
  fi
}

# upstream ships windows devkits as .zip and everything else as .tar.xz
extract-archive () {
  local archive=$1
  local dest_dir=$2
  case "$archive" in
    *.zip) safe-unzip "$archive" "$dest_dir";;
    *.tar.xz) tar -xJf "$archive" -C "$dest_dir";;
    *) echo "don't know how to extract $archive" >&2; return 1;;
  esac
}
