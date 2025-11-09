const std = @import("std");

fn getPkgConfigFlags(b: *std.Build, libs: []const []const u8) ![]const u8 {
    var args = std.ArrayList([]const u8){};
    defer args.deinit(b.allocator);

    try args.append(b.allocator, "pkg-config");
    try args.append(b.allocator, "--libs");
    for (libs) |lib| {
        try args.append(b.allocator, lib);
    }

    const result = b.run(args.items);
    return std.mem.trimRight(u8, result, "\n");
}

pub fn build(b: *std.Build) !void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    // Get DES_KEY from environment or build option
    const des_key = b.option([]const u8, "DES_KEY", "DES encryption key (exactly 8 bytes)") orelse
        std.process.getEnvVarOwned(b.allocator, "RICE_DES_KEY") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            std.log.err("DES_KEY not set!\n", .{});
            std.log.err("The LCD display requires a DES encryption key (exactly 8 bytes).\n", .{});
            std.log.err("\nBuild with either:\n", .{});
            std.log.err("  export RICE_DES_KEY=\"yourkey8\" && zig build\n", .{});
            std.log.err("  zig build -DDES_KEY=\"yourkey8\"\n", .{});
            return error.MissingDESKey;
        },
        else => return err,
    };

    // Required libraries
    const libs = [_][]const u8{
        "gtk4",
        "libadwaita-1",
        "cairo",
        "glib-2.0",
        "gobject-2.0",
        "libusb-1.0",
    };

    // Get pkg-config flags
    const pkg_config_flags = try getPkgConfigFlags(b, &libs);

    // Build additional linker flags
    const extra_linker_flags = try std.fmt.allocPrint(
        b.allocator,
        "{s} -lstdc++ -lpthread",
        .{pkg_config_flags},
    );

    // Build define flag
    const des_key_define = try std.fmt.allocPrint(
        b.allocator,
        "-define:DES_KEY={s}",
        .{des_key},
    );

    const extra_linker_flag = try std.fmt.allocPrint(
        b.allocator,
        "-extra-linker-flags:{s}",
        .{extra_linker_flags},
    );

    const cwd = std.fs.cwd().realpathAlloc(b.allocator, ".") catch unreachable;

    // Copy DES library files
    const des_dep = b.dependency("des", .{});
    const des_path = des_dep.path("").getPath(b);
    const des_output_dir = try std.fmt.allocPrint(b.allocator, "{s}/libs/des", .{cwd});

    const copy_des = b.addSystemCommand(&.{
        "sh",
        "-c",
    });
    const copy_des_cmd = try std.fmt.allocPrint(
        b.allocator,
        "mkdir -p {s} && cp {s}/des.odin {s}/",
        .{ des_output_dir, des_path, des_output_dir },
    );
    copy_des.addArg(copy_des_cmd);

    // Build tinyuz static library using make
    const tinyuz_dep = b.dependency("tinyuz", .{});
    const tinyuz_path = tinyuz_dep.path("").getPath(b);
    const output_dir = try std.fmt.allocPrint(b.allocator, "{s}/libs/tinyuz", .{cwd});

    // Clone HDiffPatch (tinyuz's dependency) and build tinyuz in one step
    const build_tinyuz = b.addSystemCommand(&.{
        "sh",
        "-c",
    });

    const tinyuz_parent = try std.fmt.allocPrint(b.allocator, "{s}/..", .{tinyuz_path});
    const build_cmd = try std.fmt.allocPrint(
        b.allocator,
        "cd {s} && [ -d HDiffPatch/.git ] || (rm -rf HDiffPatch && git clone --depth=1 https://github.com/sisong/HDiffPatch.git) && cd {s} && make libtinyuz.a MT=0 && mkdir -p {s} && cp libtinyuz.a {s}/",
        .{ tinyuz_parent, tinyuz_path, output_dir, output_dir },
    );
    build_tinyuz.addArg(build_cmd);

    // Compile Odin project
    const odin_compile = b.addSystemCommand(&.{"odin"});
    odin_compile.addArgs(&.{
        "build",
        ".",
        "-out:rice",
        "-o:speed",
    });
    odin_compile.addArg(des_key_define);
    odin_compile.addArg(extra_linker_flag);
    odin_compile.step.dependOn(&copy_des.step);
    odin_compile.step.dependOn(&build_tinyuz.step);

    // Install the built binary
    const install_exe = b.addInstallBinFile(.{ .cwd_relative = "rice" }, "rice");
    install_exe.step.dependOn(&odin_compile.step);

    b.getInstallStep().dependOn(&install_exe.step);

    // Run step
    const run_cmd = b.addSystemCommand(&.{"./rice"});
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const odin_test = b.addSystemCommand(&.{"odin"});
    odin_test.addArgs(&.{
        "test",
        "tests",
        "-all-packages",
        "-o:speed",
    });
    odin_test.addArg(des_key_define);
    odin_test.addArg(extra_linker_flag);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&odin_test.step);
}
