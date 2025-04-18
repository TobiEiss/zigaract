# Zigaract

A Zig wrapper around Tesseract OCR that builds Tesseract from source, eliminating the need to install Tesseract separately on your system.

## Features

- Build Tesseract from source during compilation
- No system-wide Tesseract installation required
- Native Zig API for Tesseract OCR functionality

## Installation

### 1. Clone Tesseract as a git submodule

```bash
git submodule add https://github.com/tesseract-ocr/tesseract.git deps/tesseract
```

### 2. Add Zigaract to your project

```bash
zig fetch --save "git+https://github.com/TobiEiss/zigaract#latest"
```

## Configuration

Add the following to your `build.zig` file to configure and use Zigaract:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const build_root = b.build_root.path orelse "";
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Configure where the Tesseract library will be built
    const tesseract_lib_path = b.pathJoin(&.{ build_root, "zig-out", "tesseract-lib" });
    
    const exe = b.addExecutable(.{
        .name = "your-application",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Configure the Zigaract dependency
    const zigaract_dep = b.dependency("zigaract", .{
        .target = target,
        .optimize = optimize,
        .tesseract_repo_path = @as([]const u8, b.pathJoin(&.{"deps/tesseract"})),
        .tesseract_lib_output_path = @as([]const u8, tesseract_lib_path),
        // Set to true to build Tesseract from source, false if already built
        .tesseract_build = @as(bool, true),
    });

    // Add the zigaract module to your executable
    const zigaract_module = zigaract_dep.module("zigaract");
    exe.root_module.addImport("zigaract", zigaract_module);
    
    // Link the static library
    const zigaract_lib = zigaract_dep.artifact("zigaract");
    exe.linkLibrary(zigaract_lib);
    
    // Link against tesseract directly
    exe.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ tesseract_lib_path, "lib" }) });
    exe.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ tesseract_lib_path, "include", "tesseract" }) });
    
    // Link required libraries
    exe.linkSystemLibrary("tesseract");
    exe.linkSystemLibrary("lept");
    exe.linkSystemLibrary("curl");
    
    // For macOS vDSP functions
    if (target.result.os.tag == .macos) {
        exe.linkFramework("Accelerate");
    }
    
    exe.linkLibCpp();
    exe.pie = true;
    
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Usage

Import the library in your Zig code:

```zig
const std = @import("std");
const zigaract = @import("zigaract").Tesseract;

pub fn main() !void {
    const version = zigaract.getVersion();
    std.debug.print("{s}\n", .{version});
}
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `tesseract_repo_path` | Path to the Tesseract source code repository |
| `tesseract_lib_output_path` | Path where the built Tesseract library will be stored |
| `tesseract_build` | Boolean flag to control whether to build Tesseract (set to `false` if already built) |

## Dependencies

- Tesseract OCR: Optical Character Recognition engine
- Leptonica: Image processing library (required by Tesseract)
- cURL: For network operations
- C++ Standard Library: Required for Tesseract operations

## Platform-specific Notes

For macOS users, the Accelerate framework is automatically linked to provide optimized vDSP functions.
