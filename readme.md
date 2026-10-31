# zig-build

A collection of scripts to automate building the [Zig](https://ziglang.org) compiler and [ZLS](https://github.com/zigtools/zls) from source. They also cross-compile LLVM and Zig for other targets, which is how the PowerPC builds in [powerzig](https://github.com/emanspeaks/powerzig) are made.

Everything runs from a bash shell: Git Bash/MSYS on Windows, or any Linux, macOS or BSD shell.

## How the bootstrap works

This follows the upstream [build-from-source](https://codeberg.org/ziglang/zig#building-from-source-on-windows) and [contributing](https://codeberg.org/ziglang/zig#editing-source-code) workflow (a release `stage3` plus a debug `stage4` built from it), except that CMake and Ninja are replaced by the Zig build system:

1. **Devkit** (`build-devkit.sh`): download the upstream `zig+llvm+lld+clang` devkit for the host (`DEVKIT_VERSION` in `common.sh`) into `devkit-<triple>-<version>/`.
2. **Stage 1** (`build.zig`, `build-src/`): the devkit's zig builds `wasm2c`, converts `zig-src/stage1/zig1.wasm` to `zig1`, uses `zig1` to generate `zig2.c` and `compiler_rt.c`, and links `zig2` against the devkit's LLVM. This replicates the bootstrap section of `zig-src/CMakeLists.txt`. Output: `bin/zig1`, `bin/zig2`.
3. **Stage 3** (`build-stage3.sh`): `zig2` builds a ReleaseFast zig from `zig-src` with `-Dstatic-llvm` into `bin/stage3/`, then runs a quick test pass.
4. **Stage 4** (`build-stage4-debug.sh`): stage3 builds a debug zig into `bin/stage4/`, then runs tests. Rerun this after editing zig-src.
5. **ZLS** (`build-zls.sh`): stage3 builds the `zls` submodule into `bin/zls/`, so ZLS's std matches the compiler.

Every stage targets the devkit's triple (`ZIG_HOST_TARGET`, autodetected: `x86_64-windows-gnu`, `x86_64-linux-musl`, and so on), so all objects link cleanly against the devkit's LLVM libraries.

## Usage

```sh
./build-all.sh              # stage3, stage4, then ZLS
./build-stage3.sh           # just the bootstrap through stage3
./build-stage4-debug.sh     # rebuild the debug compiler after editing zig-src
./build-zls.sh
```

The `zig-src` and `zls` forks carry no release tags, so `build-stage3.sh` and `build-zls.sh` first fetch upstream tags into their submodule. Without the tags, `git describe` fails, and the version string loses its `-dev.N+hash` suffix. If the fetch fails (when offline, for example), the scripts warn and build anyway.

Extra arguments to `build-stage3.sh` and `build-stage4-debug.sh` are passed to `zig build` (e.g. `-Dllvm-has-m68k` for a devkit built with that experimental target, or `-fincremental --watch` for stage4).

Settings, read from the environment, with defaults in `common.sh`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `ZIG_HOST_TARGET` | autodetected | Triple of the host toolchain and devkit |
| `ZIG_HOST_CPU` | `native` | Use `baseline` for binaries that leave this machine (CI) |
| `STAGE3_TESTS` | `1` | `0` skips stage3's tests |
| `FULLTESTFLAG` | `0` | `1` runs the full `zig build test` instead of `test-modules` |

`.envrc` (for [direnv](https://direnv.net)) puts the devkit, stage3, stage4 and ZLS on `PATH`, and defines `build4`, `watch4` and `web4` aliases for stage4.

The `zig build` caches live in `build/` rather than the user-wide cache. `bin/`, `build/`, `downloads/` and `devkit-*/` are all disposable.

## Cross builds

These scripts need a Linux, macOS or BSD host; Windows is not supported. They also need `cmake`, `ninja` and `git` on `PATH`, and a stage3 zig from `build-stage3.sh`.

| Script | Purpose |
| --- | --- |
| `build-llvm-cross.sh <target> <cpu>` | Cross-compile static LLVM/Clang/LLD, zlib and zstd with stage3 as the C/C++ compiler, from the [zig-bootstrap](https://codeberg.org/ziglang/zig-bootstrap) sources pinned in `cross-sources.sh`. Output: `build/cross/<target>-<cpu>/`. Rerunning resumes; set `CCACHE=ccache` to reuse objects across build dirs. |
| `build-zig-cross.sh <target> <cpu>` | Cross-compile zig-src against that LLVM. Output: `build/cross/zig-<target>-<cpu>/`. |
| `test-zig-cross.sh <target> <cpu>` | Smoke-test the cross zig under qemu user-mode emulation: `zig version`, plus building and running Zig and C hello worlds. |
| `cross-manifest.sh` | Print the content keys (`host`, `llvm`, `zig`) or a `manifest.json` for a target. |
| `ci-sources.sh` | Prepare a fresh CI clone: fetch the pinned zig-src without blobs, plus upstream tags for `git describe`. |

When zig-src moves to a new LLVM major version, bump `ZIG_BOOTSTRAP_COMMIT` in `cross-sources.sh` together with `DEVKIT_VERSION` in `common.sh`.

### CI (powerzig)

The `powerzig-bootstrap` and `powerzig` submodules are GitHub repos whose workflows clone this repo at a commit and run its scripts; all build logic stays here.

- **[Powerzig-bootstrap](https://github.com/emanspeaks/powerzig-bootstrap)** builds stage3 (cached by `host_key`) and then the cross LLVM (split across two jobs that share ccache), and publishes the installation prefix as release `vN`.
- **[powerzig](https://github.com/emanspeaks/powerzig)** waits for an LLVM release with the matching `llvm_key`, cross-compiles zig, smoke-tests it, and publishes it.

Each release carries a `manifest.json`, and a scheduled run is skipped when a release with the same key already exists. The keys hash these inputs:

| Key | Inputs |
| --- | --- |
| `host` | zig-src pin, devkit, host triple/CPU, `build.zig*`, `build-src/`, `common.sh`, `env-setup.sh`, `build-devkit.sh`, `build-stage3.sh` |
| `llvm` | devkit, zig-bootstrap commit, target/CPU, `build-llvm-cross.sh`, `cross-sources.sh` |
| `zig` | `llvm` key, zig-src pin, target/CPU, `build-zig-cross.sh`, `test-zig-cross.sh` |

The `llvm` key deliberately leaves out the zig-src pin, so moving zig-src rebuilds zig but not LLVM. Editing `build-llvm-cross.sh` or `cross-sources.sh`, even just a comment, triggers a full LLVM rebuild of several hours.

## Submodules

| Path | Repo | Notes |
| --- | --- | --- |
| `zig-src` | [emanspeaks/zig](https://codeberg.org/emanspeaks/zig) | `randy` branch: upstream master plus a few branches merged in |
| `zls` | [emanspeaks/zls](https://github.com/emanspeaks/zls) | `randy` branch: upstream master plus fixes needed to build with zig master |
| `powerzig-bootstrap` | [emanspeaks/powerzig-bootstrap](https://github.com/emanspeaks/powerzig-bootstrap) | CI for the cross LLVM |
| `powerzig` | [emanspeaks/powerzig](https://github.com/emanspeaks/powerzig) | CI for the cross Zig |

Submodules are pinned by commit only (no `branch =`). `.gitmodules` uses HTTPS URLs so the repo clones without SSH keys. **If you point a submodule at a commit that lives in a different repo** (for example switching `zig-src` from a fork back to upstream), update its `url` in `.gitmodules` too. Otherwise, a fresh `git clone --recursive` cannot fetch the pinned commit.

When zig-src is updated, check `build-src/` and the stage scripts against upstream `CMakeLists.txt`, `stage1/config.zig.in`, `build.zig` (the LLVM/Clang/LLD library lists) and `ci/` (devkit version), since stage 1 replicates them by hand.
