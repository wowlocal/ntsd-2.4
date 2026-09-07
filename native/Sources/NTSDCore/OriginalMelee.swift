import Foundation

public struct MeleeState: Codable, Equatable, Sendable {
    public var actors: [FighterState]
    public var sounds: [String]
    public var randomIndex: Int, randomCounter: Int
    public var cameraX: Int, cameraVelocity: Int
    public var projectiles: [ProjectileState]? = nil
    public var projectileDraws: [ProjectilePose]? = nil
    public var mpSpent: [Int]? = nil
}

/// Original two-fighter collision/hit pipeline and bounded spawned objects.
/// See COMBAT.md and PROJECTILES.md for the measured domain.
public struct OriginalMelee {
    public private(set) var fighters: [OriginalFighter]
    public private(set) var random: OriginalRandom
    private var cameraX = 0, cameraVelocity = 0
    public private(set) var localPlayer = 0
    public mutating func selectPlayer(_ index: Int) {
        precondition(fighters.indices.contains(index))
        localPlayer = index
    }
    private var sounds: [String] = []
    private let voices: [Int: OriginalFrameRecord]
    private let projectileCatalog: [Int: [Int: OriginalFrameRecord]]?
    private var objects: [Int: OriginalProjectile] = [:]
    private var draws: [ProjectilePose] = []
    private var currentInputs: [FighterInput] = [[], []]

    public init(headers: [Fields], definitions: [[String]], voiceDefinitions: [String], random: OriginalRandom,
                initial: [FighterState]? = nil, projectileDefinitions: [ProjectileDefinition]? = nil) throws {
        try random.validate()
        guard headers.count == 2, definitions.count == 2, initial == nil || initial?.count == 2 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Melee practice requires two fighters")
        }
        self.random = random
        var loader = OriginalFrameLoader()
        for definition in voiceDefinitions { try loader.apply(definition) }
        voices = loader.frames
        guard Set(voices.keys) == (projectileDefinitions == nil ? [200,201,207,208] : [200,201,207,208,334]), voices.values.allSatisfy({
            $0.field("pic") == 999 && $0.field("wait") == 0 && $0.field("next") == 1000
            && $0.interactions.isEmpty && $0.bodies.isEmpty && $0.sound != nil
        }) else { throw OriginalLoaderError.outsideVerifiedDomain("Original melee voice objects required") }
        if let definitions = projectileDefinitions {
            var catalog: [Int: [Int: OriginalFrameRecord]] = [203: voices]
            for definition in definitions {
                let allowed = ProjectileDefinition.frameNumbers(id: definition.id)
                guard !allowed.isEmpty, catalog[definition.id] == nil else {
                    throw OriginalLoaderError.outsideVerifiedDomain("Unknown/duplicate projectile definition")
                }
                var loader = OriginalFrameLoader()
                for source in definition.definitions { try loader.apply(source) }
                guard Set(loader.frames.keys) == allowed, loader.frames.values.allSatisfy({
                    $0.bodies.isEmpty && [3000,3002,3006].contains($0.field("state")!)
                    && $0.field("hit_a") == 0 && $0.field("hit_d") == 0 && $0.field("mp") == 0 && $0[0x58] == 0
                }) else { throw OriginalLoaderError.outsideVerifiedDomain("Projectile outside recovered snake/needle domain") }
                catalog[definition.id] = loader.frames
            }
            projectileCatalog = catalog
        } else { projectileCatalog = nil }
        fighters = try headers.indices.map { i in
            var state = FighterState()
            state.x = Double(450 + i * 35); state.ix = Int(state.x)
            state.facing = i; state.renderFacing = i
            state = initial?[i] ?? state
            if projectileDefinitions != nil { state.vrest += Array(repeating: 0, count: 400 - state.vrest.count) }
            var fighter = try OriginalFighter(header: headers[i], definitions: definitions[i], initial: state)
            fighter.enablesChidoriNeedles = projectileDefinitions != nil
            return fighter
        }
    }
    public var state: MeleeState {
        .init(actors: fighters.map(\.state), sounds: sounds, randomIndex: random.index,
              randomCounter: random.counter, cameraX: cameraX, cameraVelocity: cameraVelocity,
              projectiles: projectileCatalog == nil ? nil : objects.keys.sorted().map { objects[$0]!.state },
              projectileDraws: projectileCatalog == nil ? nil : draws,
              mpSpent: projectileCatalog == nil ? nil : fighters.map(\.mpSpent))
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
        sounds = []; currentInputs = inputs
        for i in fighters.indices { try fighters[i].control(inputs[i], random: &random) }
        for i in objects.keys.sorted() { objects[i]!.control() }
        for i in fighters.indices {
            fighters[i].physics()
            // 0x417f80 runs before collision; the X boundary is applied later.
            fighters[i].state.z = min(525, max(450, fighters[i].state.z))
            fighters[i].state.iz = Int(fighters[i].state.z)
            sounds += fighters[i].state.sounds
            fighters[i].state.sounds = []
        }
        for i in objects.keys.sorted() { objects[i]!.physics() }
        try collide()
        for i in fighters.indices { fighters[i].bounds() }
        for i in objects.keys.sorted() where !objects[i]!.bounds() { objects.removeValue(forKey: i) }
        let player = fighters[localPlayer].state
        // 0x41b910: lying local players have no facing look-ahead. When no
        // local player is alive, 0x41ba8d averages living type-0 actors instead.
        let center: Int
        if player.hp > 0 {
            center = player.ix + (fighters[localPlayer].frameState == 14 ? 0 : 130 - player.facing * 260)
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
        }
        draws = objects.keys.sorted().map { i in
            let object = objects[i]!.state, m = object.motion
            return .init(slot: i, id: object.id, frame: m.frame, facing: m.facing, x: m.ix, y: m.iy, z: m.iz)
        }
        for i in objects.keys.sorted() { objects[i]!.applyHitVelocity() }
        if projectileCatalog != nil {
            // Walk original slots dynamically: newly born objects in later slots
            // schedule this tick; they were absent from the earlier draw pass.
            for i in 0..<400 {
                if i < 2 {
                    try fighters[i].schedule(); fighters[i].postSchedule()
                    sounds += fighters[i].state.sounds; fighters[i].state.sounds = []
                } else if objects[i] != nil {
                    if try !objects[i]!.schedule(sounds: &sounds) { objects.removeValue(forKey: i); continue }
                } else { continue }
                try spawn(from: i)
            }
        } else {
            for i in fighters.indices {
                try fighters[i].schedule(); fighters[i].postSchedule()
                sounds += fighters[i].state.sounds; fighters[i].state.sounds = []
            }
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
    }

    private var slots: [Int] { [0,1] + objects.keys.sorted() }
    private func motion(_ i: Int) -> FighterState { i < 2 ? fighters[i].state : objects[i]!.state.motion }
    private mutating func putMotion(_ i: Int, _ value: FighterState) {
        if i < 2 { fighters[i].state = value } else { objects[i]!.state.motion = value }
    }
    private func record(_ i: Int) -> OriginalFrameRecord { i < 2 ? fighters[i].currentFrame : objects[i]!.currentFrame }
    private func owner(_ i: Int) -> Int { i < 2 ? i : objects[i]!.state.owner }
    private func team(_ i: Int) -> Int { i < 2 ? i + 1 : objects[i]!.state.team }
    public func projectileFrame(id: Int, frame: Int) -> OriginalFrameRecord? { projectileCatalog?[id]?[frame] }
    private mutating func spawn(from i: Int) throws {
        let parent = motion(i), frame = record(i)
        guard frame[0x58]! > 0, parent.wait == 0, (parent.freeze == 0 || i >= 50) else { return }
        let id = Int(frame[0x70]!), action = Int(frame[0x64]!), facing = Int(frame[0x74]!)
        guard frame[0x58] == 1, let frames = projectileCatalog?[id], let childFrame = frames[action],
              [0,1,50].contains(facing) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Spawned object \(id), action \(action), facing \(facing)")
        }
        let count = facing > 10 ? facing / 10 : 1, orientation = facing > 10 ? facing % 10 : facing
        var born: [Int] = []
        for n in 0..<count {
            guard let slot = (50..<400).first(where: { objects[$0] == nil }) else { continue }
            var m = FighterState()
            m.vrest = Array(repeating: 0, count: 400)
            m.frame = action
            m.ix = parent.ix + (parent.facing == 0 ? Int(frame[0x5c]!) - Int(frame.field("centerx")!) : Int(frame.field("centerx")!) - Int(frame[0x5c]!))
            m.iy = parent.iy - Int(frame.field("centery")!) + Int(frame[0x60]!)
            m.x = Double(m.ix); m.y = Double(m.iy); m.z = parent.z + 1; m.iz = Int(m.z)
            m.facing = orientation == 0 ? parent.facing : 1 - parent.facing
            m.vx = Double(frame[0x68]!) * Double(1 - m.facing * 2); m.vy = Double(frame[0x6c]!); m.vz = 0
            m.hitVX = 0.1; m.hitVY = 0.1; m.hitVZ = 0.1
            if [3000,1002,3006].contains(childFrame.field("state")!), id != 223 && id != 224 {
                if currentInputs[i < 2 ? i : owner(i)].contains(.up) && !currentInputs[i < 2 ? i : owner(i)].contains(.down) { m.vz = -2.5 }
                if currentInputs[i < 2 ? i : owner(i)].contains(.down) && !currentInputs[i < 2 ? i : owner(i)].contains(.up) { m.vz = 2.5 }
            }
            if count > 1 {
                let spread = Double(n) * 10 / Double(count - 1) - 5
                m.vz += spread
                if (m.vx < 0 && spread > 0) || (m.vx > 0 && spread < 0) { m.vx -= spread }
                else { m.vx += spread }
            }
            for other in slots {
                var state = motion(other); state.vrest[slot] = 0; putMotion(other, state)
            }
            objects[slot] = OriginalProjectile(state: .init(slot: slot, id: id, owner: owner(i), team: team(i), motion: m), frames: frames)
            born.append(slot)
        }
        if born.count > 1 {
            for (n, slot) in born.enumerated() {
                let middle = born.count / 2
                objects[slot]!.state.motion.rest = n < middle ? (middle - n - (born.count % 2 == 0 ? 1 : 0)) * 2 : (n - middle) * 2
                for other in born where other != slot { objects[slot]!.state.motion.vrest[other] = 40 }
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
        let state = motion(actor)
        let x = Int(box[1]), w = Int(box[3]), center = Int(frame.field("centerx")!)
        return Rect(x: state.ix + (state.facing == 0 ? x - center : center - x - w),
                    y: state.iy + Int(box[2]) - Int(frame.field("centery")!), w: w, h: Int(box[4]))
    }
    private mutating func collide() throws {
        let active = slots, records = Dictionary(uniqueKeysWithValues: slots.map { ($0, record($0)) })
        var contacts = [Int: [(target: Int, interaction: Int)]](), nearest = [Int: Int]()
        for i in active {
            var state = motion(i); state.collisionFrame = state.frame
            if records[i]!.interactions.isEmpty { state.rest = 0 }
            putMotion(i, state); contacts[i] = []; nearest[i] = 1000
        }
        // 0x419630: ascending unordered pairs, checking both directions.
        for (offset, first) in active.enumerated() {
            for second in active.dropFirst(offset + 1) {
                for (i,j) in [(first,second),(second,first)] {
                    var state = motion(i)
                    if state.vrest[j] > 0 { state.vrest[j] -= 1 }
                    putMotion(i, state)
                }
                for (i,j) in [(first,second),(second,first)] {
                    let a = motion(i), b = motion(j), attack = records[i]!, target = records[j]!
                    guard a.rest <= 0, b.vrest[i] <= 0, b.invulnerability == 0, !target.bodies.isEmpty else { continue }
                    for (index, itr) in attack.interactions.enumerated() {
                        let kind = Int(itr[0]), depth = itr[18] == 0 ? 15 : Int(itr[18])
                        guard abs(a.iz - b.iz) < depth, !(target.field("state") == 12 && itr[7] <= 40) else { continue }
                        if kind == 2 { continue }
                        if team(i) == team(j) { continue }
                        for body in target.bodies where rect(itr, actor: i, frame: attack).overlaps(rect(body, actor: j, frame: target)) {
                            if itr[9] == 0 {
                                let distance = abs(a.ix - b.ix)
                                if distance > nearest[i]! { continue }
                                if distance == nearest[i]! && random.next(2) != 0 { continue }
                                nearest[i] = distance; contacts[i] = [(j,index)]
                            } else if contacts[i]!.count < 20 { contacts[i]!.append((j,index)) }
                        }
                    }
                }
            }
        }
        for i in active {
            for contact in contacts[i]! {
                let j = contact.target
                if motion(j).vrest[i] > 0 { continue }
                let itr = records[i]!.interactions[contact.interaction]
                switch itr[0] {
                case 0:
                    guard [0,1].contains(itr[11]), j < 2 else { throw OriginalLoaderError.outsideVerifiedDomain("Projectile target/effect") }
                    resolve(itr.map(Int.init), from: i, to: j, targetFrame: records[j]!)
                case 6:
                    var target = motion(j); target.superPunch = 3; putMotion(j, target)
                case 4:
                    guard motion(i).fallHurt == 0 else { throw OriginalLoaderError.outsideVerifiedDomain("Thrown-body damage") }
                default: throw OriginalLoaderError.outsideVerifiedDomain("Interaction kind \(itr[0])")
                }
            }
        }
    }
    private mutating func resolve(_ hit: [Int], from i: Int, to j: Int, targetFrame: OriginalFrameRecord) {
        var a = motion(i), b = motion(j)
        let blocked = targetFrame.field("state") == 7 && hit[16] <= 60 && b.hp > 0
            && (a.facing != b.facing || hit[5] < 0)
        let damage = blocked ? hit[17] / 10 : hit[17]
        let killed = b.hp > 0 && damage >= b.hp
        if i < 2 && killed { a.kills += 1 }
        b.hp -= damage; b.redHP -= damage / 3
        b.damageReceived += damage; if i < 2 { a.damageDealt += damage }
        b.hitCount += 1
        let direction = Double(1 - a.facing * 2)
        if blocked {
            // 0x42fe19: type-3 guard sound comes from its header (-1 here).
            if i < 2 { sounds.append("builtin:1") }
            // 0x430520: a blocked state-3000 shot enters frame 10, retaining vz.
            if i >= 50 && record(i).field("state") == 3000 { a.frame = 10; a.wait = 0; a.vx = 0 }
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
            if i >= 50 && record(i).field("state") == 3000 {
                a.frame = 10; a.wait = 0; a.vx = 0
                a.vz = Double(objects[i]!.frames[10]!.field("dvy")!)
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
        putMotion(i, a); putMotion(j, b)
        if i >= 50 {
            fighters[owner(i)].state.damageDealt += damage
            if killed { fighters[owner(i)].state.kills += 1 }
        }
    }
}
