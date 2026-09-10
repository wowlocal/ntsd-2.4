import Foundation

public struct OriginalCalendarEvent: Codable, Equatable, Sendable {
    public var kind: String
    public var value: UInt64?, result: UInt32?, bytes: [UInt8]?, capacity: Int?, count: Int?, address: UInt32?
    public init(_ kind: String,value: UInt64? = nil,result: UInt32? = nil,bytes: [UInt8]? = nil,capacity: Int? = nil,count: Int? = nil,address: UInt32? = nil) {
        self.kind = kind;self.value = value;self.result = result;self.bytes = bytes;self.capacity = capacity;self.count = count;self.address = address
    }
}

/// VC80 calendar behavior used by original WinMain. OS responses remain inputs;
/// this owns numeric results and caches without loading a CRT or host calendar.
public struct OriginalCalendarTime: Equatable {
    public struct Zone: Codable, Equatable, Sendable {
        public let bias: Int32, standard: [Int32], daylight: [Int32], standardBias: Int32, daylightBias: Int32
        public let standardName: String, daylightName: String
        public init(bias: Int32,standard: [Int32],daylight: [Int32],standardBias: Int32,daylightBias: Int32,standardName: String,daylightName: String) {
            self.bias = bias;self.standard = standard;self.daylight = daylight;self.standardBias = standardBias;self.daylightBias = daylightBias;self.standardName = standardName;self.daylightName = daylightName
        }
    }
    public enum Boundary: Error, Equatable { case invalidParameter, unknownAllocatorReturn }
    public private(set) var timezone: [Int32] = [28800,1,-3600]
    public private(set) var cache: [Int32] = [-1,0,0,-1,0,0]
    public private(set) var names: [UInt8] = Array("PST".utf8)+[UInt8](repeating:0,count:61)+Array("PDT".utf8)+[UInt8](repeating:0,count:61)
    public private(set) var initialized = false, osZone = false
    public private(set) var errno: Int32 = 0
    public private(set) var tmPointer: UInt32 = 0
    public private(set) var allocations: [UInt32:OriginalStateRecord] = [:]
    private var zone: Zone?
    public init() {}
    public static let maximum: Int64 = 32_535_244_799
    private static func error(_ s: String) -> OriginalStateError { .invalidStorage("Calendar time: "+s) }
    private static func leap(_ year: Int) -> Bool { year%4 == 0 && (year%100 != 0 || year%400 == 0) }
    private static func months(_ year: Int) -> [Int] { [31,leap(year) ? 29 : 28,31,30,31,30,31,31,30,31,30,31] }
    private static func yearDays(_ year: Int) -> Int { 365*(year-1970)+(year-1)/4-1969/4-(year-1)/100+1969/100+(year-1)/400-1969/400 }

    /// _time64 uses unsigned wrapping FILETIME epoch subtraction and division.
    /// Its optional output is eight bytes; subsecond ticks are discarded.
    public static func readClock(filetime: () throws -> UInt64,output: inout OriginalStateRecord?,observe: (OriginalCalendarEvent) throws -> Void = { _ in }) throws -> UInt64 {
        var candidate = output
        if let candidate, candidate.bytes.count != 8 { throw error("Clock output extent") }
        let ticks = try filetime();try observe(.init("filetime",value:ticks))
        let result = (ticks &- 116_444_736_000_000_000)/10_000_000
        if candidate != nil { try candidate!.write(result,at:0) }
        output = candidate;return result
    }

    /// Whole _localtime64 with lazy timezone initialization and its retained tm.
    /// Allocator/name-conversion callbacks provide declared platform bytes.
    /// All owned state commits together; callers stage external callback effects.
    public mutating func local(_ seconds: Int64,environmentTZ: [UInt8]? = nil,
        timezoneSource: () throws -> (result: UInt32,zone: Zone?),
        allocate: (Int) throws -> OriginalInterfaceAllocation,
        convertName: (String,Int) throws -> [UInt8],
        observe: (OriginalCalendarEvent) throws -> Void = { _ in },
        after: (OriginalCalendarTime) throws -> Void = { _ in }) throws -> [Int32]? {
        var candidate = self
        let result = try candidate.convert(seconds,environmentTZ:environmentTZ,timezoneSource:timezoneSource,allocate:allocate,convertName:convertName,observe:observe)
        try after(candidate);self = candidate;return result
    }
    private mutating func alloc(_ count: Int,_ allocate: (Int) throws -> OriginalInterfaceAllocation,_ observe: (OriginalCalendarEvent) throws -> Void) throws -> UInt32 {
        let a = try allocate(count);try observe(.init("allocate",count:count,address:a.address))
        if a.address != 0 {
            guard allocations[a.address] == nil,a.backing.count == count else { throw Self.error("Allocator backing") }
            allocations[a.address] = try .init(bytes:a.backing,defined:[Bool](repeating:false,count:count))
        }
        return a.address
    }
    private mutating func setTM(_ values: [Int32]) throws {
        guard values.count == 9,var record = allocations[tmPointer],record.bytes.count == 36 else { throw Self.error("tm backing") }
        for (i,v) in values.enumerated() { try record.write(v,at:i*4) }
        allocations[tmPointer] = record
    }
    private mutating func initialize(_ tz: [UInt8]?,_ source: () throws -> (result: UInt32,zone: Zone?),_ allocate: (Int) throws -> OriginalInterfaceAllocation,_ convert: (String,Int) throws -> [UInt8],_ observe: (OriginalCalendarEvent) throws -> Void) throws {
        guard !initialized else { return }
        osZone = false;cache[0] = -1;cache[3] = -1
        if let tz,!tz.isEmpty {
            guard !tz.contains(0),tz.count >= 3,tz.count < 256,tz.allSatisfy({ $0 < 128 }) else { throw Self.error("Declared TZ input extent/encoding") }
            let address = try alloc(tz.count+1,allocate,observe)
            if address != 0 {
                var record = allocations[address]!
                for (i,b) in (tz+[0]).enumerated() { try record.write(b,at:i) };allocations[address] = record
                for i in 0..<3 { names[i] = tz[i] };names[3] = 0
                let bytes = tz+[0];var p = 3;let minus = bytes[p] == 45
                if minus { p += 1 }
                func number(_ from: Int) -> Int32 {
                    var i = from,v: Int32 = 0,negative = false
                    while [UInt8(32),9,10,11,12,13].contains(bytes[i]) { i += 1 }
                    if bytes[i] == 45 || bytes[i] == 43 { negative = bytes[i] == 45;i += 1 }
                    while bytes[i] >= 48 && bytes[i] <= 57 { v = v &* 10 &+ Int32(bytes[i]-48);i += 1 }
                    return negative ? 0 &- v : v
                }
                var bias = number(p) &* 3600
                while bytes[p] == 43 || (bytes[p] >= 48 && bytes[p] <= 57) { p += 1 }
                for scale: Int32 in [60,1] {
                    if bytes[p] != 58 { break };p += 1;bias = bias &+ number(p) &* scale
                    while bytes[p] >= 48 && bytes[p] <= 57 { p += 1 }
                }
                timezone[0] = minus ? 0 &- bias : bias;timezone[1] = Int32(Int8(bitPattern:bytes[p]))
                let end = min(p+3,tz.count);let suffix = Array(tz[p..<end])+[0]
                for (i,b) in suffix.enumerated() { names[64+i] = b }
            }
        } else {
            let response = try source();try observe(.init("timezone",result:response.result))
            if response.result != UInt32.max {
                guard let z = response.zone,z.standard.count == 8,z.daylight.count == 8 else { throw Self.error("Timezone response") }
                zone = z;osZone = true
                timezone[0] = z.bias &* 60
                if z.standard[1] != 0 { timezone[0] = timezone[0] &+ z.standardBias &* 60 }
                let daylight = z.daylight[1] != 0 && z.daylightBias != 0
                timezone[1] = daylight ? 1 : 0;timezone[2] = daylight ? (z.daylightBias &- z.standardBias) &* 60 : 0
                for (index,name) in [z.standardName,z.daylightName].enumerated() {
                    let bytes = try convert(name,63);guard !bytes.isEmpty,bytes.count <= 63,bytes.last == 0 else { throw Self.error("Declared successful name conversion") }
                    try observe(.init("nameConversion",bytes:bytes,capacity:63))
                    for (i,b) in bytes.enumerated() { names[index*64+i] = b };names[index*64+63] = 0
                }
            }
        }
        initialized = true
    }
    private mutating func gmt(_ seconds: Int64) throws -> [Int32]? {
        try setTM([Int32](repeating:-1,count:9))
        if seconds < 0 { errno = 22;return nil }
        if seconds > Self.maximum { errno = 22;throw Boundary.invalidParameter }
        let days = Int(seconds/86400);var year = 1970+days/365
        if Self.yearDays(year)>days { year -= 1 }
        let yday = days-Self.yearDays(year);var mday = yday,month = 0
        let lengths = Self.months(year)
        while mday >= lengths[month] { mday -= lengths[month];month += 1 }
        let daySeconds = Int(seconds%86400)
        let result = [daySeconds%60,daySeconds/60%60,daySeconds/3600,mday+1,month,year-1900,(days+4)%7,yday,0].map(Int32.init)
        try setTM(result);return result
    }
    private mutating func isDST(_ tm: [Int32]) throws -> Bool {
        let year = Int(tm[5])+1900
        if cache[0] != tm[5] || cache[3] != tm[5] {
            let standard: [Int32],daylight: [Int32]
            if osZone,let zone { standard = zone.standard;daylight = zone.daylight }
            else if year >= 2007 { standard = [0,11,0,1,2,0,0,0];daylight = [0,3,0,2,2,0,0,0] }
            else { standard = [0,10,0,5,2,0,0,0];daylight = [0,4,0,1,2,0,0,0] }
            for (index,t) in [daylight,standard].enumerated() {
                let month = Int(t[1]);guard (1...12).contains(month) else { throw Self.error("Transition month") }
                let lengths = Self.months(year),first = lengths.prefix(month-1).reduce(0,+)
                var day: Int
                if t[0] == 0 {
                    guard (1...5).contains(t[3]),(0...6).contains(t[2]) else { throw Self.error("Relative transition") }
                    let dow = (Self.yearDays(year)+first+4)%7
                    day = first+(Int(t[2])-dow+7)%7+7*(Int(t[3])-1)
                    if t[3] == 5,day >= first+lengths[month-1] { day -= 7 }
                } else { day = first+Int(t[3])-1 }
                var millis = ((t[4] &* 60 &+ t[5]) &* 60 &+ t[6]) &* 1000 &+ t[7]
                if index == 1 {
                    millis = millis &+ timezone[2] &* 1000
                    if millis < 0 { millis = millis &+ 86_400_000;day -= 1 }
                    else if millis >= 86_400_000 { millis = millis &- 86_400_000;day += 1 }
                }
                cache[index*3] = tm[5];cache[index*3+1] = Int32(day);cache[index*3+2] = millis
            }
        }
        let start = cache[1],end = cache[4],day = tm[7]
        if start < end {
            if day < start || day > end { return false }
            if day > start && day < end { return true }
        } else {
            if day < end || day > start { return true }
            if day > end && day < start { return false }
        }
        let millis = ((tm[2] &* 60 &+ tm[1]) &* 60 &+ tm[0]) &* 1000
        return day == start ? millis >= cache[2] : millis < cache[5]
    }
    private mutating func convert(_ seconds: Int64,environmentTZ: [UInt8]?,timezoneSource: () throws -> (result: UInt32,zone: Zone?),allocate: (Int) throws -> OriginalInterfaceAllocation,convertName: (String,Int) throws -> [UInt8],observe: (OriginalCalendarEvent) throws -> Void) throws -> [Int32]? {
        if tmPointer == 0 {
            tmPointer = try alloc(36,allocate,observe)
            if tmPointer == 0 { errno = 12;throw Boundary.unknownAllocatorReturn }
        }
        try setTM([Int32](repeating:-1,count:9))
        if seconds < 0 { errno = 22;return nil }
        if seconds > Self.maximum { errno = 22;throw Boundary.invalidParameter }
        try initialize(environmentTZ,timezoneSource,allocate,convertName,observe)
        if seconds > 259200 {
            let standard = seconds &- Int64(timezone[0])
            guard var tm = try gmt(standard) else { return nil }
            if timezone[1] != 0,try isDST(tm) {
                guard let summer = try gmt(standard &- Int64(timezone[2])) else { return nil }
                tm = summer;tm[8] = 1;try setTM(tm)
            }
            return tm
        }
        guard var tm = try gmt(seconds) else { return nil }
        let summer = try timezone[1] != 0 && isDST(tm)
        let bias = summer ? timezone[0] &+ timezone[2] : timezone[0]
        var carry = Int64(tm[0])-Int64(bias)
        for (field,divisor) in [(0,Int64(60)),(1,60),(2,24)] {
            if field > 0 { carry += Int64(tm[field]) }
            let remainder = carry%divisor;tm[field] = Int32(remainder < 0 ? remainder+divisor : remainder)
            carry = (carry-Int64(tm[field]))/divisor
        }
        if carry != 0 {
            tm[6] = Int32((Int64(tm[6])+carry+(carry < 0 ? 7 : 0))%7)
            tm[3] &+= Int32(truncatingIfNeeded:carry)
            if carry < 0 && tm[3] <= 0 { tm[7] &+= Int32(truncatingIfNeeded:carry+365);tm[3] &+= 31;tm[5] &-= 1;tm[4] = 11 }
            else { tm[7] &+= Int32(truncatingIfNeeded:carry) }
        }
        if summer { tm[8] = 1 };try setTM(tm);return tm
    }
}
