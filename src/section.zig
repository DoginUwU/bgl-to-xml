const std = @import("std");
const XmlNode = @import("./xml.zig").XmlNode;
const Utils = @import("./utils.zig").Utils;

pub const SectionType = enum(u32) {
    None = 0x0,
    Copyright = 0x1,
    Guid = 0x2,
    Airport = 0x3,
    IlsVor = 0x13,
    Ndb = 0x17,
    Marker = 0x18,
    Boundary = 0x20,
    Waypoint = 0x22,
    Geopol = 0x23,
    SceneryObject = 0x25,
    NameList = 0x27,
    VorIlsIcaoIndex = 0x28,
    NdbIcaoIndex = 0x29,
    WaypointIcaoIndex = 0x2A,
    ModelData = 0x2B,
    AirportSummary = 0x2C,
    Exclusion = 0x2E,
    TimeZone = 0x2F,
    TerrainVectorDb = 0x65,
    TerrainElevation = 0x67,
    TerrainLandClass = 0x68,
    TerrainWaterClass = 0x69,
    TerrainRegion = 0x6A,
    PopulationDensity = 0x6C,
    AutogenAnnotation = 0x6D,
    TerrainIndex = 0x6E,
    TerrainTextureLookup = 0x6F,
    TerrainSeasonJan = 0x78,
    TerrainSeasonFeb = 0x79,
    TerrainSeasonMar = 0x7A,
    TerrainSeasonApr = 0x7B,
    TerrainSeasonMay = 0x7C,
    TerrainSeasonJun = 0x7D,
    TerrainSeasonJul = 0x7E,
    TerrainSeasonAug = 0x7F,
    TerrainSeasonSep = 0x80,
    TerrainSeasonOct = 0x81,
    TerrainSeasonNov = 0x82,
    TerrainSeasonDec = 0x83,
    TerrainPhotoJan = 0x8C,
    TerrainPhotoFeb = 0x8D,
    TerrainPhotoMar = 0x8E,
    TerrainPhotoApr = 0x8F,
    TerrainPhotoMay = 0x90,
    TerrainPhotoJun = 0x91,
    TerrainPhotoJul = 0x92,
    TerrainPhotoAug = 0x93,
    TerrainPhotoSep = 0x94,
    TerrainPhotoOct = 0x95,
    TerrainPhotoNov = 0x96,
    TerrainPhotoDec = 0x97,
    TerrainPhotoNight = 0x98,
    Tacan = 0xA0,
    TacanIndex = 0xA1,
    FakeTypes = 0x2710,
    IcaoRunway = 0x2711,
};

pub const SectionHeader = struct {
    raw: SectionHeaderRaw,
    size_per_section: u32,
    subsections: std.ArrayList(SubSection),

    pub const SectionHeaderRaw = struct {
        type: SectionType,
        subsection_flags: u32,
        num_subsections: u32,
        first_subsection_offset: u32,
        total_subsection_size: u32,
    };

    pub fn init(alloc: std.mem.Allocator, header_data: []const u8) !SectionHeader {
        const header = std.mem.bytesToValue(SectionHeaderRaw, header_data);

        const size_per_section = ((header.subsection_flags & 0x10000) | 0x40000) >> 0x0E;

        if (size_per_section * header.num_subsections != header.total_subsection_size) {
            std.debug.print("{any}\n", .{header});
            return error.InvalidSubsectionSize;
        }

        const subsections = try std.ArrayList(SubSection).initCapacity(alloc, header.num_subsections);
        errdefer subsections.deinit();

        return .{
            .raw = header,
            .size_per_section = size_per_section,
            .subsections = subsections,
        };
    }

    pub fn deinit(self: *SectionHeader) void {
        self.subsections.deinit();
    }

    pub fn loadSubSection(self: *SectionHeader, full_data: []const u8) !void {
        if (self.subsections.items.len >= self.raw.num_subsections) {
            return error.InvalidSubSectionIndex;
        }

        const start_offset = self.raw.first_subsection_offset + (self.subsections.items.len * self.size_per_section);
        const subsection = try SubSection.init(self, full_data[start_offset .. start_offset + self.size_per_section]);
        try self.subsections.append(subsection);
    }

    pub fn writeData(self: *SectionHeader, alloc: std.mem.Allocator, full_data: []const u8, node: *XmlNode) !void {
        for (self.subsections.items) |*subsection| {
            const new_node = subsection.writeData(alloc, full_data) catch continue;
            try node.addChild(new_node);
        }
    }
};

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

    pub fn writeData(self: *SubSection, alloc: std.mem.Allocator, full_data: []const u8) !XmlNode {
        const sliced_data = full_data[self.raw.subsection_data_offset .. self.raw.subsection_data_offset + self.raw.subsection_data_size];

        switch (self.header.raw.type) {
            SectionType.Airport => {
                var data = try AirportSubSection.init(alloc, sliced_data);
                defer data.deinit();
                return try data.write();
            },
            SectionType.Waypoint => {
                var data = try WaypointSubSection.init(alloc, sliced_data);
                // defer data.deinit();
                return try data.write();
            },
            else => {
                std.debug.print("Not implemented SubSection type data {any}\n", .{self.header.raw.type});
                return error.UnhandledSubSection;
            },
        }
    }
};

const AirportSubSection = struct {
    raw: AirportSubSectionRaw,
    data: []const u8,
    records: std.ArrayList(Record),
    alloc: std.mem.Allocator,

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
            Approach = 0xFA,
            Departure = 0x42,
        };

        const RecordRaw = packed struct {
            id: RecordType,
            size: u32,
        };

        pub fn init(data: []const u8, offset: u32) Record {
            const raw = std.mem.bytesToValue(RecordRaw, data[offset .. offset + @divExact(@bitSizeOf(RecordRaw), 8)]);
            const record_data = data[offset + @divExact(@bitSizeOf(RecordRaw), 8) .. offset + raw.size];

            return .{
                .raw = raw,
                .record_data = record_data,
            };
        }
    };

    const AirportSubSectionRaw = packed struct {
        id: u16,
        size: u32,
        runway_records: u8,
        com_records: u8,
        start_records: u8,
        approach_records: u8,
        aprons_records: u8,
        helipad_records: u8,
        longitude: u32,
        latitude: u32,
        altitude_meters: u32,
        idk1: u96,
        magnetic_variation_deg: f32,
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
        idk5: u64,
    };

    pub fn init(alloc: std.mem.Allocator, data: []const u8) !AirportSubSection {
        const raw = std.mem.bytesToValue(AirportSubSectionRaw, data[0..@divExact(@bitSizeOf(AirportSubSectionRaw), 8)]);

        std.debug.assert(raw.id == 0x0056);

        var records = std.ArrayList(Record).init(alloc);
        errdefer records.deinit();
        var current_size_records: u32 = @divExact(@bitSizeOf(AirportSubSectionRaw), 8);

        while (current_size_records < raw.size) {
            const new_record = Record.init(data, current_size_records);
            try records.append(new_record);

            current_size_records += new_record.raw.size;
        }

        std.debug.assert(current_size_records == raw.size);

        return .{
            .raw = raw,
            .data = data, //
            .records = records,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *AirportSubSection) void {
        self.records.deinit();
    }

    pub fn write(self: *AirportSubSection) !XmlNode {
        var node = XmlNode.init(self.alloc, "Airport");
        // std.debug.print("{any}\n", .{self.raw});

        for (self.records.items) |*record| {
            switch (record.raw.id) {
                .AirportName => {
                    try node.addAttribute("name", Utils.trimNullTerminator(record.record_data));
                },
                .Departure => {
                    const new_node = XmlNode.init(self.alloc, "Departure");
                    try node.addChild(new_node);
                    // std.debug.print("{x}\n", .{record.record_data});
                },
                .Approach => {
                    const new_node = XmlNode.init(self.alloc, "Approach");
                    try node.addChild(new_node);
                },
                else => {
                    std.debug.print("Not implemented Record type data {any}\n", .{record.raw.id});
                },
            }
        }

        const latitude = try Utils.floatToString(self.alloc, Utils.computeLatitude(self.raw.latitude));
        const longitude = try Utils.floatToString(self.alloc, Utils.computeLongitude(self.raw.longitude));
        const icao = try Utils.decodeICAO(self.alloc, self.raw.icao_ident, true);
        defer {
            self.alloc.free(latitude);
            self.alloc.free(longitude);
            self.alloc.free(icao);
        }

        try node.addAttribute("lat", latitude);
        try node.addAttribute("lon", longitude);
        try node.addAttribute("ident", icao);

        return node;
    }
};

const WaypointSubSection = struct {
    raw: WaypointSubSectionRaw,
    data: []const u8,
    alloc: std.mem.Allocator,

    const WaypointType = enum(u8) {
        Named = 1,
        Unnamed = 2,
        Vor = 3,
        Ndb = 4,
        OffRoute = 5,
        IAF = 6,
        FAF = 7,
        RNAV = 8, //
    };

    const WaypointSubSectionRaw = packed struct {
        id: u16,
        size: u32,
        type: WaypointType, //
        route_entries_count: u8,
        longitude: u32,
        latitude: u32,
        magnetic_variation_deg: f32,
        icao_ident: u32,
        region: u32,
    };

    pub fn init(alloc: std.mem.Allocator, data: []const u8) !WaypointSubSection {
        const raw = std.mem.bytesToValue(WaypointSubSectionRaw, data[0..@divExact(@bitSizeOf(WaypointSubSectionRaw), 8)]);

        std.debug.assert(raw.id == 0x0022);

        return .{
            .raw = raw,
            .data = data,
            .alloc = alloc, //
        };
    }

    pub fn write(self: *WaypointSubSection) !XmlNode {
        var node = XmlNode.init(self.alloc, "Waypoint");

        const latitude = try Utils.floatToString(self.alloc, Utils.computeLatitude(self.raw.latitude));
        const longitude = try Utils.floatToString(self.alloc, Utils.computeLongitude(self.raw.longitude));
        const mag_var = try Utils.floatToString(self.alloc, self.raw.magnetic_variation_deg);
        const icao = try Utils.decodeICAO(self.alloc, self.raw.icao_ident, true);
        const airport_icao = try Utils.decodeICAO(self.alloc, (self.raw.region >> 11), false);
        const region = try Utils.decodeICAO(self.alloc, self.raw.region & 0x7FF, false);
        defer {
            self.alloc.free(latitude);
            self.alloc.free(longitude);
            self.alloc.free(icao);
            self.alloc.free(airport_icao);
            self.alloc.free(region);
            self.alloc.free(mag_var);
        }

        try node.addAttribute("lat", latitude);
        try node.addAttribute("lon", longitude);
        try node.addAttribute("ident", icao);
        try node.addAttribute("airportIdent", airport_icao);
        try node.addAttribute("region", region);
        try node.addAttribute("magVar", mag_var);

        return node;
    }
};
