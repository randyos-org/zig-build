#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Cross-compile LLVM, Clang, LLD, zlib and zstd as static libs for TARGET, using
# stage3 as the C/C++ compiler. Mirrors zig-bootstrap's `build` script (minus
# its host LLVM/zig stages, which stage3 replaces). Re-running resumes: ninja
# skips finished work, and CCACHE=ccache lets a fresh build dir reuse objects.
#
# usage: build-llvm-cross.sh <target> <cpu>   e.g. powerpc-linux-musleabihf baseline
# output: $ZIG_CROSS_DIR/<target>-<cpu>  (install prefix for zig's -Dstatic-llvm)
. ./common.sh
. ./env-setup.sh
. ./cross-sources.sh

TARGET=${1:?usage: build-llvm-cross.sh <target> <cpu>}
MCPU=${2:?usage: build-llvm-cross.sh <target> <cpu>}

require-posix-host
require-stage3
for tool in cmake ninja git; do
  command -v $tool >/dev/null || { echo "$tool not found on PATH" >&2; exit 1; }
done
fetch-zig-bootstrap || exit 1

ZIG=$ZIG_STAGE3_EXE
SRC=$ZIG_BOOTSTRAP_SRC
WORK=$ZIG_CROSS_DIR/work-$TARGET-$MCPU
PREFIX=$ZIG_CROSS_DIR/$TARGET-$MCPU
SYSTEM_NAME=$(cmake-system-name "$TARGET") || exit 1
mkdir -p "$WORK" "$PREFIX"

# ar/ranlib via zig itself, so no host binutils or prebuilt llvm-ar is needed
TOOLS=$WORK/tools
mkdir -p "$TOOLS"
for tool in ar ranlib; do
  printf '#!/bin/sh\nexec "%s" %s "$@"\n' "$ZIG" "$tool" > "$TOOLS/$tool"
  chmod +x "$TOOLS/$tool"
done

LAUNCHER=()
if [ -n "$CCACHE" ]; then
  # ccache cannot identify `zig cc` on its own
  export CCACHE_COMPILERTYPE=clang
  LAUNCHER=(-DCMAKE_C_COMPILER_LAUNCHER="$CCACHE" -DCMAKE_CXX_COMPILER_LAUNCHER="$CCACHE")
fi

cross_cc () { echo "$ZIG;$1;-fno-sanitize=all;-s;-target;$TARGET;-mcpu=$MCPU"; }

# 1. native llvm-tblgen + clang-tblgen (only these two targets, not all of LLVM).
# Same options as zig-bootstrap's host stage: its sources have unused files
# deleted (e.g. llvm/utils/*), so anything referencing them must stay off.
HOST_TBLGEN=$WORK/build-tblgen-host
cmake -S "$SRC/llvm" -B "$HOST_TBLGEN" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$ZIG_HOST_TARGET;-mcpu=$ZIG_HOST_CPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$ZIG_HOST_TARGET;-mcpu=$ZIG_HOST_CPU" \
  -DCMAKE_ASM_COMPILER="$ZIG;cc;-target;$ZIG_HOST_TARGET;-mcpu=$ZIG_HOST_CPU" \
  -DCMAKE_AR="$TOOLS/ar" \
  -DCMAKE_RANLIB="$TOOLS/ranlib" \
  "${LAUNCHER[@]}" \
  -DLLVM_APPEND_VC_REV=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  || exit 1
cmake --build "$HOST_TBLGEN" --target llvm-tblgen clang-tblgen || exit 1

# 2. zlib
cmake -S "$SRC/zlib" -B "$WORK/build-zlib" -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$SYSTEM_NAME" \
  -DCMAKE_C_COMPILER="$(cross_cc cc)" \
  -DCMAKE_CXX_COMPILER="$(cross_cc c++)" \
  -DCMAKE_ASM_COMPILER="$(cross_cc cc)" \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_AR="$TOOLS/ar" \
  -DCMAKE_RANLIB="$TOOLS/ranlib" \
  "${LAUNCHER[@]}" \
  || exit 1
cmake --build "$WORK/build-zlib" --target install || exit 1

# 3. zstd (zig-bootstrap builds it directly; its build system is unwieldy)
if [ ! -f "$PREFIX/lib/libzstd.a" ]; then
  mkdir -p "$PREFIX/include" "$PREFIX/lib"
  cp "$SRC/zstd/lib/zstd.h" "$PREFIX/include/zstd.h" || exit 1
  ZSTD=$SRC/zstd/lib
  (cd "$PREFIX/lib" && "$ZIG" build-lib \
    --name zstd \
    -target "$TARGET" \
    -mcpu="$MCPU" \
    -fno-sanitize-c -fstrip -OReleaseFast \
    -lc \
    "$ZSTD/decompress/zstd_ddict.c" \
    "$ZSTD/decompress/zstd_decompress.c" \
    "$ZSTD/decompress/huf_decompress.c" \
    "$ZSTD/decompress/huf_decompress_amd64.S" \
    "$ZSTD/decompress/zstd_decompress_block.c" \
    "$ZSTD/compress/zstdmt_compress.c" \
    "$ZSTD/compress/zstd_opt.c" \
    "$ZSTD/compress/hist.c" \
    "$ZSTD/compress/zstd_ldm.c" \
    "$ZSTD/compress/zstd_fast.c" \
    "$ZSTD/compress/zstd_compress_literals.c" \
    "$ZSTD/compress/zstd_double_fast.c" \
    "$ZSTD/compress/huf_compress.c" \
    "$ZSTD/compress/fse_compress.c" \
    "$ZSTD/compress/zstd_lazy.c" \
    "$ZSTD/compress/zstd_compress.c" \
    "$ZSTD/compress/zstd_compress_sequences.c" \
    "$ZSTD/compress/zstd_compress_superblock.c" \
    "$ZSTD/deprecated/zbuff_compress.c" \
    "$ZSTD/deprecated/zbuff_decompress.c" \
    "$ZSTD/deprecated/zbuff_common.c" \
    "$ZSTD/common/entropy_common.c" \
    "$ZSTD/common/pool.c" \
    "$ZSTD/common/threading.c" \
    "$ZSTD/common/zstd_common.c" \
    "$ZSTD/common/xxhash.c" \
    "$ZSTD/common/debug.c" \
    "$ZSTD/common/fse_decompress.c" \
    "$ZSTD/common/error_private.c" \
    "$ZSTD/dictBuilder/zdict.c" \
    "$ZSTD/dictBuilder/divsufsort.c" \
    "$ZSTD/dictBuilder/fastcover.c" \
    "$ZSTD/dictBuilder/cover.c" \
  ) || exit 1
fi

# 4. LLVM + Clang + LLD (all default, non-experimental targets)
cmake -S "$SRC/llvm" -B "$WORK/build-llvm" -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING=True \
  -DCMAKE_SYSTEM_NAME="$SYSTEM_NAME" \
  -DCMAKE_C_COMPILER="$(cross_cc cc)" \
  -DCMAKE_CXX_COMPILER="$(cross_cc c++)" \
  -DCMAKE_ASM_COMPILER="$(cross_cc cc)" \
  -DCMAKE_LINK_DEPENDS_USE_LINKER=OFF \
  -DCMAKE_AR="$TOOLS/ar" \
  -DCMAKE_RANLIB="$TOOLS/ranlib" \
  "${LAUNCHER[@]}" \
  -DLLVM_APPEND_VC_REV=OFF \
  -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_CRASH_OVERRIDES=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_ZLIB=FORCE_ON \
  -DLLVM_ENABLE_ZSTD=FORCE_ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -DLLVM_TABLEGEN="$HOST_TBLGEN/bin/llvm-tblgen" \
  -DLLVM_BUILD_UTILS=OFF \
  -DLLVM_BUILD_TOOLS=OFF \
  -DLLVM_BUILD_STATIC=ON \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET" \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DCLANG_TABLEGEN="$HOST_TBLGEN/bin/clang-tblgen" \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF \
  -DCLANG_ENABLE_OBJC_REWRITER=ON \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  -DLLD_BUILD_TOOLS=OFF \
  || exit 1
cmake --build "$WORK/build-llvm" --target install || exit 1

echo "Cross LLVM ready: $PREFIX"
