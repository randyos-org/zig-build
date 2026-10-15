#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Create the working directories (sourced after common.sh).

mkdir -p "$DOWNLOADS"
mkdir -p "$ZIGROOTBIN"
mkdir -p "$ZIG_BUILD"
# mkdir -p "$ZIG_BUILD_LOG_DIR"
# bin/zig2, bin/zig3, bin/zig find their lib dir by walking ancestors of the
# exe path looking for lib/std/std.zig, so link it at the repo root. The link
# holds a machine-specific path, so it is not tracked in git; (re)create it
# when it is missing or dangling.
if [ ! -f "$ZIGROOT/lib/std/std.zig" ]; then
  rm -f "$ZIGROOT/lib"
  ln -s "$ZIG_SRC/lib" "$ZIGROOT/lib"
fi
true
