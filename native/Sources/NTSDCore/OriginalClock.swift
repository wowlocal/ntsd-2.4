/// Normal timer branch at 0x43d157–0x43d19e. Caller supplies monotonic Windows-
/// style UInt32 milliseconds; wrapping subtraction also covers the 49-day rollover.
public struct OriginalClock {
    public private(set) var baseline: UInt32?
    public init() {}
    public mutating func reset() { baseline = nil }
    public mutating func ticks(at now: UInt32) -> Int {
        guard var time = baseline else { baseline = now; return 0 }
        var count = 0
        while now &- time > 33 {
            if now &- time > 100 { time = now &- 100 }
            time &+= 33; count += 1
        }
        baseline = time
        return count
    }
}

/// District layers have no loops/rectangles: original 0x41a2b0–0x41a3ce.
/// cc is the divisor itself (not cc + 1), and both c1/c2 endpoints are inclusive.
public struct OriginalBackgroundLayer {
    public let fields: Fields
    public private(set) var counter = 0
    public init(fields: Fields) { self.fields = fields }
    public mutating func tick() {
        let cycle = fields.integer("cc")
        if cycle > 0 { counter = (counter + 1) % cycle }
    }
    public var visible: Bool {
        fields.integer("cc") <= 0 || (fields.integer("c1")...fields.integer("c2")).contains(counter)
    }
    public func x(camera: Int, arenaWidth: Int = 960) -> Int {
        fields.integer("x") - (arenaWidth > 794 ? (fields.integer("width") - 794) * camera / (arenaWidth - 794) : 0)
    }
}
