const std = @import("std");
const SectionHeader = @import("./header.zig").SectionHeader;
const SectionType = @import("./header.zig").SectionType;

pub const SubSection = struct {
    raw: SubSectionRaw,
    header: *SectionHeader,

    const SubSectionRaw = struct {
        qmid_a: u32,
        qmid_b: u32,
        // TODO: Add records if size is 0x20
        // records: u32,
        subsection_data_offset: u32,
        subsection_data_size: u32,
    };

    pub fn init(header: *SectionHeader, data: []const u8) !SubSection {
        const raw = std.mem.bytesToValue(SubSectionRaw, data);

        return .{
            .raw = raw,
            .header = header,
        };
    }

    pub fn readData(self: *SubSection, alloc: std.mem.Allocator, full_data: []const u8) !void {
        const sliced_data = full_data[self.raw.subsection_data_offset .. self.raw.subsection_data_offset + self.raw.subsection_data_size];

        switch (self.header.raw.type) {
            SectionType.Airport => {
                const data = try AirportSection.init(alloc, sliced_data);
                std.debug.print("\n{any}\n", .{data.raw});
            },
            else => @panic("Not implemented SubSection type data"),
        }
    }
};

const AirportSection = struct {
    raw: AirportSectionRaw,
    data: []const u8,
    records: std.ArrayList(Record),

    const Record = struct {
        raw: RecordRaw,
        record_data: []const u8,

        const RecordType = enum(u16) {
            RunwayStart = 0x11,
            Com = 0x12,
            AirportName = 0x19,
            TaxiWayPoints = 0x1A,
            TaxiNames = 0x1D,
            Helipad = 0x26,
            ApronEdgeLights = 0x31,
            AirportDelete = 0x33,
            Unknown64 = 0x40,
            Tower = 0x66,
            Runway = 0xCE,
            PaintedLine = 0xCF,
            Apron = 0xD3,
            TaxiWayPaths = 0xD4,
            PaintedHatchedArea = 0xD8,
            TaxiSign = 0xD9,
            Manufacturers = 0xDD,
            Jetway = 0xDE,
            TaxiwayParking = 0xE7,
            GroundMerging = 0xE9,
        };

        const RecordRaw = packed struct {
            id: RecordType,
            size: u32,
        };

        pub fn init(data: []const u8) Record {
            const raw = std.mem.bytesToValue(RecordRaw, data[0..0x06]);
            const record_data = data[0x06..raw.size];

            return .{
                .raw = raw,
                .record_data = record_data,
            };
        }
    };

    const AirportSectionRaw = packed struct {
        id: u16,
        size: u32,
        runway_recods: u8,
        com_records: u8,
        start_records: u8,
        approach_records: u8,
        aprons_records: u8,
        helipad_records: u8,
        longitude: u32,
        latitude: u32,
        altitude_meters: u32,
        idk1: u96,
        magnetic_variation_deg: u32,
        icao_ident: u32,
        region_ident: u32,
        fuel_type: u32,
        always0: u8,
        traffic_scalar: u8,
        airport_mask: u8,
        idk2: u16,
        idk3: u8,
        idk4: u8,
        flatten: u8,
        idk5: u64, //
    };

    pub fn init(alloc: std.mem.Allocator, data: []const u8) !AirportSection {
        const raw = std.mem.bytesToValue(AirportSectionRaw, data[0..@sizeOf(AirportSectionRaw)]);

        std.debug.assert(raw.id == 0x0056);

        var records = std.ArrayList(Record).init(alloc);
        defer records.deinit();
        var current_size_records: u32 = 0x44;

        while (current_size_records < raw.size) {
            const new_record = Record.init(data[current_size_records..data.len]);
            try records.append(new_record);

            current_size_records += new_record.raw.size;
        }

        std.debug.assert(current_size_records == raw.size);

        std.debug.print("{any}\n", .{records.items[2]});

        return .{
            .raw = raw,
            .data = data, //
            .records = records,
        };
    }
};
