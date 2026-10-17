import Foundation

/// Target-owned Object allocation. Its body is cleared by 40e540 itself;
/// applying the 2.4 per-Frame constructor here would change bytes and masks.
public struct NTSD2833ObjectStorage: Sendable {
    public static let allocationSize = 0x69e00
    public static let frameBase = 0x830, frameStride = 0x1b0
    /// Allocation extent, distinct from the source parser's signed `<1000` test.
    public static let completeFrameRecords = (allocationSize - frameBase) / frameStride

    public enum Boundary: Error, Equatable {
        case allocationExtent
        case filenameOwner
        case unsupportedOuterTag([UInt8])
        case boxPostprocessing(offset: Int, count: Int32)
        case callerHelper(UInt32)
        case frameOutsideAllocation(Int)
    }
    public enum Event: Equatable, Sendable {
        case open(bytes: Int, cursor: Int)
        case token(bytes: [UInt8], before: Int, after: Int)
        case eof(cursor: Int, ended: Bool)
        case close, releaseBuffer, releaseCursor
    }
    public struct Receipt: Equatable, Sendable {
        public let events: [Event]
        public let liveStreamOwners: Int
    }
    public private(set) var storage: OriginalStateRecord
    public let fileName: [UInt8]
    private let filenameIdentity: UInt32

    /// A prepared header supplies its owned filename and identity. This does not
    /// manufacture the still-open header/file acquisition contract or import a
    /// source after-state. The ordinary application uses its own identities;
    /// reference checks may supply a declared allocator-boundary identity.
    public init(storage: OriginalStateRecord, fileName: [UInt8]) throws {
        guard storage.byteCount == Self.allocationSize else { throw Boundary.allocationExtent }
        guard fileName.count >= 3, !fileName.contains(0) else { throw Boundary.filenameOwner }
        let identity = try storage.integer(at: 0x7a8, as: UInt32.self)
        guard identity != 0 else { throw Boundary.filenameOwner }
        self.storage = storage; self.fileName = fileName; filenameIdentity = identity
    }
    /// Incoming parent updates preserve the same owner and all untouched bytes.
    public mutating func writeIncomingWord(_ value: UInt32, at offset: Int) throws {
        try storage.write(value, at: offset)
    }
    /// Physical record extent only. The source admits parser index999 even
    /// though it starts beyond this allocation. Its backing/outcome is open;
    /// rejecting that read here is not a match to an observed source fault.
    public func frameStorage(at index: Int) throws -> OriginalStateRecord {
        guard index >= 0, index < Self.completeFrameRecords else {
            throw Boundary.frameOutsideAllocation(index)
        }
        let start = Self.frameBase + index * Self.frameStride
        return storage.extract(start..<start + Self.frameStride)
    }
    /// State at record+8 is the field read by the identified target AI accesses.
    /// This getter does not establish the rest of AI or target gameplay.
    public func frameState(at index: Int) throws -> Int32 {
        let frame = try frameStorage(at: index)
        return try frame.integer(at: 8, as: Int32.self)
    }

    // Complete nonmatching outer-token route, source40e62b..41120d. These known
    // branches must remain explicit boundaries until their actual children and
    // storage are transferred; silently ignoring a recognized tag is incorrect.
    private static let outerTags: Set<[UInt8]> = Set([
        "<bmp_begin>", "<weapon_piece>", "<weapon_strength_list>", "<armor>",
        "<stats>", "<stats_count>", "<hp_bar>", "<mp_bar>", "<team_flag>",
        "<name>", "<minibar>", "<bossbar>", "<pic>", "<effect>", "<radar>",
        "<weapon>", "<sound>", "<frame>"
    ].map { Array($0.utf8) })

    private mutating func word(_ value: UInt32, at offset: Int,
                               observe: ((Int, UInt32) -> Void)?) throws {
        try storage.write(value, at: offset)
        observe?(offset, value)
    }
    private mutating func initializeBody(observe: ((Int, UInt32) -> Void)?) throws {
        for offset in stride(from: 0x7f8, to: Self.allocationSize, by: 4) {
            try word(0, at: offset, observe: observe)
        }
        for offset in stride(from: 0x90, through: 0xa0, by: 4) {
            try word(0, at: offset, observe: observe)
        }
        for offset in stride(from: 0xa4, through: 0xac, by: 4) {
            try word(UInt32.max, at: offset, observe: observe)
        }
        for offset in [4, 0x1c, 0x600] { try word(0, at: offset, observe: observe) }
        for offset in stride(from: 0xb0, to: 0x498, by: 4) {
            try word(0, at: offset, observe: observe)
        }
        for offset in stride(from: 0x62c, to: 0x654, by: 4) {
            try word(3000, at: offset, observe: observe)
        }
    }
    private mutating func afterToken(observe: ((Int, UInt32) -> Void)?) throws {
        // Actual45c500: these stores occur after each token, not only at EOF.
        for (source, destination) in [(0, 4), (0x18, 0x1c)] {
            if try storage.integer(at: destination, as: UInt32.self) == 0 {
                try word(storage.integer(at: source, as: UInt32.self), at: destination, observe: observe)
            }
        }
        for offset in [0x98, 0x704, 0x740, 0x748, 0x714] {
            let count = try storage.integer(at: offset, as: Int32.self)
            guard count <= 0 else { throw Boundary.boxPostprocessing(offset: offset, count: count) }
        }
    }
    /// Complete body-caller behavior in the currently compared Frame-free domain.
    /// Unsupported children/read boundaries throw with public state unchanged.
    /// The diagnostic store callback may observe a failed candidate's partial
    /// work, like the baseline loader callbacks; it cannot commit that state.
    @discardableResult
    public mutating func loadBody(_ file: NTSD2833FileBytes,
                                 onStore: ((Int, UInt32) -> Void)? = nil) throws -> Receipt {
        guard file.fileName == fileName,
              try storage.integer(at: 0x7a8, as: UInt32.self) == filenameIdentity else {
            throw Boundary.filenameOwner
        }
        var candidate = self
        try candidate.initializeBody(observe: onStore)
        var stream = NTSD2833TokenStream(file)
        var events: [Event] = [.open(bytes: file.endOffset, cursor: file.cursorOffset)]
        var untilLoadingPump = 32
        defer { if !stream.isClosed { stream.close() } }
        repeat {
            let token = try stream.readString()
            events.append(.token(bytes: token.cStringBytes, before: token.before, after: token.after))
            untilLoadingPump -= 1
            // 40e618..40e626 calls425010 here, resetting the next interval to100.
            // Its actual effects are an open dependency, not a no-op callback.
            guard untilLoadingPump != 0 else { throw Boundary.callerHelper(0x425010) }
            guard !Self.outerTags.contains(token.cStringBytes) else {
                throw Boundary.unsupportedOuterTag(token.cStringBytes)
            }
            try candidate.afterToken(observe: onStore)
            let ended = try stream.isAtEnd()
            events.append(.eof(cursor: stream.cursorOffset, ended: ended))
            if ended { break }
        } while true
        stream.close()
        events += [.close, .releaseBuffer, .releaseCursor]
        self = candidate
        return .init(events: events, liveStreamOwners: stream.isClosed ? 0 : 2)
    }
}
