import Foundation

/// Original413080..4132ef: edge history, nine combo recognizers and DAT
/// hit_a/hit_d/hit_j transfers. Movement and the surrounding400-slot caller
/// follow this component; this is not an entire control routine or tick.
public enum OriginalActorInput {
    public static func apply(actor: inout OriginalStateRecord, object: OriginalLoadedObject,
                             globals: OriginalStateRecord) throws {
        try apply(actor: &actor, sourceID: object.header.integer(at: 0x6f4, as: Int32.self),
                  globals: globals, frame: { index in
            guard object.frameStorage.indices.contains(Int(index)) else {
                throw OriginalStateError.invalidStorage("Actor input frame outside Object: \(index)")
            }
            return object.frameStorage[Int(index)]
        })
    }

    static let buffers = [0xbe, 0xbf, 0xc0, 0xc3, 0xc4, 0xc5, 0xc2]
    static func apply(actor: inout OriginalStateRecord, sourceID: Int32,
                      globals: OriginalStateRecord, frame: (Int32) throws -> OriginalStateRecord) throws {
        var candidate = actor
        try captureEdges(actor: &candidate)
        try recognizeCombos(actor: &candidate, sourceID: sourceID, globals: globals, frame: frame)
        try applyFrameInput(actor: &candidate, globals: globals, frame: frame)
        actor = candidate
    }

    /// Positive SIGNED bytes decay. Edges require previous==0/current==1,
    /// not arbitrary truthiness.40e450 shifts five32-bit history cells per edge.
    static func captureEdges(actor: inout OriginalStateRecord) throws {
        for offset in [0xc2, 0xc3, 0xc4, 0xc5, 0xbf, 0xbe, 0xc0, 0xc1] {
            let value = try actor.integer(at: offset, as: Int8.self)
            if value > 0 { try actor.write(value &- 1, at: offset) }
        }
        for (previous, current, buffer, code) in [
            (0xc9,0xd0,0xc2,6),(0xc8,0xcf,0xc3,4),(0xc6,0xcd,0xc4,8),
            (0xc7,0xce,0xc5,2),(0xcc,0xd3,0xc0,9),(0xcb,0xd2,0xbf,0),(0xca,0xd1,0xbe,5)
        ] where try actor.integer(at: previous, as: UInt8.self) == 0 && actor.integer(at: current, as: UInt8.self) == 1 {
            try actor.write(UInt8(5), at: buffer)
            for offset in stride(from: 0x408, through: 0x414, by: 4) {
                try actor.write(actor.integer(at: offset+4, as: UInt32.self), at: offset)
            }
            try actor.write(Int32(code), at: 0x418)
        }
    }

    ///40e170. The flag means that this recognizer advanced during this call;
    /// only then may the last accepted edge coexist with the next stage.
    static func invalidates(actor: OriginalStateRecord, key: UInt8, advanced: Int32) throws -> Bool {
        let excluded: Int?
        if advanced == 0 { excluded = nil }
        else if advanced == 1 {
            switch key {
            case 0x55: excluded = 0xc4
            case 0x44: excluded = 0xc5
            case 0x4c: excluded = 0xc3
            case 0x52: excluded = 0xc2
            case 0x64: excluded = 0xc0
            case 0x6a: excluded = 0xbf
            case 0x61: excluded = 0xbe
            default: return false
            }
        } else { return false }
        return try buffers.contains { try $0 != excluded && actor.integer(at: $0, as: UInt8.self) == 5 }
    }

    ///40e2d0..40e445.999 maps to standing; a negative target requests turning
    /// only on the resource-enabled successful path. Absent frames do nothing.
    static func transfer(actor: inout OriginalStateRecord, target: Int32,
                         globals: OriginalStateRecord, frame: (Int32) throws -> OriginalStateRecord) throws {
        var destination = target < 0 ? 0 &- target : target
        if destination == 999 { destination = 0 }
        let next = try frame(destination)
        guard try next.integer(at: 0, as: UInt8.self) != 0 else { return }
        if try globals.integer(at: 0x44d034-OriginalMatchPreparation.globalBase, as: Int32.self) != 0 {
            let cost = try next.integer(at: 0x4c, as: Int32.self)
            let healthCost = (cost/1000) &* 10, chakraCost = cost%1000
            let chakra = try actor.integer(at: 0x308, as: Int32.self)
            guard chakra >= chakraCost else { return }
            let health = try actor.integer(at: 0x2fc, as: Int32.self)
            guard health > healthCost else { return }
            try actor.write(health &- healthCost, at: 0x2fc)
            try actor.write(chakra &- chakraCost, at: 0x308)
            try actor.write(actor.integer(at: 0x34c, as: Int32.self) &+ healthCost, at: 0x34c)
            try actor.write(actor.integer(at: 0x350, as: Int32.self) &+ chakraCost, at: 0x350)
            try actor.write(destination, at: 0x70)
            if target < 0 { try actor.write(UInt8(1) &- actor.integer(at: 0x80, as: UInt8.self), at: 0x80) }
        } else {
            try actor.write(destination, at: 0x70)
        }
        for offset in [0xbf, 0xbe, 0xc0, 0xc5, 0xc4, 0xc3, 0xc2] { try actor.write(UInt8(0), at: offset) }
    }

    ///412800..413077. Each later recognizer observes transfers and buffer
    /// clears made by earlier recognizers, using the actor's NEW current frame.
    static func recognizeCombos(actor: inout OriginalStateRecord, sourceID: Int32,
                                globals: OriginalStateRecord, frame: (Int32) throws -> OriginalStateRecord) throws {
        let routes: [(direction: Int, key: UInt8, finish: Int, finishKey: UInt8, field: Int, facing: UInt8?)] = [
            (0xc2,0x52,0xbe,0x61,0x30,0),(0xc3,0x4c,0xbe,0x61,0x30,1),
            (0xc4,0x55,0xbe,0x61,0x34,nil),(0xc5,0x44,0xbe,0x61,0x38,nil),
            (0xc2,0x52,0xbf,0x6a,0x3c,0),(0xc3,0x4c,0xbf,0x6a,0x3c,1),
            (0xc4,0x55,0xbf,0x6a,0x40,nil),(0xc5,0x44,0xbf,0x6a,0x44,nil),
            (0xbf,0x6a,0xbe,0x61,0x48,nil)
        ]
        for (index, route) in routes.enumerated() {
            let progress = 0xd4+index
            var advanced: Int32 = 0
            if try actor.integer(at: progress, as: UInt8.self) == 0 && actor.integer(at: 0xc0, as: UInt8.self) == 5 {
                try actor.write(UInt8(1), at: progress); advanced = 1
            }
            if try actor.integer(at: progress, as: UInt8.self) == 1 {
                if try actor.integer(at: route.direction, as: UInt8.self) == 5 {
                    try actor.write(UInt8(2), at: progress); advanced = 1
                } else if try invalidates(actor: actor, key: 0x64, advanced: advanced) {
                    try actor.write(UInt8(0), at: progress)
                }
            }
            if try actor.integer(at: progress, as: UInt8.self) == 2 {
                if try actor.integer(at: route.finish, as: UInt8.self) == 5 {
                    try actor.write(UInt8(3), at: progress); advanced = 1
                } else if try invalidates(actor: actor, key: route.key, advanced: advanced) {
                    try actor.write(UInt8(0), at: progress)
                }
            }
            guard try actor.integer(at: progress, as: UInt8.self) == 3 else { continue }
            let current = try frame(actor.integer(at: 0x70, as: Int32.self))
            let target = try current.integer(at: route.field, as: Int32.self)
            //412fdd..41300f: original source-ID6/hit_ja300/HP177 exception.
            // This leaves progress3 intact, before either transfer or invalidation.
            if try index == 8 && sourceID == 6 && target == 300 &&
                actor.integer(at: 0x2fc, as: Int32.self) > 177 &&
                globals.integer(at: 0x458428-OriginalMatchPreparation.globalBase, as: Int32.self) == 0 { continue }
            if try target != 0 && (index != 8 || actor.integer(at: 0x324, as: Int32.self) == -1) &&
                actor.integer(at: 0x98, as: Int32.self) != 2 {
                try transfer(actor: &actor, target: target, globals: globals, frame: frame)
                if let facing = route.facing { try actor.write(facing, at: 0x80) }
                try actor.write(UInt8(0), at: progress)
            } else if try index == 8 && actor.integer(at: 0x328, as: Int32.self) == 1 {
                try actor.write(Int32(0), at: 0x338)
            } else if try invalidates(actor: actor, key: route.finishKey, advanced: advanced) {
                try actor.write(UInt8(0), at: progress)
            }
        }
    }

    ///41324c..4132ef. Strict signed-buffer comparisons reject ties. Only the
    /// first applicable DAT action is attempted; its buffer clears on failure too.
    static func applyFrameInput(actor: inout OriginalStateRecord, globals: OriginalStateRecord,
                                frame: (Int32) throws -> OriginalStateRecord) throws {
        let current = try frame(actor.integer(at: 0x70, as: Int32.self))
        for (field, buffer, others) in [(0x24,0xbe,[0xc0,0xbf]),(0x28,0xc0,[0xbe,0xbf]),(0x2c,0xbf,[0xbe,0xc0])] {
            let target = try current.integer(at: field, as: Int32.self)
            if target == 0 { continue }
            let value = try actor.integer(at: buffer, as: Int8.self)
            if try others.allSatisfy({ value > (try actor.integer(at: $0, as: Int8.self)) }) {
                try transfer(actor: &actor, target: target, globals: globals, frame: frame)
                try actor.write(UInt8(0), at: buffer)
                return
            }
        }
    }
}
