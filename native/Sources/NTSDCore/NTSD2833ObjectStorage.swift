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
        case unsupportedFrameTag([UInt8])
        case boxPostprocessing(offset: Int, count: Int32)
        case callerHelper(UInt32)
        case frameOutsideAllocation(Int)
    }
    public enum Event: Equatable, Sendable {
        case open(bytes: Int, cursor: Int)
        case token(bytes: [UInt8], before: Int, after: Int)
        case integer(bits: UInt32, before: Int, after: Int)
        case messageBox(text: [UInt8], caption: [UInt8], flags: UInt32)
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
    private static func frameOffset(_ index: Int32) throws -> Int {
        let bits = UInt32(bitPattern: index) &* UInt32(frameStride) &+ UInt32(frameBase)
        let offset = Int(Int32(bitPattern: bits))
        guard offset >= 0, offset <= allocationSize-frameStride else {
            throw Boundary.frameOutsideAllocation(Int(index))
        }
        return offset
    }
    /// The actual caller's32-bit index arithmetic, including proved aliases.
    /// This is separate from the ordinary physical-record enumeration above.
    public func frameState(rawIndex: Int32) throws -> Int32 {
        try storage.integer(at: Self.frameOffset(rawIndex)+8, as: Int32.self)
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
    private static let integerFrameFields: [[UInt8]: Int] = [
        Array("pic:".utf8): 4, Array("state:".utf8): 8,
        Array("wait:".utf8): 0x0c, Array("next:".utf8): 0x10
    ]
    private static let otherFrameTags: Set<[UInt8]> = Set([
        "dvx:", "dvy:", "dvz:", "centerx:", "centery:", "hit_a:", "hit_d:", "hit_j:",
        "hit_Fa:", "hit_Ua:", "hit_Da:", "hit_Fj:", "hit_Uj:", "hit_Dj:", "hit_ja:",
        "hit_aj:", "hit_jd:", "hit_ad:", "hit_g:", "respond:", "chp:", "cmp:", "hit_f:",
        "hit_b:", "hit_uz:", "hit_dz:", "hold_a:", "hold_d:", "hold_j:", "hold_f:",
        "hold_b:", "hold_uz:", "hold_dz:", "shadow:", "loop:", "amount:", "bound:",
        "cover:", "attacking:", "action:", "centerz:", "caughtact:", "y:", "## reserve ##",
        "hp:", "mp:", "dx:", "dy:", "dz:", "sound:", "opoint:", "bpoint:", "cpoint:",
        "wpoint:", "ppoint:", "itr:", "bdy:"
    ].map { Array($0.utf8) })

    private mutating func word(_ value: UInt32, at offset: Int,
                               observe: ((Int, Int, UInt32) -> Void)?) throws {
        try storage.write(value, at: offset)
        observe?(offset, 4, value)
    }
    private mutating func initializeBody(observe: ((Int, Int, UInt32) -> Void)?) throws {
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
    private mutating func afterToken(observe: ((Int, Int, UInt32) -> Void)?) throws {
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
    private static func loadingStep(_ remaining: inout Int) throws {
        remaining -= 1
        guard remaining != 0 else { throw Boundary.callerHelper(0x425010) }
    }
    private mutating func loadFrame(initialToken: [UInt8], stream: inout NTSD2833TokenStream,
                                    events: inout [Event], untilPump: inout Int,
                                    observe: ((Int, Int, UInt32) -> Void)?) throws {
        let index = try stream.readInteger()
        events.append(.integer(bits: index.bits, before: index.before, after: index.after))
        if index.value >= 1000 {
            // The caller ignores MessageBoxA's result and resumes its outer
            // stream. This receipt is an owned UI request, not a Windows call.
            events.append(.messageBox(text: Array("Unable to create memory space for frame!".utf8),
                                      caption: fileName, flags: 0))
            return
        }
        let base = try Self.frameOffset(index.value)
        if try storage.integer(at: base, as: UInt32.self) != 0 { return }
        try storage.write(UInt8(1), at: base)
        observe?(base, 1, 1)
        var token = initialToken
        repeat {
            try Self.loadingStep(&untilPump)
            if let field = Self.integerFrameFields[token] {
                let value = try stream.readInteger()
                events.append(.integer(bits: value.bits, before: value.before, after: value.after))
                try word(value.bits, at: base+field, observe: observe)
            } else if Self.otherFrameTags.contains(token) {
                throw Boundary.unsupportedFrameTag(token)
            }
            let next = try stream.readString()
            events.append(.token(bytes: next.cStringBytes, before: next.before, after: next.after))
            token = next.cStringBytes
            if token == Array("<frame_end>".utf8) { break }
        } while true
        for (countOffset, pointerOffset, helper): (Int, Int, UInt32) in
            [(0x78, 0x7c, 0x44e1a0), (0x128, 0x130, 0x44e160), (0x12c, 0x134, 0x44e1e0)] {
            if try storage.integer(at: base+countOffset, as: Int32.self) > 0 {
                // The pointer read precedes the child call. Undefined alias
                // bytes cannot be replaced with a guessed null or helper result.
                _ = try storage.integer(at: base+pointerOffset, as: UInt32.self)
                throw Boundary.callerHelper(helper)
            }
        }
    }
    /// Body-caller behavior for the compared token and integer Frame domain.
    /// Unsupported children/read boundaries throw with public state unchanged.
    /// The diagnostic store callback may observe a failed candidate's partial
    /// work, like the baseline loader callbacks; it cannot commit that state.
    @discardableResult
    public mutating func loadBody(_ file: NTSD2833FileBytes,
                                 onWrite: ((Int, Int, UInt32) -> Void)? = nil) throws -> Receipt {
        guard file.fileName == fileName,
              try storage.integer(at: 0x7a8, as: UInt32.self) == filenameIdentity else {
            throw Boundary.filenameOwner
        }
        var candidate = self
        try candidate.initializeBody(observe: onWrite)
        var stream = NTSD2833TokenStream(file)
        var events: [Event] = [.open(bytes: file.endOffset, cursor: file.cursorOffset)]
        var untilLoadingPump = 32
        defer { if !stream.isClosed { stream.close() } }
        repeat {
            let token = try stream.readString()
            events.append(.token(bytes: token.cStringBytes, before: token.before, after: token.after))
            // 40e618..40e626 calls425010 here, resetting the next interval to100.
            // Its actual effects are an open dependency, not a no-op callback.
            try Self.loadingStep(&untilLoadingPump)
            if token.cStringBytes == Array("<frame>".utf8) {
                try candidate.loadFrame(initialToken: token.cStringBytes, stream: &stream, events: &events,
                                        untilPump: &untilLoadingPump, observe: onWrite)
            } else if Self.outerTags.contains(token.cStringBytes) {
                throw Boundary.unsupportedOuterTag(token.cStringBytes)
            }
            try candidate.afterToken(observe: onWrite)
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
