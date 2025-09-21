const std = @import("std");

/// A list of heap allocated file names and the allocator that owns them.
pub const FileNameList = struct {
    allocator: std.mem.Allocator,
    items: [][]u8,

    /// Returns the file names as immutable slices.
    pub fn names(self: FileNameList) []const []const u8 {
        return self.items;
    }

    /// Releases all allocated memory.
    pub fn deinit(self: *FileNameList) void {
        for (self.items) |item| {
            self.allocator.free(item);
        }
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

/// Errors that can occur while listing files in a directory.
pub const ListError = std.fs.Dir.OpenError || std.fs.Dir.Iterator.Error || error{OutOfMemory};

/// Reads the provided directory path and returns the names of regular files within it.
/// Non-file entries (directories, symlinks, etc.) are ignored. The returned list owns
/// the strings and must be deinitialized by calling `FileNameList.deinit`.
pub fn listFileNames(allocator: std.mem.Allocator, dir_path: []const u8) ListError!FileNameList {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var collected = try std.ArrayList([]u8).initCapacity(allocator, 0);
    errdefer {
        for (collected.items) |item| allocator.free(item);
        collected.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        const duplicate = try allocator.dupe(u8, entry.name);
        try collected.append(allocator, duplicate);
    }

    std.mem.sort([]u8, collected.items, {}, sortLessThan);

    return FileNameList{
        .allocator = allocator,
        .items = try collected.toOwnedSlice(allocator),
    };
}

fn sortLessThan(_: void, lhs: []u8, rhs: []u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn buildCacheTmpPath(allocator: std.mem.Allocator, sub_path: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{sub_path});
}

test "listFileNames returns file names only" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.writeFile(.{ .sub_path = "alpha.txt", .data = "" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "beta.log", .data = "" });
    try tmp_dir.dir.makeDir("nested");
    try tmp_dir.dir.writeFile(.{ .sub_path = "nested/ignored.txt", .data = "" });

    const allocator = std.testing.allocator;
    const dir_path = try buildCacheTmpPath(allocator, tmp_dir.sub_path[0..]);
    defer allocator.free(dir_path);

    var list = try listFileNames(allocator, dir_path);
    defer list.deinit();

    const names = list.names();
    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("alpha.txt", names[0]);
    try std.testing.expectEqualStrings("beta.log", names[1]);
}

test "listFileNames propagates missing directory" {
    const allocator = std.testing.allocator;
    const result = listFileNames(allocator, "definitely/missing/path");
    try std.testing.expectError(error.FileNotFound, result);
}
