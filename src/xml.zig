const std = @import("std");

pub const XmlNode = struct {
    name: []const u8,
    attributes: ?std.StringHashMap([]const u8) = null,
    children: ?std.ArrayList(XmlNode) = null,
    text: ?[]const u8 = null,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, name: []const u8) XmlNode {
        return XmlNode{
            .name = name,
            .attributes = std.StringHashMap([]const u8).init(alloc),
            .children = std.ArrayList(XmlNode).init(alloc),
            .text = null,
            .alloc = alloc,
        };
    }

    pub fn addChild(self: *XmlNode, child: XmlNode) !void {
        try self.children.?.append(child);
    }

    pub fn addAttribute(self: *XmlNode, key: []const u8, value: []const u8) !void {
        try self.attributes.?.put(key, try self.alloc.dupe(u8, value));
    }

    pub fn deinit(self: *XmlNode) void {
        if (self.attributes) |*map| {
            var it = map.iterator();
            while (it.next()) |entry| {
                self.alloc.free(entry.value_ptr.*);
            }
        }

        self.attributes.?.deinit();

        for (self.children.?.items) |*child| {
            child.deinit();
        }

        self.children.?.deinit();
    }

    pub fn write(self: *XmlNode, file: std.fs.File, indent: usize) !void {
        var writer = file.writer();

        const indentation = try self.alloc.alloc(u8, indent * 2);
        defer self.alloc.free(indentation);
        @memset(indentation, ' ');
        try writer.print("{s}<{s}", .{ indentation, self.name });

        var iter = self.attributes.?.iterator();
        while (iter.next()) |entry| {
            try writer.print(" {s}=\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        if (self.children.?.items.len == 0 and self.text == null) {
            try writer.writeAll(" />\n");
            return;
        }

        try writer.writeAll(">\n");

        for (self.children.?.items) |*child| {
            try child.write(file, indent + 1);
        }

        try writer.print("</{s}>", .{self.name});
    }
};
