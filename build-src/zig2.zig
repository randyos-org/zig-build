const std = @import("std");

const libs = @import("libs.zig");
const utils = @import("utils.zig");
const zig_src = utils.zig_src;
const TargetInfo = @import("targets.zig").TargetInfo;
const DevkitInfo = @import("env.zig").DevkitInfo;

const zig2_cflags = [_][]const u8{
    "-std=c99",
    "-Oz",
    "-fno-sanitize=undefined",
    "-fno-stack-protector",
    "-fno-strict-aliasing",
    "-D_GNU_SOURCE",
    "-D__STDC_CONSTANT_MACROS",
    "-D__STDC_FORMAT_MACROS",
    "-D__STDC_LIMIT_MACROS",
};

pub fn genZig2C(b: *std.Build, zig1: *std.Build.Step.Compile, tgtinfo: TargetInfo, config_zig: std.Build.LazyPath, wait_on: *std.Build.Step) std.Build.LazyPath {
    const gen_zig2c = b.addRunArtifact(zig1);
    gen_zig2c.step.dependOn(wait_on);
    gen_zig2c.setCwd(b.path(zig_src));
    gen_zig2c.addArg("lib");
    gen_zig2c.addArgs(&.{ "build-exe", "-ofmt=c", "-lc", "-OReleaseSmall", "--name", "zig2" });
    const zig2_c = gen_zig2c.addPrefixedOutputFileArg("-femit-bin=", "zig2.c");
    gen_zig2c.addArgs(&.{ "-target", tgtinfo.triple, "--dep", "build_options", "-Mroot=src/main.zig" });
    gen_zig2c.addPrefixedFileArg("-Mbuild_options=", config_zig);
    return zig2_c;
}

pub fn genCrtC(b: *std.Build, zig1: *std.Build.Step.Compile, tgtinfo: TargetInfo, wait_on: *std.Build.Step) std.Build.LazyPath {
    const gen_crt = b.addRunArtifact(zig1);
    gen_crt.step.dependOn(wait_on);
    gen_crt.setCwd(b.path(zig_src));
    gen_crt.addArg("lib");
    gen_crt.addArgs(&.{ "build-obj", "-ofmt=c", "-lc", "-OReleaseSmall", "--name", "compiler_rt" });
    const crt_c = gen_crt.addPrefixedOutputFileArg("-femit-bin=", "compiler_rt.c");
    gen_crt.addArgs(&.{ "-target", tgtinfo.triple, "-Mroot=lib/compiler_rt.zig" });
    return crt_c;
}

pub fn buildZig2(
    b: *std.Build,
    tgtinfo: TargetInfo,
    zig2_c: std.Build.LazyPath,
    crt_c: std.Build.LazyPath,
    zigcpp: *std.Build.Step.Compile,
    devkit: DevkitInfo,
    exotic: libs.ExperimentalTargets,
) *std.Build.Step.Compile {
    const tgt = tgtinfo.tgt;

    const zig2 = utils.cExe(b, tgtinfo, "zig2");
    b.installArtifact(zig2);

    const zig2_mod = zig2.root_module;

    // source files
    zig2_mod.addIncludePath(b.path(utils.zig_src ++ "/stage1"));
    zig2_mod.addIncludePath(devkit.devkit_inc);
    zig2_mod.addCSourceFile(.{ .file = zig2_c, .flags = &zig2_cflags });
    zig2_mod.addCSourceFile(.{ .file = crt_c, .flags = &zig2_cflags });

    // linking
    zig2_mod.link_libcpp = true;
    zig2_mod.linkLibrary(zigcpp);
    if (tgt.os.tag == .windows) {
        zig2_mod.linkSystemLibrary("ntdll", .{});
        zig2_mod.linkSystemLibrary("ws2_32", .{});
        zig2_mod.linkSystemLibrary("version", .{});
        zig2_mod.linkSystemLibrary("uuid", .{});
        zig2_mod.linkSystemLibrary("ole32", .{});
    }
    libs.addDevkitLibs(b, tgtinfo, zig2_mod, devkit, exotic);
    return zig2;
}
