const std = @import("std");
const SectionHeader = @import("./section.zig").SectionHeader;
const SectionType = @import("./section.zig").SectionType;
const XmlNode = @import("./xml.zig").XmlNode;

pub fn isValidBGL(data: []const u8) bool {
    const bgl_magic_1 = [_]u8{ 0x01, 0x02, 0x92, 0x19, 0x38 };

    if (data.len < bgl_magic_1.len) {
        return false;
    }

    return std.mem.eql(u8, &bgl_magic_1, data[0..bgl_magic_1.len]);
}

const BGLDecoder = struct {
    data: []const u8,
    header: Header,
    section_headers: std.ArrayList(SectionHeader),
    alloc: std.mem.Allocator,

    const Header = struct {
        magic1: u32,
        len: u32,
        low_file_time: u32,
        high_file_time: u32,
        magic2: u32,
        sections_len: u32,
        reserved: [8]u32, //
    };

    pub fn init(alloc: std.mem.Allocator, data: []const u8) !BGLDecoder {
        if (!isValidBGL(data)) {
            return error.InvalidBGL;
        }

        const header = std.mem.bytesToValue(Header, data[0..@divExact(@bitSizeOf(Header), 8)]);
        const section_headers = try std.ArrayList(SectionHeader).initCapacity(alloc, header.sections_len);
        errdefer section_headers.deinit();

        return .{
            .header = header,
            .data = data, //
            .section_headers = section_headers,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *BGLDecoder) void {
        for (self.section_headers.items) |*section| {
            section.deinit();
        }

        self.section_headers.deinit();
    }

    pub fn fillData(self: *BGLDecoder) !void {
        for (0..self.header.sections_len) |_| {
            try self.loadSectionHeader();
        }
    }

    fn loadSectionHeader(self: *BGLDecoder) !void {
        if (self.section_headers.items.len >= self.header.sections_len) {
            return error.InvalidSectionIndex;
        }

        const size_of_section = @divExact(@bitSizeOf(SectionHeader.SectionHeaderRaw), 8);
        const start_offset = @divExact(@bitSizeOf(Header), 8) + (self.section_headers.items.len * size_of_section);
        const header = try SectionHeader.init(self.alloc, self.data[start_offset .. start_offset + size_of_section]);

        try self.section_headers.append(header);
    }
};

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gp.deinit();

    var allocator = gp.allocator();

    var file = try std.fs.cwd().openFile("test/raw2.bgl", .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const data = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(data);

    var decoder = try BGLDecoder.init(allocator, data);
    defer decoder.deinit();
    try decoder.fillData();

    var root = XmlNode.init(allocator, "Root");
    defer root.deinit();

    const xml_file = try std.fs.cwd().createFile("test/test.xml", .{ .read = true });
    defer xml_file.close();

    for (decoder.section_headers.items) |*section| {
        for (0..section.raw.num_subsections) |_| {
            try section.loadSubSection(data);
        }

        try section.writeData(allocator, data, &root);
    }

    try root.write(xml_file, 0);
}
