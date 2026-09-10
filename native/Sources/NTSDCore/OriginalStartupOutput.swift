import Foundation

/// Whole WinMain43cfb4..43d078. Platform responses are explicit inputs until
/// the application adapter owns them. Dates, expiry arithmetic, calendar caches
/// and music allocations come from this caller's own computations.
public struct OriginalStartupOutput {
    public enum Boundary: Error, Equatable { case nullCalendarRead(address: UInt32) }
    public struct Result: Equatable {
        public let time: UInt64, expiry: Int64, calendars: [[Int32]], dates: [[UInt8]]
        public let cursor: UInt32, previousCursor: UInt32
    }
    public private(set) var calendar: OriginalCalendarTime
    public private(set) var music: OriginalMusicMemory
    public init(calendar: OriginalCalendarTime = .init(),music: OriginalMusicMemory = .init()) {
        self.calendar = calendar;self.music = music
    }
    /// Callbacks must stage external effects until the encompassing startup
    /// commits. Every owned value and global byte rolls back if any callback or
    /// calendar boundary throws, including after both cursor requests.
    @discardableResult
    public mutating func run(globals: inout OriginalStateRecord,
        filetime: () throws -> UInt64,environmentTZ: [UInt8]? = nil,
        timezoneSource: () throws -> (result: UInt32,zone: OriginalCalendarTime.Zone?),
        allocateCalendar: (Int) throws -> OriginalInterfaceAllocation,
        convertName: (String,Int) throws -> [UInt8],
        observeCalendar: (OriginalCalendarEvent) throws -> Void = { _ in },
        returnedCalendar: (Int64,[Int32]?) throws -> Void = { _,_ in },
        formatted: (Int,[Int32],[UInt8]) throws -> Void = { _,_,_ in },
        requestMusic: OriginalMusicPlayback.Request,
        requestCursor: (_ load: Bool,_ arguments: [UInt32]) throws -> UInt32,
        store: OriginalWindowInput.Store = { _,_ in },
        after: (OriginalStartupOutput,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Startup output globals extent")
        }
        var candidate = self,state = globals,output: OriginalStateRecord?
        let time = try OriginalCalendarTime.readClock(filetime:filetime,output:&output,observe:observeCalendar)
        var calendars: [[Int32]] = [],dates: [[UInt8]] = []
        func date(_ seconds: Int64,_ address: Int,_ nullRead: UInt32,_ failureReturn: UInt32?) throws {
            let tm = try candidate.calendar.local(seconds,environmentTZ:environmentTZ,
                allocationFailureReturn:failureReturn,timezoneSource:timezoneSource,
                allocate:allocateCalendar,convertName:convertName,observe:observeCalendar)
            try returnedCalendar(seconds,tm)
            guard let tm else { throw Boundary.nullCalendarRead(address:nullRead) }
            let values = [tm[5] &+ 1900,tm[4] &+ 1,tm[3],tm[2],tm[1],tm[0]]
            // Original %04d/%02d/... uses minimum widths, including sign before
            // zero padding. The calendar owns all six signed integer operands.
            let fields = values.enumerated().map { index,value -> [UInt8] in
                let magnitude = Array(String(Int64(value).magnitude).utf8)
                let sign: [UInt8] = value < 0 ? [45] : []
                let width = index == 0 ? 4 : 2
                return sign+[UInt8](repeating:48,count:max(0,width-sign.count-magnitude.count))+magnitude
            }
            let bytes: [UInt8] = fields.enumerated().flatMap { index,field -> [UInt8] in
                index == 0 ? field : [UInt8(47)]+field
            }+[0]
            for (index,byte) in bytes.enumerated() { try state.write(byte,at:address-OriginalMatchPreparation.globalBase+index) }
            try store(address,bytes);try formatted(address,values,bytes)
            calendars.append(tm);dates.append(bytes)
        }
        // _time64(0) itself leaves ECX0; the first tmBuffer push ecx owns this
        // allocation-failure return. The second call reuses the retained tm.
        try date(Int64(bitPattern:time),0x451d48,0x43cfd3,0)
        let period = try state.integer(at:0x44d788-OriginalMatchPreparation.globalBase,as:Int32.self)
        let expiry = Int64(bitPattern:time) &+ Int64(period &* 86400)
        try date(expiry,0x458350,0x43d028,nil)
        try OriginalMusicPlayback.play(Array("bgm\\main.wma".utf8),globals:&state,memory:&candidate.music,request:requestMusic,store:store)
        let cursor = try requestCursor(true,[0,0x7f00])
        let previous = try requestCursor(false,[cursor])
        try after(candidate,state)
        self = candidate;globals = state
        return .init(time:time,expiry:expiry,calendars:calendars,dates:dates,cursor:cursor,previousCursor:previous)
    }
}
