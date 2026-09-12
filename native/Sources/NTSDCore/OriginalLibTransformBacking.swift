/// Explicit ownership for the bundled library's write beyond Actor+420.
/// A destination describes supplied allocation backing, never assumed heap
/// adjacency. Address tokens are required only for a pointer-valued write.
/// Empty backing rejects the first extended write; it does not skip the hook.
public struct OriginalLibTransformBacking: Equatable {
    public enum Destination: Equatable {
        case actor(index: Int, offset: Int)
        case external(index: Int, offset: Int)
    }
    public let destinations: [Int: Destination]
    public let actorAddressTokens: [Int: UInt32]
    public private(set) var externalRecords: [OriginalStateRecord]

    public init(destinations: [Int: Destination] = [:], actorAddressTokens: [Int: UInt32] = [:],
                externalRecords: [OriginalStateRecord] = []) {
        self.destinations = destinations; self.actorAddressTokens = actorAddressTokens
        self.externalRecords = externalRecords
    }

    mutating func write(actor: Int, matched: Bool, scanned: Int32, actors: inout [OriginalStateRecord]) throws {
        func error(_ reason: String) -> OriginalStateError { .invalidStorage("Library transform +7b4: "+reason) }
        guard let target = destinations[actor] else { throw error("Unavailable destination backing") }
        let value: UInt32
        if matched {
            guard let token = actorAddressTokens[actor] else { throw error("Unavailable Actor address token") }
            value = token
        } else { value = UInt32(bitPattern: scanned) }
        switch target {
        case let .actor(index, offset):
            guard actors.indices.contains(index) else { throw error("Actor destination binding") }
            try actors[index].write(value, at: offset)
        case let .external(index, offset):
            guard externalRecords.indices.contains(index) else { throw error("External destination binding") }
            try externalRecords[index].write(value, at: offset)
        }
    }
}
