#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Build a scratch debug zig (stage5) from a separate zig-src worktree with
# stage3, for compiler work that must not disturb stage4 while other projects
# build with it. Extra arguments are passed to the build (e.g. -fincremental
# --watch).
#
# stage4 is installed with -Dno-lib, so it reads zig-src/lib live (through the
# top-level lib symlink); editing zig-src's working tree changes the std that
# stage4's users compile against. stage5 instead builds from
# $ZIG_SRC_STAGE5, a git worktree of zig-src, and installs into its zig-out/,
# where the compiler finds the worktree's own lib/. The build itself also
# takes the worktree's lib/ (--zig-lib), since the compiler's source
# imports std.zig's AstGen, Zir and BuiltinFn from the std it is built with.
#
# One-time setup, at the commit stage4 was built from:
#   git -C zig-src worktree add --detach ../zig-src-stage5 HEAD
#
# The version string carries a hash of the worktree's uncommitted changes, so
# the ZIR cache never reuses ZIR from a different build of the same commit.
#
# To promote a stable stage5 to stage4: commit in the worktree, move zig-src's
# branch to that commit (git -C zig-src merge --ff-only <commit>), then run
# build-stage4-debug.sh.
ZIGROOT=${ZIGROOT:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)}
. "$ZIGROOT/common.sh"

ZIG_SRC_STAGE5=${ZIG_SRC_STAGE5:-$ZIGROOT/zig-src-stage5}
# 1 links LLVM into stage5 and compiles it with the LLVM backend, like stage4.
# The default does neither, which rebuilds in about a minute instead of
# fifteen; it covers the self-hosted backends (-fno-llvm), SPIR-V included.
STAGE5_LLVM=${STAGE5_LLVM:-0}

if [ ! -e "$ZIG_SRC_STAGE5/.git" ]; then
  echo "no zig-src worktree at $ZIG_SRC_STAGE5; create it with:" >&2
  echo "  git -C zig-src worktree add --detach ../zig-src-stage5 HEAD" >&2
  exit 1
fi

# Same format as zig-src/build.zig: <zig_version>-dev.<height>+<commit>.
cd "$ZIG_SRC_STAGE5"
base=$(sed -n 's/^const zig_version.*\.major = \([0-9]*\), \.minor = \([0-9]*\), \.patch = \([0-9]*\).*/\1.\2.\3/p' build.zig)
describe=$(git describe --match '*.*.*' --tags --abbrev=9) || {
  echo "git describe failed; fetch upstream tags into zig-src first" >&2
  exit 1
}
IFS=- read -r _ height commit <<< "$describe"
version="$base-dev.$height+${commit#g}"
dirty=$({
  git diff HEAD --binary
  git ls-files --others --exclude-standard -z | xargs -0 -r sha1sum
} | sha1sum | cut -c1-8)
if [ -n "$(git status --porcelain)" ]; then
  version="$version.stage5-$dirty"
fi

llvm_args=-Duse-llvm=false
if [ "$STAGE5_LLVM" -eq 1 ]; then
  llvm_args="-Dstatic-llvm --search-prefix ${DEVKIT_WIN:-$DEVKIT}"
fi

# Separate caches, so stage5 can be cleared freely without touching stage4's.
export ZIG_GLOBAL_CACHE_DIR=$ZIG_BUILD/stage5/zig-global-cache
export ZIG_LOCAL_CACHE_DIR=$ZIG_BUILD/stage5/zig-local-cache

echo "Building stage 5 ($version)..."

"$ZIG_STAGE3_EXE" build \
  --zig-lib=lib \
  -p zig-out \
  -Dtarget="$ZIG_HOST_TARGET" \
  -Dcpu="$ZIG_HOST_CPU" \
  -Dno-lib \
  -Dversion-string="$version" \
  $llvm_args \
  $@ \
  || exit 1

echo "Zig debug stage 5 built: $ZIG_SRC_STAGE5/zig-out/bin/zig$EXE_SUFFIX"
