const std = @import("std");
const rlz = @import("raylib-zig");
const builtin = @import("builtin");

const emccOutputDir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
const emccOutputFile = "index.html";

pub fn linkWithEmscripten(
    b: *std.Build,
    itemsToLink: []const *std.Build.Step.Compile,
) !*std.Build.Step.Run {
    // Raylib uses --sysroot in order to find emscripten, so do the same here.
    if (b.sysroot == null) {
        @panic("Pass '--sysroot \"[path to emsdk installation]/upstream/emscripten\"'");
    }
    const emccExe = switch (builtin.os.tag) {
        .windows => "emcc.bat",
        else => "emcc",
    };
    var emcc_run_arg = try b.allocator.alloc(u8, b.sysroot.?.len + emccExe.len + 1);
    defer b.allocator.free(emcc_run_arg);

    emcc_run_arg = try std.fmt.bufPrint(
        emcc_run_arg,
        "{s}" ++ std.fs.path.sep_str ++ "{s}",
        .{ b.sysroot.?, emccExe },
    );

    // Create the output directory because emcc can't do it.
    const mkdir_command = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", emccOutputDir });

    // Actually link everything together.
    const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_run_arg});

    for (itemsToLink) |item| {
        emcc_command.addFileArg(item.getEmittedBin());
        emcc_command.step.dependOn(&item.step);
    }
    // This puts the file in zig-out/htmlout/index.html.
    emcc_command.step.dependOn(&mkdir_command.step);
    emcc_command.addArgs(&[_][]const u8{
        "-o",
        emccOutputDir ++ emccOutputFile,
        "-sFULL-ES3=1",
        "-sUSE_GLFW=3",
        "-sUSE_OFFSET_CONVERTER",
        "-sASYNCIFY",
        "-sTOTAL_MEMORY=1024MB", // increase memory
        "-O3",
        "--emrun",
    });
    return emcc_command;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // raylib-zig
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib"); // raylib module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // ==================
    // ==> WASM BUILD <==
    // ==================
    if (target.query.os_tag == .emscripten) {
        const exe_lib = rlz.emcc.compileForEmscripten(
            b,
            "wfc",
            "src/main.zig",
            target,
            optimize,
        );

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file,
        // so it also needs to be linked with emscripten.
        const link_step = try linkWithEmscripten(
            b,
            &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact },
        );

        link_step.addArg("--embed-file");
        link_step.addArg("assets/");

        link_step.addArg("--shell-file");
        link_step.addArg("shell-files/index.html");

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run web version");
        run_option.dependOn(&run_step.step);

        // NOTE: return early if we're on emscripten
        return;
    }

    // =============================
    // ==> NATIVE DEBUGGER BUILD <==
    // =============================
    const dbg = b.addExecutable(.{
        .name = "debug",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(dbg);
    dbg.linkLibrary(raylib_artifact);
    dbg.root_module.addImport("raylib", raylib);

    // ====================
    // ==> NATIVE BUILD <==
    // ====================
    const exe = b.addExecutable(.{
        .name = "wfc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    // exe executable
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args|
        run_cmd.addArgs(args);

    const exe_run_step = b.step("run", "Run native version");
    exe_run_step.dependOn(&run_cmd.step);

    // ==================
    // ==> TEST BUILD <==
    // ==================
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
