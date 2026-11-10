#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Content keys for the cross pipeline, so CI rebuilds only when an input changes.
#
#   host  stage3 toolchain: zig-src pin, devkit, host triple/cpu, stage1-3 scripts
#   llvm  cross LLVM: devkit (LLVM/libc++ era), zig-bootstrap sources, target/cpu,
#         llvm scripts. Deliberately not the zig-src pin: moving zig-src should
#         rebuild zig, not LLVM.
#   zig   cross zig: llvm key + zig-src pin + target/cpu + zig/test scripts
#
# usage: cross-manifest.sh key <host|llvm|zig> <target> <cpu>   -> prints the key
#        cross-manifest.sh json <target> <cpu>                  -> prints manifest.json
. ./common.sh
. ./cross-sources.sh

sha256 () {
  if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1
  fi
}

# hash of file contents, in a fixed order, independent of checkout path
files-hash () {
  local f
  for f in "$@"; do
    printf '%s\n' "$f"
    cat "$ZIGROOT/$f" || exit 1
  done | sha256
}

# pinned zig-src commit from the index (works without the submodule checked out)
zig-src-pin () { git -C "$ZIGROOT" ls-files -s zig-src | awk '{print $2}'; }

host-key () {
  local scripts
  scripts=$(cd "$ZIGROOT" && ls build.zig build.zig.zon build-src/*.zig common.sh env-setup.sh fetch-devkit.sh build-stage3.sh)
  printf 'host\n%s\n%s\n%s\n%s\n%s\n' "$(zig-src-pin)" "$DEVKIT_VERSION" "$ZIG_HOST_TARGET" "$ZIG_HOST_CPU" \
    "$(files-hash $scripts)" | sha256
}

llvm-key () {
  printf 'llvm\n%s\n%s\n%s\n%s\n%s\n' "$DEVKIT_VERSION" "$ZIG_BOOTSTRAP_COMMIT" "$1" "$2" \
    "$(files-hash build-llvm-cross.sh cross-sources.sh)" | sha256
}

zig-key () {
  printf 'zig\n%s\n%s\n%s\n%s\n%s\n' "$(llvm-key "$1" "$2")" "$(zig-src-pin)" "$1" "$2" \
    "$(files-hash build-zig-cross.sh test-zig-cross.sh)" | sha256
}

case "$1" in
  key)
    case "$2" in
      host) host-key;;
      llvm) llvm-key "${3:?target}" "${4:?cpu}";;
      zig) zig-key "${3:?target}" "${4:?cpu}";;
      *) echo "usage: cross-manifest.sh key <host|llvm|zig> <target> <cpu>" >&2; exit 1;;
    esac
    ;;
  json)
    TARGET=${2:?target}
    MCPU=${3:?cpu}
    cat <<EOF
{
  "zig_build_commit": "$(git -C "$ZIGROOT" rev-parse HEAD)",
  "zig_src_commit": "$(zig-src-pin)",
  "devkit_version": "$DEVKIT_VERSION",
  "zig_bootstrap_commit": "$ZIG_BOOTSTRAP_COMMIT",
  "host_target": "$ZIG_HOST_TARGET",
  "host_cpu": "$ZIG_HOST_CPU",
  "target": "$TARGET",
  "cpu": "$MCPU",
  "host_key": "$(host-key)",
  "llvm_key": "$(llvm-key "$TARGET" "$MCPU")",
  "zig_key": "$(zig-key "$TARGET" "$MCPU")"
}
EOF
    ;;
  *) echo "usage: cross-manifest.sh <key|json> ..." >&2; exit 1;;
esac
