import Foundation
import NTSDCore

/// GetTimeZoneInformation-shaped data derived from a macOS time zone. This is a
/// declared runtime conversion, not a Windows observation: Bias and the annual
/// DST rule decide the CRT local time; Windows registry display names are not
/// derivable, so the zone's English standard/daylight names are used within WCHAR[32].
public enum OriginalMacRuntimeZone {
    public enum Boundary: Error, Equatable { case unsupportedRule(String), nonASCIIName(String), nameCapacity(Int) }
    public static let unknown: UInt32 = 0, standard: UInt32 = 1, daylight: UInt32 = 2

    /// SYSTEMTIME in the Windows "day-in-month" form: year0, month, weekday
    /// (0 Sunday), week1...5 (5 = last), then the local wall-clock time.
    static func rule(_ instant: Date,_ wall: TimeZone) -> [Int32] {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
        // Wall clock immediately before the transition, in the offset then in force.
        let before = instant.addingTimeInterval(-1)
        let local = before.addingTimeInterval(TimeInterval(wall.secondsFromGMT(for:before))+1)
        let c = calendar.dateComponents([.year,.month,.day,.weekday,.hour,.minute,.second],from:local)
        let days = calendar.range(of:.day,in:.month,for:local)!.count
        let day = c.day!,week = day+7 > days ? 5 : (day-1)/7+1
        return [0,Int32(c.month!),Int32(c.weekday!-1),Int32(week),Int32(c.hour!),Int32(c.minute!),Int32(c.second!),0]
    }
    static func name(_ zone: TimeZone,_ style: NSTimeZone.NameStyle) throws -> String {
        let text = zone.localizedName(for:style,locale:Locale(identifier:"en_US_POSIX")) ?? zone.identifier
        guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value < 0x7f }) else { throw Boundary.nonASCIIName(text) }
        return String(text.prefix(31))
    }
    /// The result code describes `now`; the rule is the calendar year of `now`.
    public static func information(_ zone: TimeZone,now: Date) throws -> OriginalApplicationPreparedStartupPlatform.Zone {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = zone
        let year = calendar.component(.year,from:now)
        let start = calendar.date(from:DateComponents(year:year,month:1,day:1))!
        let end = calendar.date(from:DateComponents(year:year+1,month:1,day:1))!
        var transitions: [Date] = [],cursor = start
        while let next = zone.nextDaylightSavingTimeTransition(after:cursor),next < end,transitions.count < 4 {
            transitions.append(next); cursor = next
        }
        let standardSeconds = zone.isDaylightSavingTime(for:start) ? zone.secondsFromGMT(for:start)-Int(zone.daylightSavingTimeOffset(for:start)) : zone.secondsFromGMT(for:start)
        guard standardSeconds%60 == 0 else { throw Boundary.unsupportedRule("second-level offset") }
        let bias = Int32(-standardSeconds/60)
        let standardName = try name(zone,.standard),daylightName = try name(zone,.daylightSaving)
        if transitions.isEmpty {
            let value = OriginalCalendarTime.Zone(bias:bias,standard:[Int32](repeating:0,count:8),daylight:[Int32](repeating:0,count:8),
                standardBias:0,daylightBias:0,standardName:standardName,daylightName:daylightName)
            return .init(unknown,value)
        }
        guard transitions.count == 2 else { throw Boundary.unsupportedRule("\(transitions.count) transitions in \(year)") }
        let into = transitions.first { zone.isDaylightSavingTime(for:$0) }
        let out = transitions.first { !zone.isDaylightSavingTime(for:$0) }
        guard let into,let out else { throw Boundary.unsupportedRule("transition direction") }
        let saving = zone.daylightSavingTimeOffset(for:into)
        guard saving > 0,Int(saving)%60 == 0 else { throw Boundary.unsupportedRule("daylight offset") }
        let value = OriginalCalendarTime.Zone(bias:bias,standard:rule(out,zone),daylight:rule(into,zone),
            standardBias:0,daylightBias:Int32(-Int(saving)/60),standardName:standardName,daylightName:daylightName)
        return .init(zone.isDaylightSavingTime(for:now) ? daylight : standard,value)
    }
    /// WideCharToMultiByte(CP_ACP, 0, name, -1, buffer, capacity) for ASCII
    /// names: the written bytes including NUL. Other code pages stay unsupported.
    public static func convert(_ name: String,capacity: Int) throws -> [UInt8] {
        guard name.unicodeScalars.allSatisfy({ $0.value < 0x80 }) else { throw Boundary.nonASCIIName(name) }
        let bytes = Array(name.utf8)+[0]
        guard bytes.count <= capacity else { throw Boundary.nameCapacity(capacity) }
        return bytes
    }
}
