const std = @import("std");

const TargetInfo = @import("targets.zig").TargetInfo;
const DevkitInfo = @import("env.zig").DevkitInfo;

pub const clang = [_][]const u8{
    "clangFrontendTool",
    "clangCodeGen",
    "clangStaticAnalyzerFrontend",
    "clangStaticAnalyzerCheckers",
    "clangStaticAnalyzerCore",
    "clangCrossTU",
    "clangDriver",
    "clangScalableStaticAnalysisAnalyses",
    "clangScalableStaticAnalysisCore",
    "clangScalableStaticAnalysisFrontend",
    "clangScalableStaticAnalysisSourceTransformation",
    "clangDependencyScanning",
    "clangFrontend",
    "clangOptions",
    "clangSerialization",
    "clangSema",
    "clangAnalysisLifetimeSafety",
    "clangAnalysis",
    "clangASTMatchers",
    "clangParse",
    "clangAPINotes",
    "clangEdit",
    "clangUnifiedSymbolResolution",
    "clangLex",
    "clangRewriteFrontend",
    "clangRewrite",
    "clangIndex",
    "clangFormat",
    "clangToolingInclusions",
    "clangToolingCore",
    "clangExtractAPI",
    "clangSupport",
    "clangInstallAPI",
    "clangAST",
    "clangBasic",
};

pub const lld = [_][]const u8{
    "lldMinGW",
    "lldELF",
    "lldCOFF",
    "lldWasm",
    "lldMachO",
    "lldCommon",
};

// regen with `llvm-config --libfiles`, omit LLVMTableGen.
// keep in sync with llvm_libs in zig-src/build.zig.
pub const llvm = [_][]const u8{
    "LLVMWindowsManifest",
    "LLVMXRay",
    "LLVMLibDriver",
    "LLVMDlltoolDriver",
    "LLVMTelemetry",
    "LLVMTextAPIBinaryReader",
    "LLVMCoverage",
    "LLVMLineEditor",
    "LLVMXCoreDisassembler",
    "LLVMXCoreCodeGen",
    "LLVMXCoreDesc",
    "LLVMXCoreInfo",
    "LLVMX86TargetMCA",
    "LLVMX86Disassembler",
    "LLVMX86AsmParser",
    "LLVMX86CodeGen",
    "LLVMX86Desc",
    "LLVMX86Info",
    "LLVMWebAssemblyDisassembler",
    "LLVMWebAssemblyAsmParser",
    "LLVMWebAssemblyCodeGen",
    "LLVMWebAssemblyUtils",
    "LLVMWebAssemblyDesc",
    "LLVMWebAssemblyInfo",
    "LLVMVEDisassembler",
    "LLVMVEAsmParser",
    "LLVMVECodeGen",
    "LLVMVEDesc",
    "LLVMVEInfo",
    "LLVMSystemZDisassembler",
    "LLVMSystemZAsmParser",
    "LLVMSystemZCodeGen",
    "LLVMSystemZDesc",
    "LLVMSystemZInfo",
    "LLVMSPIRVCodeGen",
    "LLVMSPIRVDesc",
    "LLVMSPIRVInfo",
    "LLVMSPIRVAnalysis",
    "LLVMSparcDisassembler",
    "LLVMSparcAsmParser",
    "LLVMSparcCodeGen",
    "LLVMSparcDesc",
    "LLVMSparcInfo",
    "LLVMRISCVTargetMCA",
    "LLVMRISCVDisassembler",
    "LLVMRISCVAsmParser",
    "LLVMRISCVCodeGen",
    "LLVMRISCVDesc",
    "LLVMRISCVInfo",
    "LLVMPowerPCDisassembler",
    "LLVMPowerPCAsmParser",
    "LLVMPowerPCCodeGen",
    "LLVMPowerPCDesc",
    "LLVMPowerPCInfo",
    "LLVMNVPTXCodeGen",
    "LLVMNVPTXDesc",
    "LLVMNVPTXInfo",
    "LLVMMSP430Disassembler",
    "LLVMMSP430AsmParser",
    "LLVMMSP430CodeGen",
    "LLVMMSP430Desc",
    "LLVMMSP430Info",
    "LLVMMipsDisassembler",
    "LLVMMipsAsmParser",
    "LLVMMipsCodeGen",
    "LLVMMipsDesc",
    "LLVMMipsInfo",
    "LLVMLoongArchDisassembler",
    "LLVMLoongArchAsmParser",
    "LLVMLoongArchCodeGen",
    "LLVMLoongArchDesc",
    "LLVMLoongArchInfo",
    "LLVMLanaiDisassembler",
    "LLVMLanaiCodeGen",
    "LLVMLanaiAsmParser",
    "LLVMLanaiDesc",
    "LLVMLanaiInfo",
    "LLVMHexagonDisassembler",
    "LLVMHexagonCodeGen",
    "LLVMHexagonAsmParser",
    "LLVMHexagonDesc",
    "LLVMHexagonInfo",
    "LLVMBPFDisassembler",
    "LLVMBPFAsmParser",
    "LLVMBPFCodeGen",
    "LLVMBPFDesc",
    "LLVMBPFInfo",
    "LLVMAVRDisassembler",
    "LLVMAVRAsmParser",
    "LLVMAVRCodeGen",
    "LLVMAVRDesc",
    "LLVMAVRInfo",
    "LLVMARMDisassembler",
    "LLVMARMAsmParser",
    "LLVMARMCodeGen",
    "LLVMARMDesc",
    "LLVMARMUtils",
    "LLVMARMInfo",
    "LLVMAMDGPUTargetMCA",
    "LLVMAMDGPUDisassembler",
    "LLVMAMDGPUAsmParser",
    "LLVMAMDGPUCodeGen",
    "LLVMAMDGPUDesc",
    "LLVMAMDGPUUtils",
    "LLVMAMDGPUInfo",
    "LLVMAArch64Disassembler",
    "LLVMAArch64AsmParser",
    "LLVMAArch64CodeGen",
    "LLVMAArch64Desc",
    "LLVMAArch64Utils",
    "LLVMAArch64Info",
    "LLVMOrcDebugging",
    "LLVMOrcJIT",
    "LLVMWindowsDriver",
    "LLVMMCJIT",
    "LLVMJITLink",
    "LLVMInterpreter",
    "LLVMExecutionEngine",
    "LLVMRuntimeDyld",
    "LLVMOrcTargetProcess",
    "LLVMOrcShared",
    "LLVMDWP",
    "LLVMDWARFCFIChecker",
    "LLVMDebugInfoLogicalView",
    "LLVMOption",
    "LLVMObjCopy",
    "LLVMMCA",
    "LLVMMCDisassembler",
    "LLVMDTLTO",
    "LLVMLTO",
    "LLVMFrontendOpenACC",
    "LLVMFrontendDriver",
    "LLVMExtensions",
    "LLVMPlugins",
    "LLVMPasses",
    "LLVMHipStdPar",
    "LLVMCoroutines",
    "LLVMCFGuard",
    "LLVMipo",
    "LLVMInstrumentation",
    "LLVMVectorize",
    "LLVMSandboxIR",
    "LLVMLinker",
    "LLVMFrontendOpenMP",
    "LLVMFrontendDirective",
    "LLVMFrontendAtomic",
    "LLVMFrontendOffloading",
    "LLVMObjectYAML",
    "LLVMDWARFLinkerParallel",
    "LLVMDWARFLinkerClassic",
    "LLVMDWARFLinker",
    "LLVMGlobalISel",
    "LLVMMIRParser",
    "LLVMAsmPrinter",
    "LLVMSelectionDAG",
    "LLVMCodeGen",
    "LLVMTarget",
    "LLVMObjCARCOpts",
    "LLVMCodeGenTypes",
    "LLVMCGData",
    "LLVMCAS",
    "LLVMIRPrinter",
    "LLVMInterfaceStub",
    "LLVMFileCheck",
    "LLVMFuzzMutate",
    "LLVMScalarOpts",
    "LLVMInstCombine",
    "LLVMAggressiveInstCombine",
    "LLVMTransformUtils",
    "LLVMBitWriter",
    "LLVMAnalysis",
    "LLVMProfileData",
    "LLVMSymbolize",
    "LLVMDebugInfoBTF",
    "LLVMDebugInfoPDB",
    "LLVMDebugInfoMSF",
    "LLVMDebugInfoCodeView",
    "LLVMDebugInfoGSYM",
    "LLVMDebugInfoDWARF",
    "LLVMObject",
    "LLVMTextAPI",
    "LLVMMCParser",
    "LLVMIRReader",
    "LLVMAsmParser",
    "LLVMMC",
    "LLVMDebugInfoDWARFLowLevel",
    "LLVMBitReader",
    "LLVMFrontendHLSL",
    "LLVMFuzzerCLI",
    "LLVMABI",
    "LLVMCore",
    "LLVMRemarks",
    "LLVMBitstreamReader",
    "LLVMBinaryFormat",
    "LLVMTargetParser",
    "LLVMSupport",
    "LLVMDemangle",
};

// experimental targets, only in devkits whose llvm was built with them.
// gated by -Dllvm-has-* options, same as zig-src/build.zig.
pub const m68k = [_][]const u8{
    "LLVMM68kDisassembler",
    "LLVMM68kAsmParser",
    "LLVMM68kCodeGen",
    "LLVMM68kDesc",
    "LLVMM68kInfo",
};
pub const csky = [_][]const u8{
    "LLVMCSKYDisassembler",
    "LLVMCSKYAsmParser",
    "LLVMCSKYCodeGen",
    "LLVMCSKYDesc",
    "LLVMCSKYInfo",
};
pub const arc = [_][]const u8{
    "LLVMARCDisassembler",
    "LLVMARCCodeGen",
    "LLVMARCDesc",
    "LLVMARCInfo",
};
pub const xtensa = [_][]const u8{
    "LLVMXtensaDisassembler",
    "LLVMXtensaAsmParser",
    "LLVMXtensaCodeGen",
    "LLVMXtensaDesc",
    "LLVMXtensaInfo",
};

// extra static libs appended after the LLVM libs (compression deps)
pub const extra = [_][]const u8{
    "z",
    "zstd",
};

// devkit ships foo.lib on windows, libfoo.a elsewhere
fn libFile(b: *std.Build, t: std.Target, devkit: []const u8, name: []const u8) []const u8 {
    return if (t.os.tag == .windows)
        b.fmt("{s}/lib/{s}.lib", .{ devkit, name })
    else
        b.fmt("{s}/lib/lib{s}.a", .{ devkit, name });
}

fn addLibs(b: *std.Build, t: std.Target, mod: *std.Build.Module, devkit: []const u8, names: []const []const u8) void {
    for (names) |name| mod.addObjectFile(.{ .cwd_relative = libFile(b, t, devkit, name) });
}

/// experimental llvm target toggles
pub const ExperimentalTargets = struct {
    m68k: bool,
    csky: bool,
    arc: bool,
    xtensa: bool,
};

pub fn addExoticTargetOpts(b: *std.Build) ExperimentalTargets {
    return ExperimentalTargets{
        .m68k = b.option(bool, "llvm-has-m68k", "devkit llvm built with experimental m68k") orelse false,
        .csky = b.option(bool, "llvm-has-csky", "devkit llvm built with experimental csky") orelse false,
        .arc = b.option(bool, "llvm-has-arc", "devkit llvm built with experimental arc") orelse false,
        .xtensa = b.option(bool, "llvm-has-xtensa", "devkit llvm built with experimental xtensa") orelse false,
    };
}

pub fn addDevkitLibs(b: *std.Build, target: TargetInfo, mod: *std.Build.Module, devkit: DevkitInfo, exotic: ExperimentalTargets) void {
    const tgt = target.tgt;
    const devkit_path = devkit.devkit_path;
    addLibs(b, tgt, mod, devkit_path, clang[0..]);
    addLibs(b, tgt, mod, devkit_path, lld[0..]);
    addLibs(b, tgt, mod, devkit_path, llvm[0..]);

    if (exotic.m68k) addLibs(b, tgt, mod, devkit_path, m68k[0..]);
    if (exotic.csky) addLibs(b, tgt, mod, devkit_path, csky[0..]);
    if (exotic.arc) addLibs(b, tgt, mod, devkit_path, arc[0..]);
    if (exotic.xtensa) addLibs(b, tgt, mod, devkit_path, xtensa[0..]);

    addLibs(b, tgt, mod, devkit_path, extra[0..]);
}
