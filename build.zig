const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build tesseract from source
    std.fs.cwd().access("./deps/tesseract/autogen.sh", .{}) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
    };

    // tesseract-lib path
    const build_root = b.build_root.path orelse "";
    const prefix_path = b.pathJoin(&.{ build_root, "zig-out", "tesseract-lib" });

    // Autogen step
    var tesseract_autogen_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_autogen_args.deinit();
    tesseract_autogen_args.append("sh") catch unreachable;
    tesseract_autogen_args.append("-c") catch unreachable;
    tesseract_autogen_args.append("cd ./deps/tesseract/ && ./autogen.sh") catch unreachable;
    const run_tesseract_autogen = b.addSystemCommand(tesseract_autogen_args.items);

    // config arg
    var tesseract_configure_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_configure_args.deinit();
    tesseract_configure_args.append("sh") catch unreachable;
    tesseract_configure_args.append("-c") catch unreachable;
    // tesseract_configure_args.append(b.fmt("cd ./deps/tesseract/ && ./configure --enable-debug --prefix=\"{s}\"", .{prefix_path})) catch unreachable;
    tesseract_configure_args.append(b.fmt("cd ./deps/tesseract/ && ./configure --enable-debug --prefix=\"{s}\" --enable-static --disable-shared", .{prefix_path})) catch unreachable;
    const run_tesseract_configure = b.addSystemCommand(tesseract_configure_args.items);
    run_tesseract_configure.step.dependOn(&run_tesseract_autogen.step);

    // Make step
    var tesseract_make_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_args.deinit();
    tesseract_make_args.append("sh") catch unreachable;
    tesseract_make_args.append("-c") catch unreachable;
    tesseract_make_args.append("cd ./deps/tesseract/ && make") catch unreachable;
    const cpu_count = std.Thread.getCpuCount() catch 1;
    tesseract_make_args.append(b.fmt("-j{d}", .{cpu_count})) catch unreachable;
    const run_tesseract_make = b.addSystemCommand(tesseract_make_args.items);
    run_tesseract_make.step.dependOn(&run_tesseract_configure.step);

    // Make install step
    var tesseract_make_install_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_install_args.deinit();
    tesseract_make_install_args.append("sh") catch unreachable;
    tesseract_make_install_args.append("-c") catch unreachable;
    tesseract_make_install_args.append("cd ./deps/tesseract/ && make install") catch unreachable;
    const run_tesseract_make_install = b.addSystemCommand(tesseract_make_install_args.items);
    run_tesseract_make_install.step.dependOn(&run_tesseract_make.step);

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "zigaract",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Include directories
    exe.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "include", "tesseract" }) });
    exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "lib" }) });

    // Use static linking instead of dynamic to avoid runtime library searching
    exe.linkSystemLibrary("tesseract");
    exe.linkLibCpp();

    exe.pie = true;

    // Dynamic linking
    if (target.result.os.tag == .macos) {
        const dylib_path = b.pathJoin(&.{ prefix_path, "lib" });
        exe.addRPath(.{ .cwd_relative = dylib_path });
    }

    b.installArtifact(exe);

    // Make sure installation finishes before building the executable
    exe.step.dependOn(&run_tesseract_make_install.step);

    // build run step
    const run_exe = b.addRunArtifact(exe);

    // Make sure the project directory is clean and reusable for packagers
    var clean_tesseract_args = std.ArrayList([]const u8).init(b.allocator);
    defer clean_tesseract_args.deinit();
    clean_tesseract_args.append("sh") catch unreachable;
    clean_tesseract_args.append("-c") catch unreachable;
    clean_tesseract_args.append("cd ./deps/tesseract/ && make distclean || true") catch unreachable;
    const clean_tesseract = b.addSystemCommand(clean_tesseract_args.items);

    b.step("clean", "Clean the project").dependOn(&clean_tesseract.step);
    b.step("run", "Run the app").dependOn(&run_exe.step);
}
