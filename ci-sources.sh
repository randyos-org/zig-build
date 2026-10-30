#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Prepare a fresh (CI) clone of zig-build for building: fetch the pinned zig-src
# commit without file history blobs, plus upstream's release tags so that
# `git describe` produces proper dev version strings (forks may lack tags).
# Run from the zig-build root. Local checkouts already have all of this.
. ./common.sh
. ./cross-sources.sh

retry git -C "$ZIGROOT" submodule update --init --filter=blob:none zig-src || exit 1
retry git -C "$ZIG_SRC" fetch --quiet --filter=blob:none --tags \
  https://codeberg.org/ziglang/zig.git || exit 1
echo "zig-src at $(git -C "$ZIG_SRC" describe --match '*.*.*' --tags --abbrev=9)"
