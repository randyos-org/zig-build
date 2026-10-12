# zig-build

A collection of scripts to automate building the [Zig](https://ziglang.org) compiler from source.

The scripts in this repo address cloning the [Zig source repo](https://codeberg.org/ziglang/zig.git) (as a submodule), downloading portable versions of CMake, Ninja, and the Zig LLVM devkit as necessary, and then checks out a known good commit of Zig to do the build.  It also locally sets `$PATH` to a minimal set of values due to issues with other libraries installed on the machine polluting the build.

## Usage

1. Run `build-release-stage3`, which will set up the build environment and produce a release version of the Zig executable.
2. Run `build-debug-stage4` after any local changes to the source to build a debug version of the executable bootstrapped from the release version.

## Submodules

`.gitmodules` uses https URLs so the repo clones without SSH keys. **If you point a submodule at a commit that lives in a different repo** (for example switching `zig-src` from a fork back to upstream), update its `url` in `.gitmodules` too. Otherwise, a fresh `git clone --recursive` cannot fetch the pinned commit.

## Background

There are instructions on the Zig readme for [building from source on Windows](https://codeberg.org/ziglang/zig#building-from-source-on-windows).  These scripts are initially developed to simply codify the steps listed there and ensure repeatability and, perhaps, easing future CI builds or other automation.

Furthermore, this workflow conforms to that described in the [Contributing readme section](https://codeberg.org/ziglang/zig#editing-source-code), which recommends having a stable release build `stage3` version and a `stage4` debug version built from that.

<!-- Tar commands have the additional `-mS` flags added.  This is because I tried to compile on exFAT flash storage, which doesn't fully support POSIX-like file attributes.  The `-m` prevents trying to update the last modified time, while `-S` allows it to handle sparse files more efficiently (which seems to be important due to how the devkit tar file is constructed I suppose; this may not actually be necessary, but did seem to help performance) -->
