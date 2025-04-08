const std = @import("std");
const zigaract = @import("zigaract");

pub fn main() !void {
    const version = zigaract.Tesseract.getVersion();
    std.debug.print("Tesseract Version: {s}\n", .{version});

    // Initialize a Tesseract instance
    var tess = try zigaract.Tesseract.init();
    defer tess.deinit();

    std.debug.print("Tesseract API initialized successfully\n", .{});
}
