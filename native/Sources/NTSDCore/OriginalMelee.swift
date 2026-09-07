import Foundation

public struct MeleeState: Codable, Equatable, Sendable {
    public var actors: [FighterState]
    public var sounds: [String]
    public var randomIndex: Int, randomCounter: Int
    public var cameraX: Int, cameraVelocity: Int
}

/// Original two-fighter collision/hit pipeline. Only unarmed type-0 melee and
/// passive falling bodies are supported here; see the measured domain in COMBAT.md.
public struct OriginalMelee {
    public private(set) var fighters: [OriginalFighter]
    public private(set) var random: OriginalRandom
    private var cameraX = 0, cameraVelocity = 0
    private var sounds: [String] = []
    private let voices: [Int: OriginalFrameRecord]

    public init(headers: [Fields], definitions: [[String]], voiceDefinitions: [String], random: OriginalRandom,
                initial: [FighterState]? = nil) throws {
        try random.validate()
        guard headers.count == 2, definitions.count == 2, initial == nil || initial?.count == 2 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Melee practice requires two fighters")
        }
        self.random = random
        var loader = OriginalFrameLoader()
        for definition in voiceDefinitions { try loader.apply(definition) }
        voices = loader.frames
        guard Set(voices.keys) == [200,201,207,208], voices.values.allSatisfy({
            $0.field("pic") == 999 && $0.field("wait") == 0 && $0.field("next") == 1000
            && $0.interactions.isEmpty && $0.bodies.isEmpty && $0.sound != nil
        }) else { throw OriginalLoaderError.outsideVerifiedDomain("Original melee voice objects required") }
        fighters = try headers.indices.map { i in
            var state = FighterState()
            state.x = Double(450 + i * 35); state.ix = Int(state.x)
            state.facing = i; state.renderFacing = i
            return try OriginalFighter(header: headers[i], definitions: definitions[i], initial: initial?[i] ?? state)
        }
    }
    public var state: MeleeState {
        .init(actors: fighters.map(\.state), sounds: sounds, randomIndex: random.index,
              randomCounter: random.counter, cameraX: cameraX, cameraVelocity: cameraVelocity)
    }
    /// Roll back the complete tick on an unsupported technique/interaction.
    @discardableResult public mutating func tick(_ inputs: [FighterInput]) throws -> MeleeState {
        var next = self
        try next.advance(inputs)
        self = next
        return state
    }
    private mutating func advance(_ inputs: [FighterInput]) throws {
        guard inputs.count == 2 else { throw OriginalLoaderError.outsideVerifiedDomain("Two input slots required") }
        sounds = []
        for i in fighters.indices {
            try fighters[i].control(inputs[i], random: &random)
            fighters[i].physics()
            // 0x417f80 runs before collision; the X boundary is applied later.
            fighters[i].state.z = min(525, max(450, fighters[i].state.z))
            fighters[i].state.iz = Int(fighters[i].state.z)
            sounds += fighters[i].state.sounds
            fighters[i].state.sounds = []
        }
        try collide()
        for i in fighters.indices { fighters[i].bounds() }
        let player = fighters[0].state
        // 0x41b910: lying local players have no facing look-ahead. When no
        // local player is alive, 0x41ba8d averages living type-0 actors instead.
        let center: Int
        if player.hp > 0 {
            center = player.ix + (fighters[0].frameState == 14 ? 0 : 130 - player.facing * 260)
        } else {
            let living = fighters.map(\.state).filter { $0.hp > 0 }
            center = living.isEmpty ? 800 : living.reduce(0) { $0 + $1.ix } / living.count
        }
        let target = min(166, max(0, center - 397))
        cameraVelocity = ((target - cameraX) / 14 + cameraVelocity * 6) / 7
        if cameraVelocity == 0 && target != cameraX { cameraVelocity = target > cameraX ? 1 : -1 }
        cameraX = min(166, max(0, cameraX + cameraVelocity))
        for i in fighters.indices {
            fighters[i].state.renderFrame = fighters[i].state.frame
            fighters[i].state.renderFacing = fighters[i].state.facing
            fighters[i].state.renderX = fighters[i].state.ix
            fighters[i].state.renderY = fighters[i].state.iy
            fighters[i].state.renderZ = fighters[i].state.iz
            fighters[i].applyHitVelocity()
            try fighters[i].schedule()
            fighters[i].postSchedule()
            sounds += fighters[i].state.sounds
            fighters[i].state.sounds = []
        }
        // 0x41fc61..0x4202e6: these invisible one-frame sound objects are born
        // after their parent's scheduler. Slots >=50 schedule after both fighters.
        for fighter in fighters where fighter.state.wait == 0 && fighter.state.freeze == 0 {
            let frame = fighter.currentFrame
            if frame[0x58]! > 0 {
                guard frame[0x58] == 1, frame[0x70] == 203,
                      let voice = voices[Int(frame[0x64]!)], frame[0x74] == 0 else {
                    throw fighter.unsupported("spawned technique object")
                }
                sounds.append(voice.sound!)
            }
        }
    }

    private struct Rect {
        var x: Int, y: Int, w: Int, h: Int
        func overlaps(_ b: Self) -> Bool {
            // 0x4171c0: touching edges have no intersection.
            x < b.x + b.w && b.x < x + w && y < b.y + b.h && b.y < y + h
        }
    }
    private func rect(_ box: [Int32], actor: Int, frame: OriginalFrameRecord) -> Rect {
        let state = fighters[actor].state
        let x = Int(box[1]), w = Int(box[3]), center = Int(frame.field("centerx")!)
        return Rect(x: state.ix + (state.facing == 0 ? x - center : center - x - w),
                    y: state.iy + Int(box[2]) - Int(frame.field("centery")!), w: w, h: Int(box[4]))
    }
    private mutating func collide() throws {
        // 0x419380 snapshots frames for both directions before resolving any hit.
        let records = fighters.map(\.currentFrame)
        for i in fighters.indices {
            fighters[i].state.collisionFrame = fighters[i].state.frame
            if records[i].interactions.isEmpty { fighters[i].state.rest = 0 }
            if fighters[i].state.vrest[1-i] > 0 { fighters[i].state.vrest[1-i] -= 1 }
        }
        var contacts = [[Int]](repeating: [], count: 2)
        for i in fighters.indices {
            let j = 1-i, a = fighters[i].state, b = fighters[j].state
            guard a.rest <= 0, b.vrest[i] <= 0, b.invulnerability == 0 else { continue }
            var nearest = 1000
            for (index, itr) in records[i].interactions.enumerated() {
                let kind = Int(itr[0]), depth = itr[18] == 0 ? 15 : Int(itr[18])
                guard abs(a.iz - b.iz) < depth else { continue }
                guard !(records[j].field("state") == 12 && itr[7] <= 40) else { continue }
                // Type-0 characters cannot be picked up by kind 2.
                if kind == 2 { continue }
                for body in records[j].bodies where rect(itr, actor: i, frame: records[i]).overlaps(rect(body, actor: j, frame: records[j])) {
                    if itr[9] == 0 {
                        let distance = abs(a.ix - b.ix)
                        if distance > nearest { continue }
                        if distance == nearest && random.next(2) != 0 { continue }
                        nearest = distance; contacts[i] = [index]
                    } else if contacts[i].count < 20 { contacts[i].append(index) }
                }
            }
        }
        for i in fighters.indices {
            let j = 1-i
            for index in contacts[i] {
                if fighters[j].state.vrest[i] > 0 { continue }
                let itr = records[i].interactions[index]
                switch itr[0] {
                case 0:
                    guard [0,1].contains(itr[11]) else { throw fighters[i].unsupported("hit effect \(itr[11])") }
                    resolve(itr.map(Int.init), from: i, to: j, targetFrame: records[j])
                case 6: fighters[j].state.superPunch = 3 // 0x43056e
                case 4:
                    guard fighters[i].state.fallHurt == 0 else { throw fighters[i].unsupported("thrown-body damage") }
                default: throw fighters[i].unsupported("interaction kind \(itr[0])")
                }
            }
        }
    }
    private mutating func resolve(_ hit: [Int], from i: Int, to j: Int, targetFrame: OriginalFrameRecord) {
        var a = fighters[i].state, b = fighters[j].state
        let blocked = targetFrame.field("state") == 7 && hit[16] <= 60 && b.hp > 0
            && (a.facing != b.facing || hit[5] < 0)
        let damage = blocked ? hit[17] / 10 : hit[17]
        if b.hp > 0 && damage >= b.hp { a.kills += 1 }
        b.hp -= damage; b.redHP -= damage / 3
        b.damageReceived += damage; a.damageDealt += damage
        b.hitCount += 1
        let direction = Double(1 - a.facing * 2)
        if blocked {
            sounds.append("builtin:1")
            if b.hp <= 0 { b.fall = 80 }
            b.wait = 0; b.guardDamage += hit[16]
            a.freeze = 3; b.freeze = -5
            if b.iy == 0 {
                if b.guardDamage > 30 { b.frame = 112 }
                else if b.frame == 110 { b.frame = 111 }
                b.hitVX += direction * (b.fall == 80 && abs(b.vx) < 3 && hit[5] == 0 ? 3 : Double(hit[5] / 2))
            } else {
                b.hitVX += direction * (b.fall == 80 && abs(b.vx) < 6 && hit[5] < 6 ? 6 : Double(hit[5]))
            }
            a.rest = hit[8] < 4 && hit[9] == 0 ? 4 : min(hit[8],12)
            if hit[9] > 0 { b.vrest[i] = min(12,max(4,hit[9])) }
        } else {
            b.guardDamage = 45
            if b.hp <= 0 { b.fall = 80 }
            b.fall += hit[7] == 0 ? 20 : hit[7]
            if targetFrame.field("state") == 12 { b.fall = 80 }
            if b.fall > 60 { b.fall = 80 }
            else if b.fall > 40 { b.frame = 226; b.fall = b.iy < 0 ? 80 : 60 }
            else if b.fall > 20 { b.frame = 222 + (a.facing == b.facing ? 2 : 0); b.fall = b.iy < 0 ? 80 : 40 }
            else if b.fall > 0 {
                b.frame = b.iy < 0 ? 222 + (a.facing == b.facing ? 2 : 0) : 220; b.fall = 20
            }
            if hit[11] == 1 { sounds.append(b.fall == 80 ? "builtin:12" : "builtin:11") }
            sounds.append(b.fall == 80 ? "builtin:2" : "builtin:0")
            b.hitVX += direction * (b.fall == 80 && abs(b.vx) < 5 && hit[5] == 0 ? 5 : Double(hit[5]))
            if b.fall == 80 {
                b.hitVY += hit[6] == 0 ? -7 : Double(hit[6])
                if hit[6] != 0 && Int(Double(b.iy) + b.hitVY) > 0 { b.hitVY = 12 }
                b.frame = (b.facing == 0 && b.hitVX <= 0) || (b.facing == 1 && b.hitVX > 0) ? 180 : 186
                b.fall = 0
            }
            if a.freeze >= 0 { a.freeze = 3 }
            b.freeze = -3
            a.rest = hit[8] < 4 && hit[9] == 0 ? 4 : hit[8]
            if hit[9] > 0 { b.vrest[i] = hit[9] }
        }
        fighters[i].state = a; fighters[j].state = b
    }
}
