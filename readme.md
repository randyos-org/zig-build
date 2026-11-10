# zig-build

A collection of scripts to automate building the [Zig](https://ziglang.org) compiler and [ZLS](https://github.com/zigtools/zls) from source. They also cross-compile LLVM and Zig for other targets, which is how the PowerPC builds in [powerzig](https://github.com/emanspeaks/powerzig) are made.

Everything runs from a bash shell: Git Bash/MSYS on Windows, or any Linux, macOS or BSD shell.

## How the bootstrap works

This follows the upstream [build-from-source](https://codeberg.org/ziglang/zig#building-from-source-on-windows) and [contributing](https://codeberg.org/ziglang/zig#editing-source-code) workflow (a release `stage3` plus a debug `stage4` built from it), except that CMake and Ninja are replaced by the Zig build system:

1. **Devkit** (`build-devkit.sh`): download the `zig+llvm+lld+clang` devkit for the host into `devkit-<triple>-<version>/`. `devkits.json` in the `zig-devkits` submodule picks it: upstream's devkit at `UPSTREAM_DEVKIT_VERSION` (`common.sh`) from zig-devkits' mirror, checked against its sha256, or, for a host upstream doesn't publish (x86_64-macos), zig-devkits' build. That build may be newer than upstream's devkit, since every host still builds the same zig-src, but not older: `build-devkit.sh` refuses it. Without the submodule, it downloads upstream's from `ziglang.org/deps`.
2. **Stage 1** (`build.zig`, `build-src/`): the devkit's zig builds `wasm2c`, converts `zig-src/stage1/zig1.wasm` to `zig1`, uses `zig1` to generate `zig2.c` and `compiler_rt.c`, and links `zig2` against the devkit's LLVM. This replicates the bootstrap section of `zig-src/CMakeLists.txt`. Output: `bin/zig1`, `bin/zig2`.
3. **Stage 3** (`build-stage3.sh`): `zig2` builds a ReleaseFast zig from `zig-src` with `-Dstatic-llvm` into `bin/stage3/`, then runs a quick test pass.
4. **Stage 4** (`build-stage4-debug.sh`): stage3 builds a debug zig into `bin/stage4/`, then runs tests. Rerun this after editing zig-src.
5. **ZLS** (`build-zls.sh`): stage3 builds the `zls` submodule into `bin/zls/`, so ZLS's std matches the compiler.

**Stage 5** (`build-stage5.sh`, optional): stage3 builds a scratch debug zig from `zig-src-stage5/`, a git worktree of `zig-src`, into that worktree's `zig-out/`. It is for compiler work that must not disturb stage4 while other projects build with it. stage4 is installed with `-Dno-lib`, so it reads `zig-src/lib` live, and editing `zig-src` changes the std its users compile against. stage5 skips LLVM, both linked in and as the backend that compiles it, unless `STAGE5_LLVM=1`, which cuts a rebuild from about fifteen minutes to about one; has its own caches under `build/stage5/`, and adds a hash of the worktree's uncommitted changes to its version string, so the ZIR cache is never shared between builds of the same commit. The script's header has the one-time `git worktree add` and the steps to promote a stable stage5 to stage4.

Every stage targets the devkit's triple (`ZIG_HOST_TARGET`, autodetected: `x86_64-windows-gnu`, `x86_64-linux-musl`, and so on), so all objects link cleanly against the devkit's LLVM libraries.

## Usage

```sh
./build-all.sh              # stage3, stage4, then ZLS
./build-stage3.sh           # just the bootstrap through stage3
./build-stage4-debug.sh     # rebuild the debug compiler after editing zig-src
./build-stage5.sh           # scratch compiler from the zig-src-stage5 worktree
./build-zls.sh
```

The `zls` fork carries no release tags, and the `zig-src` fork's can lag upstream, so `build-stage3.sh` and `build-zls.sh` first fetch upstream tags into their submodule. Without the tags, `git describe` fails, and the version string loses its `-dev.N+hash` suffix. If the fetch fails (when offline, for example), the scripts warn and build anyway.

Extra arguments to `build-stage3.sh` and `build-stage4-debug.sh` are passed to `zig build` (e.g. `-Dllvm-has-m68k` for a devkit built with that experimental target, or `-fincremental --watch` for stage4).

Settings, read from the environment, with defaults in `common.sh`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `ZIG_HOST_TARGET` | autodetected | Triple of the host toolchain and devkit |
| `ZIG_HOST_CPU` | `native` | Use `baseline` for binaries that leave this machine (CI) |
| `DEVKIT_VERSION`, `DEVKIT_URL` | from `devkits.json` | Try another devkit; one already unpacked as `devkit-<triple>-<version>/` needs no URL |
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
| `ci-sources.sh` | Prepare a fresh CI clone: fetch the pinned zig-src without blobs, plus upstream tags for `git describe`, and the pinned `zig-devkits` for `devkits.json`. Set `ZIG_SRC_URL` to fetch both from elsewhere, such as the GitHub mirror `https://github.com/randyos-org/zig.git`, as the GitHub workflows do. |

When zig-src moves to a new LLVM major version, bump `ZIG_BOOTSTRAP_COMMIT` in `cross-sources.sh` together with `UPSTREAM_DEVKIT_VERSION` in `common.sh` and the `zig-devkits` pin, once its mirror holds that version. `cross-sources.sh` fetches zig-bootstrap from its GitHub mirror, [randyos-org/zig-bootstrap](https://github.com/randyos-org/zig-bootstrap) (override with `ZIG_BOOTSTRAP_URL`); if a new pin isn't there yet, run zig-devkits **Mirror zig-bootstrap** workflow by hand.

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

### CI (zig-toolchain)

The `zig-toolchain` submodule, [randyos-org/zig-toolchain](https://github.com/randyos-org/zig-toolchain), builds the zig-src this repo pins natively on each GitHub-hosted runner with `ci-sources.sh` and `build-stage3.sh`, and releases one archive per host as `zig-<version>`; other projects' CI installs it with `randyos-org/zig-toolchain/setup@main`. It runs daily, on its own pushes and by hand, and it skips any host whose `host` key is already released, so moving the zig-src pin (or editing a `host` key input) is what makes a new release. It clones this repo from its GitHub mirror, and zig-src from `randyos-org/zig` (`ZIG_SRC_URL`).

### CI (zig-devkits)

The `zig-devkits` submodule, [randyos-org/zig-devkits](https://github.com/randyos-org/zig-devkits), is the home for devkits: it mirrors upstream devkits from `ziglang.org/deps` as releases, and builds the ones upstream doesn't publish (x86_64-macos) with this repo's cross scripts. `devkits.json` there names the devkit for each host, and `common.sh` reads it at the pinned commit, so a host takes a newer zig-devkits build only when the pin moves (which changes that host's `host` key, so zig-toolchain rebuilds it). Its workflows fetch this repo and zig-src from the GitHub mirrors, as zig-toolchain does.

## Mirrors

Codeberg is the source for this repo and the zig-src fork. Each push-mirrors (over SSH, on every push and every 8 hours) to a read-only GitHub copy: [randyos-org/zig-build](https://github.com/randyos-org/zig-build) and [randyos-org/zig](https://github.com/randyos-org/zig). The fork carries upstream release tags, so the GitHub copy can stand in for upstream when `git describe` needs them; push each new upstream release tag to the fork. Each GitHub copy has a write deploy key titled "codeberg push mirror", and issues, PRs and Actions turned off. Don't push to the GitHub copies directly: the next sync force-pushes over them. Upstream's zig-bootstrap can't be mirrored this way (Codeberg allows no new pull mirrors), so zig-devkits **Mirror zig-bootstrap** workflow pushes it to [randyos-org/zig-bootstrap](https://github.com/randyos-org/zig-bootstrap) nightly instead.

## Submodules

| Path | Repo | Notes |
| --- | --- | --- |
| `zig-src` | [emanspeaks/zig](https://codeberg.org/emanspeaks/zig) | `randy` branch: upstream master plus a few branches merged in |
| `zls` | [emanspeaks/zls](https://github.com/emanspeaks/zls) | `randy` branch: upstream master plus fixes needed to build with zig master |
| `powerzig-bootstrap` | [emanspeaks/powerzig-bootstrap](https://github.com/emanspeaks/powerzig-bootstrap) | CI for the cross LLVM |
| `powerzig` | [emanspeaks/powerzig](https://github.com/emanspeaks/powerzig) | CI for the cross Zig |
| `zig-devkits` | [randyos-org/zig-devkits](https://github.com/randyos-org/zig-devkits) | Devkit mirrors and builds |
| `zig-toolchain` | [randyos-org/zig-toolchain](https://github.com/randyos-org/zig-toolchain) | CI that releases stage3 per host |

`zig-devkits` and `zig-toolchain` are pinned here so that every change to this repo, its scripts or its zig-src pin is committed together with the workflows that consume it. Neither repo's CI reads these pins (both clone this repo's `main` from its GitHub mirror), so after pushing a change to either one, move its pin here in the same zig-build commit as the change it goes with.

Submodules are pinned by commit only (no `branch =`). `.gitmodules` uses HTTPS URLs so the repo clones without SSH keys. **If you point a submodule at a commit that lives in a different repo** (for example switching `zig-src` from a fork back to upstream), update its `url` in `.gitmodules` too. Otherwise, a fresh `git clone --recursive` cannot fetch the pinned commit.

When zig-src is updated, check `build-src/` and the stage scripts against upstream `CMakeLists.txt`, `stage1/config.zig.in`, `build.zig` (the LLVM/Clang/LLD library lists) and `ci/` (devkit version), since stage 1 replicates them by hand.

### What the `randy` branches carry

This is the recipe for rebuilding each `randy` branch from upstream. Keep it in sync with the branches. When upstream merges a PR, drop it from the list. When a merge needs a hand-resolved conflict or a local patch, record it under that entry.

#### Zig-src

Base: [ziglang/zig](https://codeberg.org/ziglang/zig) `master`, merged into `randy` (last: `75d48dfffb`, 2026-11-09, merge `e9e7cf6564`).

| Change | Source | Notes |
| --- | --- | --- |
| std: OS independence day | [#31235](https://codeberg.org/ziglang/zig/pulls/31235), branch `the-os-independence-day` on [GasInfinity/zig](https://codeberg.org/GasInfinity/zig) (`c0533f388a`) | Lets the root module override OS APIs by declaring `std_os_options` (`std.Options.OperatingSystem`). The author force-pushes rebases: when that happens, rebuild `randy` (reset to upstream `master`, then merge the branch again) instead of merging on top of the old copy. Conflict resolution in `lib/std/Io/Dir.zig`: keep the `os_options` override on `max_name_bytes` and upstream OS list (haiku fix `77d692a72e`). |
| ci: enable running SPIR-V behavior tests | [#37168](https://codeberg.org/ziglang/zig/pulls/37168) (`1175625e6d`) | Approved, but conflicts with master. Resolve every conflict to upstream: its compiler changes landed in #37300, and master already has its behavior-test skips as `builtin.cpu.arch.isSpirv()`. What remains is the `-Dspirv-test-runner`/`-Dspirv-test-executor` options, the `spirv64-vulkan` module test target and CI scripts; use `isSpirv` instead of the deprecated `isSpirV` in `test/tests.zig`. Since upstream `f315ecc3aa`, `Run.enableProtocolMode` takes options, so the executor block calls `enableProtocolMode(.{})`. Drop once merged upstream. |
| Fix SPIR-V invalid memory access on small int read/write | [#36741](https://codeberg.org/ziglang/zig/pulls/36741) (`e5a57bfbc3`) + local commit `2ecec6672f` | Upstream review requested changes, so we applied them ourselves. Merge: keep only `getSpirvPtrRwFeatures` in `src/target.zig` (upstream deleted `isDynamicAMDGCNFeature`), and use `Type.fmt(zcu)` and `isSpirv`. Local commit: covers bools, enums, error sets, f16, optionals and error unions; walks tuples and union tags; uses the reviewer's error wording; drops the PR's `int64` requirement for ints wider than 32 bits; formats and extends the tests. Since upstream's `packed`→`bitpack` rename ([#30875](https://codeberg.org/ziglang/zig/pulls/30875)), the struct and union checks in `ensureSpirvPtrRwAllowed` compare against `.@"bitpack"`. Since upstream moved compile-error tests to the new runner (`f0481d974e`), the two tests are `test/errors/spirv_small_int_ptr_missing_{int,storage}_feature`: one `#zig build-obj` block per target with `-fno-llvm`, `bitpack struct`, and `'test.E'` in place of `'tmp.E'`. When `ensureSpirvPtrRwAllowed` (ours) and `analyzeRefDeref` (upstream) conflict in `Sema.zig`, keep both functions. Replace with the upstream version once it lands. |
| Transition: keep `packed` working while 0.17.0 is supported | local commits `9628d06400` (reverts `1f5aeb4d55`), `c7630d2db7` (reverts `44413c1a42`) and `a5bd3dfbf0` (reverts `6fa1827a4c`) | [#30875](https://codeberg.org/ziglang/zig/pulls/30875) renamed `packed` to `bitpack`, made `packed` a parse error, and made `zig fmt` rewrite `packed` to `bitpack`. Zig 0.17.x doesn't know `bitpack`, so code that must build on both 0.17.0 and `randy` has to keep writing `packed`. `9628d06400` reverts the `zig fmt` rewrite in `lib/std/zig/Ast/Render.zig`, so neither `zig fmt` nor ZLS format-on-save converts files. `c7630d2db7` removes the `warnExpected(.keyword_bitpack)` error from `lib/std/zig/Parse.zig`, so `packed` is an alias of `bitpack` again. `a5bd3dfbf0` puts `packed` back into the grammar (`doc/langref/grammar.peg`) and the parser fuzz oracle (`lib/std/zig/parser_generated_oracle.zig`), and drops the `packed keyword` test in `lib/std/zig/parser_fuzz.zig`, which asserts that `packed` is rejected. Not covered: the `std.lang.Type.ContainerLayout` tag is still renamed (`.@"packed"` → `.@"bitpack"`), so reflection code picks the tag with `@hasField(std.lang.Type.ContainerLayout, "bitpack")`. **To back out once 0.17.0 support is dropped:** run `zig fmt` from an upstream zig built after #30875 over every project (rstd, zfls, randyos, …) to turn `packed` into `bitpack`, and switch any `@hasField` layout checks to `.@"bitpack"`. Then revert `a5bd3dfbf0`, `c7630d2db7` and `9628d06400` on `randy` (or leave them out of the next rebuild), and delete this row. |
| Work around LLVM asserting on `f16` to integers wider than 64 bits | local commit `4f79e5a6e9`, [rstd#270](https://github.com/randyos-org/rstd/issues/270) | LLVM 23 asserts (or, without assertions, miscompiles) `fptosi`/`fptoui` from `half` to a type wider than `i64` on x86 CPUs with AVX512-FP16, such as Sapphire and Emerald Rapids ([llvm/llvm-project#230703](https://github.com/llvm/llvm-project/issues/230703)). `zig build` compiles its build runner for the host CPU, so any `zig build` on such a host aborts. In `airIntFromFloat` (`src/codegen/llvm/FuncGen.zig`), x86 converts `f16` to `i64` and then sign- or zero-extends, as LLVM's own fix does; every finite `f16` fits in 64 bits. A behavior test in `test/behavior/cast.zig` covers scalars and vectors. Drop it once the devkit's LLVM has [`c4e841f8ad22`](https://github.com/llvm/llvm-project/commit/c4e841f8ad223cddec936d99f328339bbadb1ece): it isn't in 23.1.4 (zig-bootstrap `2bceaa4ab6`). |

To rebuild from scratch: check out upstream `master`, merge each source above in table order with `--no-ff`, apply the noted resolutions, and cherry-pick the listed local commits.

#### Zig-src `randy-matrix`

A prototype of a builtin matrix type, `@Matrix(rows, cols, T)`, on top of `randy`, following [#4960](https://github.com/ziglang/zig/issues/4960) (accepted for SPIR-V) and [#35376](https://codeberg.org/ziglang/zig/issues/35376). Zig's no-AI policy rules it out as an upstream contribution. It stays a separate branch. When `randy` moves, merge `randy` into it, so that both branches stay buildable.

| Commit | What it adds |
| --- | --- |
| `e7950e99f2` | The type: column-major, columns are `@Vector(rows, T)`, float elements. Coerces to and from `[cols][rows]T` and from tuples of columns. Extern only on SPIR-V. |
| `586f2b9bac` | `m[c]` indexing, `.{ col, col }` init, `.len`, `for` and destructuring, at runtime and comptime. On Vulkan and OpenGL, 2 to 4 columns of 2 to 4 floats lower to `OpTypeMatrix`, with `ColMajor` and `MatrixStride` on the block members holding one; other matrices lower to an array of columns. |
| `db33a6a3f0` | The operators and `@transpose` below, the `matrix_mul` and `matrix_transpose` AIR instructions SPIR-V lowers them from, and `OpCompositeExtract` for comptime-known column indexes. |
| `b5896d765b` | Fused product terms in strict float mode, as `std.Options.Float.fuse_mul_add_bits` allows, defaulting to `std.Target.fusedMulAddBits`. |
| `1ebdf2f8f9` | Merge of `randy` `a5bd3dfbf0` (upstream `75d48dfffb`, the `packed` transition reverts and the `f16` workaround). Upstream's new exhaustive `@typeInfo` switch in `std.mem.Allocator.isInstantiable` lists `.matrix` with `.vector`, and the matrix `elemVal` calls pass the new `indexable_src` argument. In `lib/std/zig.zig` `SimpleComptimeReason`, upstream's `vector_index` comes first, then `matrix_rows`/`matrix_cols`. The `InternPool` prong lists `.type_matrix` with upstream's renamed `.type_struct_bitpack_*` tags. In `Sema.zig`, field access by pointer keeps both the `.matrix` `.len` prong and upstream's new `.vector` `.len` prong ([#37472](https://codeberg.org/ziglang/zig/pulls/37472)). Matrices still go through `elemValArray`, so runtime column indexes work, while vectors take upstream's comptime-index-only `elemValVector`. The three compile-error tests are now `test/errors/matrix_{arithmetic,init_column_count,type_validation}` in the new runner format. |

Operators: `+`, `-` and negation work column by column. `*` multiplies a matrix by a matrix, a vector or a scalar, or a vector by a matrix, and `@transpose(m)` transposes. On `OpTypeMatrix` they lower to SPIR-V's matrix instructions; everywhere else, and at comptime, Sema expands them into vector arithmetic. Products sum in column order. In strict float mode, each product after the first is fused into the running sum where the element type has at most `std.float_options.fuse_mul_add_bits` bits. That defaults to `std.Target.fusedMulAddBits()`, the widest float the target fuses in hardware (0 with MSA on LLVM, which miscompiles vector `fma`). A root overrides it with `pub const std_float_options: std.Options.Float = .{ .fuse_mul_add_bits = 0 };` (0 never fuses, 128 always does); stock std has no `std.Options.Float` and ignores the declaration, so a root that also builds with stock Zig writes `if (@hasDecl(std.Options, "Float")) @as(std.Options.Float, .{ ... }) else {}`. Optimized float mode leaves fusion to the backend, and on SPIR-V the driver decides.

Iterate with `build-stage5.sh` in the `zig-src-stage5` worktree; `rstd/tools/spirv_matrix_probe.zig` in randyos checks the SPIR-V output with `spirv-val`.

#### ZLS

Base: [zigtools/zls](https://github.com/zigtools/zls) `master`, merged into `randy` (last: `066658e2`, 2026-11-09, merge `06c0fbc1`). Conflict resolution in `src/features/completions.zig`: take upstream struct completion-kind fix (`c72bd803`).

| Change | Commit | Notes |
| --- | --- | --- |
| `bitpack` layout tag | `4af86faa` | zig-src's `std.lang.Type.ContainerLayout` tag is `.@"bitpack"` since [#30875](https://codeberg.org/ziglang/zig/pulls/30875), so `DidConfigChange` in `src/configuration.zig` and the `intInfo` assert in `src/analyser/InternPool.zig` use it. Drop once upstream ZLS makes the same change. |
| Parenthesize code action | `baf0bed4` | Adds a code action that inserts parentheses where zig master's partially ordered precedence (`64e4f9db8f`) requires them. The same commit's parentheses in `build.zig`, `InternPool.zig`, `code_actions.zig`, `completions.zig` and `semantic_tokens.zig` are now identical to upstream (`da8d5314`). Randy-only feature. |
| Deprecation detection | `271b0827` | Detects `Deprecated…` doc comments and drives builtin deprecations from data (semantic tokens, completions). Its known-folders bump is now identical to upstream (`15c10aaf`). Randy-only feature. |
| `@Matrix` support | `4792e305`, `763613bb` | Langref entries for `randy-matrix`'s `@Matrix` and `@transpose`, and an inlay-hint table that defaults missing builtins, so ZLS builds against a std with or without them. Randy-only feature. |

Upstream ZLS bans AI-generated contributions (`f8563bab`), so these features aren't candidates to send upstream.
