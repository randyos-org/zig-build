#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Prepare a fresh (CI) clone of zig-build for building: fetch the pinned zig-src
# commit without file history blobs, plus upstream's release tags so that
# `git describe` produces proper dev version strings (forks may lack tags).
# Run from the zig-build root. Local checkouts get the tags from build-stage3.sh.
# ZIG_SRC_URL, if set, replaces .gitmodules' zig-src URL for both the commit and
# the tags (e.g. the GitHub mirror https://github.com/randyos-org/zig.git, which
# carries upstream's release tags).
. ./common.sh
. ./cross-sources.sh

tags_url=$ZIG_UPSTREAM_URL
if [ -n "${ZIG_SRC_URL:-}" ]; then
  git -C "$ZIGROOT" submodule init zig-src || exit 1
  git -C "$ZIGROOT" config submodule.zig-src.url "$ZIG_SRC_URL" || exit 1
  tags_url=$ZIG_SRC_URL
fi
retry git -C "$ZIGROOT" submodule update --init --filter=blob:none zig-src || exit 1
retry fetch-upstream-tags "$ZIG_SRC" "$tags_url" || exit 1
echo "zig-src at $(git -C "$ZIG_SRC" describe --match '*.*.*' --tags --abbrev=9)"
