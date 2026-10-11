const std = @import("std");

// const libs = @import("libs.zig");
const libs = @import("libs.zig");
const targets = @import("targets.zig");
const config = @import("config.zig");
const wasm2c_mod = @import("wasm2c.zig");
const zig1_mod = @import("zig1.zig");
const zig2_mod = @import("zig2.zig");
const zigcpp_mod = @import("zigcpp.zig");
const env = @import("env.zig");
const utils = @import("utils.zig");

pub fn build(b: *std.Build) !void {
    const exotic = libs.addExoticTargetOpts(b);
    const tgtinfo = targets.getTargetDetails(b);
    const devkit = env.getDevkitInfo(b);

    // build config file
    const config_zig = try config.genConfigZig(b, exotic);

    // build wasm2c
    const wasm2c = wasm2c_mod.buildWasm2c(b, tgtinfo);

    // convert zig1.wasm to zig1.c using wasm2c
    const zig1_c = zig1_mod.genZig1C(b, wasm2c);

    // compile zig1
    const zig1 = zig1_mod.buildZig1(b, tgtinfo, zig1_c);
    const zig1_done = utils.addAnnounce(b, "zig1 built, generating zig2/compiler_rt sources...");
    zig1_done.dependOn(&zig1.step);

    // run zig1 to convert zig2 and compiler_rt Zig codes to C source files
    const zig2_c = zig2_mod.genZig2C(b, zig1, tgtinfo, config_zig, zig1_done);
    const crt_c = zig2_mod.genCrtC(b, zig1, tgtinfo, zig1_done);

    // build zigcpp static lib (LLVM/clang/lld C++ shims)
    const zigcpp = zigcpp_mod.buildZigCpp(b, tgtinfo, devkit);

    // build zig2
    _ = zig2_mod.buildZig2(b, tgtinfo, zig2_c, crt_c, zigcpp, devkit, exotic);
}
