// root.zig - exposes the API
pub usingnamespace @import("zigaract.zig");

// Expose build API
pub const build = struct {
    pub usingnamespace @import("../build.zig");
};