#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Build ZLS from the zls submodule with stage3, so its std matches stage3/stage4.
. ./common.sh

fetch-upstream-tags "$ZLS_SRC" "$ZLS_UPSTREAM_URL" ||
  echo "warning: could not fetch zls tags; version string may lack the dev suffix" >&2

cd "$ZLS_SRC"
"$ZIG_STAGE3_EXE" build -p "$ZLS_PREFIX" -Doptimize=ReleaseSafe || exit 1
echo Build ZLS complete.
