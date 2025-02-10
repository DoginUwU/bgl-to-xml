const std = @import("std");
const SubSection = @import("./section.zig").SubSection;

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

    pub const SectionHeaderRaw = struct {
        type: SectionType,
        subsection_flags: u32,
        num_subsections: u32,
        first_subsection_offset: u32,
        total_subsection_size: u32,
    };

    pub fn init(header_data: []const u8) !SectionHeader {
        const header = std.mem.bytesToValue(SectionHeaderRaw, header_data);

        const size_per_section = ((header.subsection_flags & 0x10000) | 0x40000) >> 0x0E;

        if (size_per_section * header.num_subsections != header.total_subsection_size) {
            std.debug.print("{any}\n", .{header});
            return error.InvalidSubsectionSize;
        }

        return .{
            .raw = header,
            .size_per_section = size_per_section,
        };
    }

    pub fn findSubSection(self: *SectionHeader, full_data: []const u8, idx: u32) !SubSection {
        if (idx >= self.raw.num_subsections) {
            return error.InvalidSubSectionIndex;
        }

        const start_offset = self.raw.first_subsection_offset + (idx * self.size_per_section);
        const subsection = SubSection.init(self, full_data[start_offset .. start_offset + self.size_per_section]);

        return subsection;
    }
};
