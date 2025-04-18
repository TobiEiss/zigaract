const std = @import("std");

pub fn build(b: *std.Build) !void {
    const options = Options.getOptions(b);
    const tesseract_repo_path = options.tesseract_repo_path;
    const prefix_path = options.tesseract_lib_output_path;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Check if tesseract autogen.sh exists
    const autogen_path = b.pathJoin(&.{ tesseract_repo_path, "autogen.sh" });
    std.fs.cwd().access(autogen_path, .{}) catch |err| {
        std.debug.print("Search for autogen here: {s}\nError: {s}\n", .{ autogen_path, @errorName(err) });
    };

    // Build Tesseract
    // Autogen step
    var tesseract_autogen_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_autogen_args.deinit();
    tesseract_autogen_args.append("sh") catch unreachable;
    tesseract_autogen_args.append("-c") catch unreachable;
    tesseract_autogen_args.append(b.fmt("cd {s} && ./autogen.sh", .{tesseract_repo_path})) catch unreachable;
    const run_tesseract_autogen = b.addSystemCommand(tesseract_autogen_args.items);

    // Configure step
    var tesseract_configure_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_configure_args.deinit();
    tesseract_configure_args.append("sh") catch unreachable;
    tesseract_configure_args.append("-c") catch unreachable;
    tesseract_configure_args.append(b.fmt("cd {s} && ./configure --enable-debug --prefix=\"{s}\" --enable-static --disable-shared", .{ tesseract_repo_path, prefix_path })) catch unreachable;
    const run_tesseract_configure = b.addSystemCommand(tesseract_configure_args.items);
    run_tesseract_configure.step.dependOn(&run_tesseract_autogen.step);

    // Make step
    var tesseract_make_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_args.deinit();
    tesseract_make_args.append("sh") catch unreachable;
    tesseract_make_args.append("-c") catch unreachable;
    tesseract_make_args.append(b.fmt("cd {s} && make", .{tesseract_repo_path})) catch unreachable;
    const cpu_count = std.Thread.getCpuCount() catch 1;
    tesseract_make_args.append(b.fmt("-j{d}", .{cpu_count})) catch unreachable;
    const run_tesseract_make = b.addSystemCommand(tesseract_make_args.items);
    run_tesseract_make.step.dependOn(&run_tesseract_configure.step);

    // Make install step
    var tesseract_make_install_args = std.ArrayList([]const u8).init(b.allocator);
    defer tesseract_make_install_args.deinit();
    tesseract_make_install_args.append("sh") catch unreachable;
    tesseract_make_install_args.append("-c") catch unreachable;
    tesseract_make_install_args.append(b.fmt("cd {s} && make install", .{tesseract_repo_path})) catch unreachable;
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

    if (options.tesseract_build) {
        lib.step.dependOn(&run_tesseract_make_install.step);
    }
    b.installArtifact(lib);
}

pub const Options = struct {
    tesseract_repo_path: []const u8,
    tesseract_lib_output_path: []const u8,
    tesseract_build: bool,

    pub fn getOptions(b: *std.Build) Options {
        return .{
            .tesseract_repo_path = b.option([]const u8, "tesseract_repo_path", "Path to tesseract repository") orelse "./deps/tesseract",
            .tesseract_lib_output_path = b.option([]const u8, "tesseract_lib_output_path", "Path to the output of the built lib") orelse "./zig-out/tesseract-lib",
            .tesseract_build = b.option(bool, "tesseract_build", "build tesseract") orelse true,
        };
    }
};
