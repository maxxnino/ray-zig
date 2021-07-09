const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const raylib = b.addStaticLibrary("raylib", null);
    raylib.linkLibC();
    raylib.setTarget(target);
    raylib.setBuildMode(mode);
    raylib.addCSourceFiles(&.{
        "3rd/raylib/src/core.c",
        "3rd/raylib/src/rglfw.c",
        "3rd/raylib/src/shapes.c",
        "3rd/raylib/src/textures.c",
        "3rd/raylib/src/text.c",
        "3rd/raylib/src/utils.c",
        "3rd/raylib/src/models.c",
        "3rd/raylib/src/raudio.c",
    }, &.{
        "-Wall",
        "-Wno-missing-braces",
        "-Werror=pointer-arith",
        "-fno-strict-aliasing",
        "-std=c99",
        "-fno-sanitize=undefined",
        "-Werror=implicit-function-declaration",
        "-DPLATFORM_DESKTOP",
        "-DGRAPHICS_API_OPENGL_33",
    });
    raylib.addIncludeDir("3rd/raylib/src");
    raylib.addIncludeDir("3rd/raylib/src/external/glfw/include");
    raylib.addIncludeDir("3rd/raylib/src/external/glfw/deps/mingw");
    raylib.linkSystemLibrary("opengl32");
    raylib.linkSystemLibrary("gdi32");
    raylib.linkSystemLibrary("winmm");

    const exe = b.addExecutable("ray-zig", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibrary(raylib);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
