const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build tesseract from source
    const tesseract_path = "deps/tesseract";
    const build_root = b.build_root.path orelse "";
    const prefix_path = b.pathJoin(&.{ build_root, "zig-out", "tesseract-lib" });

    // Check if tesseract autogen.sh exists
    const autogen_path = b.pathFromRoot(tesseract_path ++ "/autogen.sh");
    std.fs.cwd().access(autogen_path, .{}) catch |err| {
        std.debug.print("Search for autogen here: {s}\nError: {s}\n", .{ autogen_path, @errorName(err) });
    };

    // Build Tesseract
    // Autogen step
    var tesseract_autogen_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_autogen_args.deinit();
    tesseract_autogen_args.append("sh") catch unreachable;
    tesseract_autogen_args.append("-c") catch unreachable;
    tesseract_autogen_args.append(b.fmt("cd {s} && ./autogen.sh", .{b.pathFromRoot(tesseract_path)})) catch unreachable;
    const run_tesseract_autogen = b.addSystemCommand(tesseract_autogen_args.items);

    // Configure step
    var tesseract_configure_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_configure_args.deinit();
    tesseract_configure_args.append("sh") catch unreachable;
    tesseract_configure_args.append("-c") catch unreachable;
    tesseract_configure_args.append(b.fmt("cd {s} && ./configure --enable-debug --prefix=\"{s}\" --enable-static --disable-shared", .{ b.pathFromRoot(tesseract_path), prefix_path })) catch unreachable;
    const run_tesseract_configure = b.addSystemCommand(tesseract_configure_args.items);
    run_tesseract_configure.step.dependOn(&run_tesseract_autogen.step);

    // Make step
    var tesseract_make_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_args.deinit();
    tesseract_make_args.append("sh") catch unreachable;
    tesseract_make_args.append("-c") catch unreachable;
    tesseract_make_args.append(b.fmt("cd {s} && make", .{b.pathFromRoot(tesseract_path)})) catch unreachable;
    const cpu_count = std.Thread.getCpuCount() catch 1;
    tesseract_make_args.append(b.fmt("-j{d}", .{cpu_count})) catch unreachable;
    const run_tesseract_make = b.addSystemCommand(tesseract_make_args.items);
    run_tesseract_make.step.dependOn(&run_tesseract_configure.step);

    // Make install step
    var tesseract_make_install_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_install_args.deinit();
    tesseract_make_install_args.append("sh") catch unreachable;
    tesseract_make_install_args.append("-c") catch unreachable;
    tesseract_make_install_args.append(b.fmt("cd {s} && make install", .{b.pathFromRoot(tesseract_path)})) catch unreachable;
    const run_tesseract_make_install = b.addSystemCommand(tesseract_make_install_args.items);
    run_tesseract_make_install.step.dependOn(&run_tesseract_make.step);

    // Create the library module
    const zigaract_mod = b.addModule("zigaract", .{
        .root_source_file = b.path("src/zigaract.zig"),
    });
    zigaract_mod.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "include", "tesseract" }) });

    // Create static library
    const lib = b.addStaticLibrary(.{
        .name = "zigaract",
        .root_source_file = b.path("src/zigaract.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Include directories for library (exact same as your original)
    lib.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "include", "tesseract" }) });
    lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "lib" }) });
    lib.linkSystemLibrary("tesseract");
    lib.linkLibCpp();
    lib.pie = true;

    // Add rpath for macOS
    if (target.result.os.tag == .macos) {
        const dylib_path = b.pathJoin(&.{ prefix_path, "lib" });
        lib.addRPath(.{ .cwd_relative = dylib_path });
    }

    lib.step.dependOn(&run_tesseract_make_install.step);
    b.installArtifact(lib);

    // Build example executable
    const example_exe = b.addExecutable(.{
        .name = "zigaract-example",
        .root_source_file = b.path("examples/version.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add our module to the example
    example_exe.root_module.addImport("zigaract", zigaract_mod);

    // Include directories for example (same as library)
    example_exe.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "include", "tesseract" }) });
    example_exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "lib" }) });
    example_exe.linkSystemLibrary("tesseract");
    example_exe.linkLibCpp();
    example_exe.pie = true;

    // Add rpath for macOS
    if (target.result.os.tag == .macos) {
        const dylib_path = b.pathJoin(&.{ prefix_path, "lib" });
        example_exe.addRPath(.{ .cwd_relative = dylib_path });
    }

    example_exe.step.dependOn(&run_tesseract_make_install.step);
    b.installArtifact(example_exe);

    // Test step
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/zigaract.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Include directories for tests (same as library)
    lib_tests.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "include", "tesseract" }) });
    lib_tests.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix_path, "lib" }) });
    lib_tests.linkSystemLibrary("tesseract");
    lib_tests.linkLibCpp();
    lib_tests.pie = true;

    // Add rpath for macOS
    if (target.result.os.tag == .macos) {
        const dylib_path = b.pathJoin(&.{ prefix_path, "lib" });
        lib_tests.addRPath(.{ .cwd_relative = dylib_path });
    }

    lib_tests.step.dependOn(&run_tesseract_make_install.step);

    const run_tests = b.addRunArtifact(lib_tests);
    b.step("test", "Run tests").dependOn(&run_tests.step);

    // Clean step
    var clean_tesseract_args = std.ArrayList([]const u8).init(b.allocator);
    defer clean_tesseract_args.deinit();
    clean_tesseract_args.append("sh") catch unreachable;
    clean_tesseract_args.append("-c") catch unreachable;
    clean_tesseract_args.append(b.fmt("cd {s} && make distclean || true", .{b.pathFromRoot(tesseract_path)})) catch unreachable;
    const clean_tesseract = b.addSystemCommand(clean_tesseract_args.items);

    b.step("clean", "Clean the project").dependOn(&clean_tesseract.step);

    // Create a step that runs the example by default
    const run_example = b.addRunArtifact(example_exe);
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_example.step);
}
