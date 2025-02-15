const std = @import("std");

pub const Utils = struct {
    pub fn computeLongitude(value: u32) f64 {
        return (@as(f64, @floatFromInt(value)) * (360.0 / @as(f64, @floatFromInt(3 * 0x10000000)))) - 180.0;
    }

    pub fn computeLatitude(value: u32) f64 {
        return 90.0 - @as(f64, @floatFromInt(value)) * (180.0 / @as(f64, @floatFromInt(2 * 0x10000000)));
    }

    pub fn floatToString(alloc: std.mem.Allocator, value: f64) ![]const u8 {
        const formatted = try std.fmt.allocPrint(alloc, "{d:.15}", .{value});

        return formatted;
    }

    pub fn trimNullTerminator(data: []const u8) []const u8 {
        if (std.mem.indexOfScalar(u8, data, 0)) |pos| {
            return data[0..pos];
        }

        return data;
    }

    pub fn decodeICAO(alloc: std.mem.Allocator, value: u32, is_aiport: bool) ![]const u8 {
        var defined_value = if (is_aiport) value >> 5 else value;
        const buffer = try alloc.alloc(u8, if (value > 99999999) 5 else 4);

        var index: usize = 0;

        while (defined_value > 37) {
            buffer[index] = valueToCharICAO(defined_value % 38);
            defined_value = (defined_value) / 38;
            index += 1;
        }

        buffer[index] = valueToCharICAO(defined_value);
        index += 1;

        std.mem.reverse(u8, buffer[0..index]);

        return buffer[0..index];
    }

    fn valueToCharICAO(v: u32) u8 {
        return switch (v) {
            0 => ' ',
            2...11 => @as(u8, @intCast((v - 2))) + '0',
            12...37 => @as(u8, @intCast((v - 12))) + 'A',
            else => unreachable,
        };
    }
};

test "should computeLongitude/computeLatitude gives correct value" {
    try std.testing.expectEqual(-64.27555829286575, Utils.computeLongitude(258871194));
    try std.testing.expectEqual(-36.588058434426785, Utils.computeLatitude(377563591));
}

test "should format float to string correctly" {
    const data = try Utils.floatToString(std.testing.allocator, -36.588058434426785);
    try std.testing.expectEqualStrings("-36.588058434426785", data);
    defer std.testing.allocator.free(data);
}

test "should decode a ICAO correctly" {
    const data1 = try Utils.decodeICAO(std.testing.allocator, 53277537, true);
    try std.testing.expectEqualStrings("SAZR", data1);
    defer std.testing.allocator.free(data1);

    const data2 = try Utils.decodeICAO(std.testing.allocator, 1004523782, true);
    try std.testing.expectEqualStrings("D014M", data2);
    defer std.testing.allocator.free(data2);
}
