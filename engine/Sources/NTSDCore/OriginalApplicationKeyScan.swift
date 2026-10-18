/// Original43e9db..43ea95 service-key prefix of the application dispatcher.
/// These values belong to the outer application state; the loaded-match
/// globals do not yet own the whole4593a0/4593a4 region.
public struct OriginalApplicationKeyScan: Equatable {
    public private(set) var sequence: UInt32
    public private(set) var diagnostics: UInt32
    public private(set) var mode: UInt32
    public init(sequence: UInt32, diagnostics: UInt32, mode: UInt32) {
        self.sequence = sequence; self.diagnostics = diagnostics; self.mode = mode
    }

    /// Input is already acquired. The original scans indices0..<250 in order,
    /// recognizes byte100, and never consumes or changes a key byte here.
    /// Observers must buffer effects until the enclosing operation commits.
    public mutating func apply(keyboard: [UInt8],
        observe: (UInt32, UInt32) throws -> Void = { _,_ in }) throws {
        guard keyboard.count == 300 else { throw OriginalStateError.invalidStorage("Application keyboard extent") }
        var next = self
        for key in 0..<250 where keyboard[key] == 100 {
            switch next.sequence {
            case 0: next.sequence = key == 65 ? 1 : 0
            case 1:
                if key == 66 { next.sequence = 2 }
                else if key != 65 { next.sequence = 0 }
            case 2:
                if key == 67 { next.sequence = 3; next.diagnostics = 1 }
                else if key != 66 { next.sequence = 0 }
            case 3: if key != 67 { next.sequence = 0 }
            default: next.sequence = 0
            }
        }
        try observe(0x450bec,next.diagnostics)
        try observe(0x4593a4,next.sequence)
        if next.diagnostics != 0 {
            for key in 112...114 where keyboard[key] == 100 {
                next.mode = UInt32(key-112)
                try observe(0x4593a0,next.mode)
            }
        }
        self = next
    }
}
