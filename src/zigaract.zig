// zigaract.zig
const std = @import("std");
const c = @cImport({
    @cInclude("capi.h");
});

pub const Tesseract = struct {
    api: *c.TessBaseAPI,

    pub fn init() !Tesseract {
        const api = c.TessBaseAPICreate() orelse return error.TesseractInitFailed;
        return Tesseract{ .api = api };
    }

    pub fn deinit(self: *Tesseract) void {
        c.TessBaseAPIEnd(self.api);
        c.TessBaseAPIDelete(self.api);
    }

    pub fn getVersion() []const u8 {
        return std.mem.span(c.TessVersion());
    }

    pub fn initLanguage(self: *Tesseract, datapath: ?[]const u8, language: []const u8) !void {
        const datapath_c = if (datapath) |path| path.ptr else null;
        const result = c.TessBaseAPIInit3(self.api, datapath_c, language.ptr);
        if (result != 0) {
            return error.LanguageInitFailed;
        }
    }

    pub fn setImage(self: *Tesseract, image_data: []const u8, width: i32, height: i32, bytes_per_pixel: i32, bytes_per_line: i32) void {
        c.TessBaseAPISetImage(
            self.api,
            @ptrCast(image_data.ptr),
            @intCast(width),
            @intCast(height),
            @intCast(bytes_per_pixel),
            @intCast(bytes_per_line),
        );
    }

    pub fn recognize(self: *Tesseract) !void {
        const result = c.TessBaseAPIRecognize(self.api, null);
        if (result != 0) {
            return error.RecognizeFailed;
        }
    }

    pub fn getText(self: *Tesseract, allocator: std.mem.Allocator) ![]const u8 {
        const text_ptr = c.TessBaseAPIGetUTF8Text(self.api);
        if (text_ptr == null) {
            return error.GetTextFailed;
        }
        defer c.TessDeleteText(text_ptr);

        const text = std.mem.span(text_ptr);
        return allocator.dupe(u8, text);
    }
};

// Export the C API directly for advanced usage
pub const raw = struct {
    pub usingnamespace c;
};

test "tesseract version" {
    const version = c.TessVersion();
    std.debug.print("Tesseract version: {s}\n", .{version});
    try std.testing.expect(version != null);
}
