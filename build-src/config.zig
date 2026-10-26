const std = @import("std");

const ExperimentalTargets = @import("libs.zig").ExperimentalTargets;
const zig_src = @import("utils.zig").zig_src;

fn cmakeInt(text: []const u8, key: []const u8) usize {
    const i = std.mem.indexOf(u8, text, key) orelse @panic("version constant missing in CMakeLists.txt");
    const rest = text[i + key.len ..];
    const end = std.mem.indexOfScalar(u8, rest, ')') orelse @panic("malformed CMakeLists.txt");
    return std.fmt.parseInt(usize, rest[0..end], 10) catch @panic("bad version int in CMakeLists.txt");
}

// version constants live in zig-src CMakeLists; parse them so nothing is hardcoded here
fn srcVersion(b: *std.Build) !std.SemanticVersion {
    const cwd: std.Io.Dir = .cwd();
    const text = cwd.readFileAlloc(b.graph.io, try b.root.joinString(b.allocator, zig_src ++ "/CMakeLists.txt"), b.allocator, .limited(1 << 20)) catch
        @panic("cannot read " ++ zig_src ++ "/CMakeLists.txt");
    return .{
        .major = cmakeInt(text, "set(ZIG_VERSION_MAJOR "),
        .minor = cmakeInt(text, "set(ZIG_VERSION_MINOR "),
        .patch = cmakeInt(text, "set(ZIG_VERSION_PATCH "),
    };
}

fn resolveVersion(b: *std.Build, sv: std.SemanticVersion) ![]const u8 {
    if (b.option([]const u8, "version-string", "override zig version string")) |v| return v;
    const base = b.fmt("{d}.{d}.{d}", .{ sv.major, sv.minor, sv.patch });
    var code: u8 = undefined;
    const raw = b.runAllowFail(&.{
        "git", "-C", try b.root.joinString(b.allocator, zig_src), "describe", "--match", "*.*.*", "--tags", "--abbrev=9",
    }, &code, .ignore) catch return base;
    const desc = std.mem.trim(u8, raw, " \r\n");
    switch (std.mem.count(u8, desc, "-")) {
        0 => return base, // tagged release
        2 => {
            // untagged dev build: declared version + height + hash, tag itself unused
            var it = std.mem.splitScalar(u8, desc, '-');
            _ = it.first();
            const n = it.next().?;
            const g = it.next().?;
            const hash = if (g.len > 0 and g[0] == 'g') g[1..] else g;
            return b.fmt("{s}-dev.{s}+{s}", .{ base, n, hash });
        },
        else => return base,
    }
}

pub fn genConfigZig(b: *std.Build, x: ExperimentalTargets) !std.Build.LazyPath {
    const version = try resolveVersion(b, try srcVersion(b));
    const content = b.fmt(
        \\pub const have_llvm = true;
        \\pub const llvm_has_m68k = {};
        \\pub const llvm_has_csky = {};
        \\pub const llvm_has_arc = {};
        \\pub const llvm_has_xtensa = {};
        \\pub const version: [:0]const u8 = "{s}";
        \\pub const semver = @import("std").SemanticVersion.parse(version) catch unreachable;
        \\pub const enable_debug_extensions = false;
        \\pub const log_level: @import("std").log.Level = .err;
        \\pub const enable_link_snapshots = false;
        \\pub const enable_tracy = false;
        \\pub const value_tracing = false;
        \\pub const debug_gpa = false;
        \\pub const dev = .core;
        \\pub const io_mode: enum {{ threaded, evented }} = .threaded;
        \\pub const value_interpret_mode = .direct;
        \\
    , .{ x.m68k, x.csky, x.arc, x.xtensa, version });
    const wf = b.addWriteFiles();
    return wf.add("config.zig", content);
}
