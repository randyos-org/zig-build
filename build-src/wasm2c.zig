const std = @import("std");

const utils = @import("utils.zig");
const TargetInfo = @import("targets.zig").TargetInfo;

pub fn buildWasm2c(b: *std.Build, tgtinfo: TargetInfo) *std.Build.Step.Compile {
    const wasm2c = utils.cExe(b, tgtinfo, "zig-wasm2c");
    wasm2c.root_module.addCSourceFile(.{
        .file = b.path(utils.zig_src ++ "/stage1/wasm2c.c"),
        .flags = &.{"-std=c99"},
    });
    return wasm2c;
}
