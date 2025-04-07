const std = @import("std");
const c = @cImport({
    @cInclude("capi.h");
});

pub fn main() !void {
    const version = c.TessVersion();
    std.debug.print("Version: {s}", .{version});
}
