const std = @import("std");
const TargetInfo = @import("targets.zig").TargetInfo;

// zig source submodule root, relative to zig-build's build.zig
pub const zig_src = "zig-src";

// zig1 stack size; CMakeLists sets it with /STACK or -Wl,--stack on windows.
pub const stack_size = 0x10000000;

pub fn cExe(b: *std.Build, tgtinfo: TargetInfo, name: []const u8) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{ .target = tgtinfo.resolved, .optimize = .ReleaseFast, .link_libc = true }),
    });
}

// no-op barrier step named `message` (shown in build progress); wire deps with
// .dependOn so it lands at an exact point in the graph instead of racing other
// steps. split-phase std.Build has no custom makeFn, so an empty WriteFile
// stands in for a step that printed at make time.
pub fn addAnnounce(b: *std.Build, message: []const u8) *std.Build.Step {
    const wf = b.addWriteFiles();
    wf.step.name = message;
    return &wf.step;
}
