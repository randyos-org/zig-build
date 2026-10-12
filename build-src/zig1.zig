const std = @import("std");

const utils = @import("utils.zig");
const zig_src = utils.zig_src;
const TargetInfo = @import("targets.zig").TargetInfo;

const zig1_cflags = [_][]const u8{
    "-std=c99",
    "-Oz",
    "-fno-strict-aliasing",
};

pub fn genZig1C(b: *std.Build, wasm2c: *std.Build.Step.Compile) std.Build.LazyPath {
    // wasm2c < zig1.wasm > zig1.c
    const gen_zig1c = b.addRunArtifact(wasm2c);
    gen_zig1c.addFileArg(b.path(zig_src ++ "/stage1/zig1.wasm"));
    const zig1_c = gen_zig1c.addOutputFileArg("zig1.c");
    return zig1_c;
}

pub fn buildZig1(b: *std.Build, tgtinfo: TargetInfo, zig1_c: std.Build.LazyPath) *std.Build.Step.Compile {
    const zig1 = utils.cExe(b, tgtinfo, "zig1");
    zig1.stack_size = utils.stack_size;
    b.installArtifact(zig1);

    const zig1_mod = zig1.root_module;
    zig1_mod.addCSourceFile(.{ .file = zig1_c, .flags = &zig1_cflags });
    zig1_mod.addCSourceFile(.{ .file = b.path(zig_src ++ "/stage1/wasi.c"), .flags = &zig1_cflags });
    // cmake links m everywhere except MSVC
    if (tgtinfo.tgt.abi != .msvc) zig1_mod.linkSystemLibrary("m", .{});

    return zig1;
}
