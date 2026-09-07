import Foundation

/// Replay bits, original 0x4198f0.
public struct FighterInput: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue & 0xfe }
    public static let up = Self(rawValue: 0x80), down = Self(rawValue: 0x40)
    public static let left = Self(rawValue: 0x20), right = Self(rawValue: 0x10)
    public static let attack = Self(rawValue: 8), jump = Self(rawValue: 4), defend = Self(rawValue: 2)
}

public struct FighterState: Codable, Equatable, Sendable {
    public var phase = 0, tap = 0, ix = 480, iy = 0, iz = 490
    public var frame = 0, previousFrame = 0, wait = 0
    public var vx = 0.0, vy = 0.0, vz = 0.0, x = 480.0, y = 0.0, z = 490.0
    public var facing = 0, jumpBuffer = 0, rightBuffer = 0, leftBuffer = 0, upBuffer = 0, downBuffer = 0
    public var sounds: [String] = []
    public var cameraX = 0, cameraVelocity = 0
    public var renderFrame = 0, renderFacing = 0
    public var renderX = 480, renderY = 0, renderZ = 490
    public var collisionFrame = 0, fall = 0, freeze = 0, guardDamage = 0, rest = 0
    public var hp = 500, redHP = 500, mp = 500, hitCount = 0, fallHurt = 0, invulnerability = 0
    public var damageDealt = 0, damageReceived = 0, kills = 0
    public var attackBuffer = 0, defendBuffer = 0, defendCooldown = 0, superPunch = 0
    public var hitVX = 0.0, hitVY = 0.0, hitVZ = 0.0
    public var vrest = [0, 0]
    public var combos = [Int](repeating: 0, count: 9)
    public init() {}
}

/// Two-fighter melee slice. Unsupported techniques stop the practice explicitly;
/// original DAT definitions are never rewritten to turn them into ordinary moves.
public struct OriginalFighter {
    public let frames: [Int: OriginalFrameRecord]
    public let parameters: Fields
    public internal(set) var state: FighterState
    private var previousInput: FighterInput = []
    private var currentInput: FighterInput = []
    var enablesChidoriNeedles = false
    public private(set) var mpSpent = 0

    public static func frameNumbers(name: String) -> Set<Int> {
        var result = OriginalMovement.frameNumbers.union(60...74).union(110...114)
            .union(180...191).union(220...231).union([85,95])
        if name == "Sasuke" { result.formUnion(240...242); result.formUnion(261...266); result.insert(246) }
        return result
    }
    public static func sections(in text: String, name: String, numbers: Set<Int>? = nil) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"<frame>\s+(-?\d+)\s+.*?<frame_end>"#, options: .dotMatchesLineSeparators)
        let ns = text as NSString, allowed = numbers ?? frameNumbers(name: name)
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard let n = Int(ns.substring(with: $0.range(at: 1))), allowed.contains(n) else { return nil }
            return ns.substring(with: $0.range)
        }
    }
    public init(header: Fields, definitions: [String], initial: FighterState) throws {
        guard ["Naruto", "Sasuke"].contains(header["name"]) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Only original Naruto and Sasuke in melee practice")
        }
        var loader = OriginalFrameLoader()
        for definition in definitions { try loader.apply(definition) }
        frames = loader.frames; parameters = header; state = initial
        state.renderX = state.ix; state.renderY = state.iy; state.renderZ = state.iz
        guard header.integer("walking_frame_rate") > 0, header.integer("running_frame_rate") > 0,
              OriginalMovement.frameNumbers.isSubset(of: Set(frames.keys)) else { throw unsupported("motion data") }
        guard frames[state.frame] != nil else { throw unsupported("initial frame") }
    }
    public var currentFrame: OriginalFrameRecord { frames[state.frame]! }
    var frameState: Int { Int(currentFrame.field("state")!) }
    private func p(_ key: String) -> Double { parameters.number(key) }
    func unsupported(_ detail: String) -> OriginalLoaderError {
        .outsideVerifiedDomain("\(parameters["name"] ?? "Fighter"): \(detail)")
    }
    private mutating func walkPhase() {
        let rate = parameters.integer("walking_frame_rate")
        state.phase = (state.phase + 1) % (rate * 6)
        state.frame = state.phase < rate * 4 ? state.phase / rate + 5 : 11 - state.phase / rate
    }
    private mutating func frameSound() {
        if let sound = currentFrame.sound { state.sounds.append(sound) }
    }
    mutating func control(_ input: FighterInput, random: inout OriginalRandom) throws {
        state.sounds.removeAll(keepingCapacity: true)
        currentInput = input
        let right = input.contains(.right), left = input.contains(.left)
        let up = input.contains(.up), down = input.contains(.down), jump = input.contains(.jump)
        let rightOnly = right && !left, leftOnly = left && !right
        let upOnly = up && !down, downOnly = down && !up
        // 0x413080–0x413208: positive buffers decay before rising-edge capture.
        for (key, button) in [(\FighterState.rightBuffer, FighterInput.right), (\.leftBuffer, .left),
                              (\.upBuffer, .up), (\.downBuffer, .down), (\.jumpBuffer, .jump),
                              (\.attackBuffer, .attack), (\.defendBuffer, .defend)] {
            if state[keyPath: key] > 0 { state[keyPath: key] -= 1 }
            if input.contains(button) && !previousInput.contains(button) { state[keyPath: key] = 5 }
        }
        if state.defendCooldown > 0 { state.defendCooldown -= 1 }
        try sampleCombos()
        // 0x41324c..0x4132ef: priority is strictly greater than BOTH other buffers.
        // Techniques/escapes are an explicit boundary, never rewritten as a punch.
        for (field, value, other1, other2) in [
            ("hit_a", state.attackBuffer, state.defendBuffer, state.jumpBuffer),
            ("hit_d", state.defendBuffer, state.attackBuffer, state.jumpBuffer),
            ("hit_j", state.jumpBuffer, state.attackBuffer, state.defendBuffer)
        ] where currentFrame.field(field) != 0 && value > other1 && value > other2 {
            throw unsupported("technique \(currentFrame.field(field)!)")
        }
        if state.frame == 110 {
            if right { state.facing = 0 }
            if left { state.facing = 1 }
        }
        // 0x4133b1–0x413766. These blocks are sequential, not mutually exclusive:
        // a second tap can enter running and execute its block in the same tick.
        if frameState == 0 || frameState == 1 {
            if state.tap > 0 { state.tap -= 1 }
            if state.tap < 0 { state.tap += 1 }
            if rightOnly && state.iy == 0 {
                if state.facing == 1 { state.tap = 0 }
                state.facing = 0; walkPhase(); state.vx = p("walking_speed")
                if !previousInput.contains(.right) { state.tap += 10 }
                if state.tap >= 11 { state.frame = 9; state.phase = 0; state.tap = 0 }
            }
            if leftOnly && state.iy == 0 {
                if state.facing == 0 { state.tap = 0 }
                state.facing = 1; walkPhase(); state.vx = -p("walking_speed")
                if !previousInput.contains(.left) { state.tap -= 10 }
                if state.tap <= -11 { state.frame = 9; state.phase = 0; state.tap = 0 }
            }
            if (upOnly || downOnly) && state.iy == 0 {
                if right == left { walkPhase() }
                state.vz = p("walking_speedz") * (upOnly ? -1 : 1)
                state.vx /= 1.4
            }
            if input.contains(.attack) && state.attackBuffer > 0 {
                state.tap = 0; state.wait = 0
                state.frame = state.superPunch > 0 ? 70 : 60 + 5 * random.next(2)
            }
            if jump && state.jumpBuffer > 0 { state.tap = 0; state.wait = 0; state.frame = 210 }
            if input.contains(.defend) && state.defendCooldown == 0 && state.defendBuffer > 0 {
                state.tap = 0; state.wait = 0; state.frame = 110
            }
        }
        if frameState == 4 && state.iy < 0 {
            if rightOnly { state.facing = 0 }
            if leftOnly { state.facing = 1 }
            if input.contains(.attack) { throw unsupported("jump attack") }
        }
        // 0x413b13–0x413d74: running persists after the direction key is released.
        if frameState == 2 {
            state.wait = 0
            let rate = parameters.integer("running_frame_rate")
            state.phase = (state.phase + 1) % (rate * 4)
            state.frame = state.phase < rate * 3 ? state.phase / rate + 9 : 10
            state.vx = p("running_speed") * (state.facing == 0 ? 1 : -1)
            if (state.facing == 0 && left) || (state.facing == 1 && right) { state.frame = 218 }
            if (upOnly || downOnly) && state.iy == 0 {
                state.vz = p("running_speedz") * (upOnly ? -1 : 1); state.vx /= 1.2
            }
            if input.contains(.attack) && state.attackBuffer > 0 { state.frame = 85 }
            if input.contains(.defend) && state.defendBuffer > 0 { throw unsupported("running defense") }
            if jump && state.jumpBuffer > 0 {
                state.sounds.append("builtin:7"); state.tap = 0; state.frame = 213
                state.vx = p("dash_distance") * (state.facing == 0 ? 1 : -1)
                state.vy = p("dash_height")
                if upOnly || downOnly { state.vz = p("dash_distancez") * (upOnly ? -1 : 1) }
            }
        }
        // 0x413e75–0x413f8d: buffered jump during crouch can immediately dash.
        if state.frame == 215 {
            if jump && (right || state.vx >= 0.001) && state.jumpBuffer > 0 {
                state.sounds.append("builtin:7"); state.frame = 213 + state.facing; state.tap = 0
                state.vx = p("dash_distance"); state.vy = p("dash_height")
            }
            if jump && (left || state.vx < -0.001) && state.jumpBuffer > 0 {
                state.sounds.append("builtin:7"); state.frame = 214 - state.facing; state.tap = 0
                state.vx = -p("dash_distance"); state.vy = p("dash_height")
            }
            if upOnly || downOnly { state.vz = p("dash_distancez") * (upOnly ? -1 : 1) }
        }
        // 0x414080–0x414184: turn in flight without reversing dash momentum.
        if [182,188].contains(state.frame) && state.fallHurt >= 0 && jump && state.jumpBuffer > 0 && state.hp > 0 {
            throw unsupported("fall recovery roll") // 0x413f8d
        }
        if frameState == 5 {
            if rightOnly { state.facing = 0 }
            if state.facing == 0 {
                if state.frame != 217 && state.vx < 0 { state.frame = 214 }
                if state.frame != 216 && state.vx > 0 { state.frame = 213 }
            }
            if leftOnly { state.facing = 1 }
            if state.facing == 1 {
                if state.frame != 217 && state.vx > 0 { state.frame = 214 }
                if state.frame != 216 && state.vx < 0 { state.frame = 213 }
            }
            if input.contains(.attack) && ((state.facing == 0 && state.vx >= 0) || (state.facing == 1 && state.vx < 0)) {
                throw unsupported("dash attack")
            }
        }
        let direction = state.facing == 0 ? 1.0 : -1.0
        let dvx = Double(currentFrame.field("dvx")!)
        if dvx > 500 { state.vx = dvx - 550 }
        else if dvx > 0 { state.vx = max(state.vx * direction, dvx) * direction }
        else if dvx < 0 { state.vx = min(state.vx * direction, dvx) * direction }
        let dvy = Double(currentFrame.field("dvy")!)
        if dvy != 0 { state.vy = dvy > 500 ? dvy - 550 : state.vy + dvy }
        let dvz = Double(currentFrame.field("dvz")!)
        if dvz > 500 { state.vz = dvz - 550 }
        else if dvz != 0 {
            if up && state.upBuffer >= state.downBuffer { state.vz = -dvz }
            if down && state.upBuffer <= state.downBuffer { state.vz = dvz }
        }
        previousInput = input
    }

    /// 0x412800..0x413077 and invalidation helper 0x40e170. Recognition is
    /// recovered; only Sasuke hit_Fa=261 may transfer into a technique here.
    private mutating func sampleCombos() throws {
        let routes = [(1,6,"hit_Fa"),(2,6,"hit_Fa"),(3,6,"hit_Ua"),(4,6,"hit_Da"),
                      (1,5,"hit_Fj"),(2,5,"hit_Fj"),(3,5,"hit_Uj"),(4,5,"hit_Dj"),(5,6,"hit_ja")]
        for (i, route) in routes.enumerated() {
            let buffers = [state.defendBuffer, state.rightBuffer, state.leftBuffer,
                           state.upBuffer, state.downBuffer, state.jumpBuffer, state.attackBuffer]
            var changed = false
            if state.combos[i] == 0 && buffers[0] == 5 { state.combos[i] = 1; changed = true }
            for stage in 1...3 where state.combos[i] == stage {
                let previous = stage == 1 ? 0 : stage == 2 ? route.0 : route.1
                if stage < 3 && buffers[stage == 1 ? route.0 : route.1] == 5 {
                    state.combos[i] += 1; changed = true
                } else if stage == 3 && currentFrame.field(route.2) != 0 {
                    let target = Int(currentFrame.field(route.2)!)
                    guard enablesChidoriNeedles, parameters["name"] == "Sasuke", target == 261, i < 2,
                          let next = frames[target] else { throw unsupported("technique \(target)") }
                    // 0x40e2d0: mp packs health cost in thousands and chakra in
                    // the remainder. Insufficient resources leave the frame alone.
                    let cost = Int(next.field("mp")!), hpCost = (cost / 1000) * 10, mpCost = cost % 1000
                    if state.mp >= mpCost && state.hp > hpCost {
                        state.hp -= hpCost; state.damageReceived += hpCost
                        state.mp -= mpCost; mpSpent += mpCost; state.frame = target
                        state.attackBuffer = 0; state.jumpBuffer = 0; state.defendBuffer = 0
                        state.rightBuffer = 0; state.leftBuffer = 0; state.upBuffer = 0; state.downBuffer = 0
                    }
                    // 0x4128be / 0x4129ae apply even when affordability failed.
                    state.facing = i; state.combos[i] = 0
                } else if buffers.indices.contains(where: { (!changed || $0 != previous) && buffers[$0] == 5 }) {
                    state.combos[i] = 0
                }
            }
        }
    }

    // 0x40e490: a tick reducing hitstop to zero still does not integrate position.
    mutating func physics() {
        if state.freeze != 0 { state.freeze += state.freeze > 0 ? -1 : 1; return }
        state.x += state.vx; state.z += state.vz
        if state.iy >= 0 { state.vx = Self.friction(state.vx); state.vz = Self.friction(state.vz) }
        state.y += state.vy
        if state.y < -0.0001 {
            state.vy += 1.7
            if frameState == 12 {
                // The x87 stack retains FLD1 here, not FLDZ (0x40e6de..0x40e6eb).
                let phase = state.vy < -8 ? 0 : state.vy < 1 ? 1 : state.vy < 8 ? 2 : 3
                if state.frame < 185 { state.frame = 180 + phase }
                else if (186..<191).contains(state.frame) { state.frame = 186 + phase }
            }
        } else if frameState == 12 && state.y > 0 && state.vy > 0 {
            // 0x40eb18..0x40ec4e: land, bounce, or lie down.
            state.sounds.append("builtin:6")
            if state.fallHurt != 0 {
                state.hp -= abs(state.fallHurt); state.redHP -= abs(state.fallHurt); state.fallHurt = 0
            }
            state.y = 0
            if state.vy <= 11 && state.vx <= 9 && state.vx >= -9 {
                state.vy = 0; state.vx /= 3; state.wait = 0
                state.frame = state.frame >= 186 ? 231 : 230
            } else {
                state.vy = -3.5; state.vx = min(7, max(-7, state.vx))
                state.frame = state.frame >= 186 ? 191 : 185
            }
        } else if (state.y > 0 && state.vy > 0) || (state.frame == 212 && state.vy == 0) {
            state.y = 0; state.vy = 0; state.vx /= 3
            state.frame = state.frame == 212 || frameState == 6 ? 215 : 219; state.wait = 0
        }
        state.ix = Int(state.x); state.iy = Int(state.y); state.iz = Int(state.z)
    }
    mutating func bounds() {
        state.z = min(525, max(450, state.z)); state.iz = Int(state.z)
        state.x = min(960, max(0, state.x)); state.ix = Int(state.x)
    }
    mutating func applyHitVelocity() {
        guard state.freeze == 0 else { return }
        if state.hitCount != 0 {
            let divisor = Double(state.hitCount + 1)
            state.vx = state.hitVX * 2 / divisor; state.vy = state.hitVY * 2 / divisor
            state.vz = state.hitVZ * 2 / divisor; state.hitCount = 0
        }
        state.hitVX = 0; state.hitVY = 0; state.hitVZ = 0
    }
    mutating func schedule() throws {
        guard state.freeze == 0 else { return }
        if state.rest > 0 { state.rest -= 1 }
        if state.invulnerability > 0 { state.invulnerability -= 1 }
        if state.invulnerability < 0 { state.invulnerability += 1 }
        if state.fall > 0 { state.fall -= 1 }
        if state.guardDamage > 0 { state.guardDamage -= 1 }
        if state.superPunch > 0 { state.superPunch -= 1 }
        if state.frame != state.previousFrame { frameSound(); state.wait = 0 }
        state.wait += 1
        if frameState == 0 && state.iy < 0 { state.frame = 212 }
        if frameState == 14 && state.hp <= 0 { state.wait = 0 }
        if state.wait > Int(currentFrame.field("wait")!) {
            state.wait = 0
            var next = Int(currentFrame.field("next")!)
            if next != 0 {
                if next < 0 { state.facing = 1 - state.facing; next = -next }
                let airReturn = next == 999 && state.iy != 0
                next = next == 999 ? (airReturn ? 212 : 0) : next
                guard frames[next] != nil else { throw unsupported("frame \(next)") }
                state.frame = next
                if frames[state.previousFrame]?.field("state") == 14 && frameState != 13 { state.invulnerability = 15 }
                if state.frame == 212 && !airReturn {
                    state.vy = p("jump_height")
                    if currentInput.contains(.right) && !currentInput.contains(.left) { state.vx = p("jump_distance") }
                    if currentInput.contains(.left) && !currentInput.contains(.right) { state.vx = -p("jump_distance") }
                    if currentInput.contains(.up) && !currentInput.contains(.down) { state.vz = -p("jump_distancez") }
                    if currentInput.contains(.down) && !currentInput.contains(.up) { state.vz = p("jump_distancez") }
                }
                frameSound()
            }
        }
        if state.frame == 110 || state.frame == 114 { state.defendCooldown = 3 }
        state.previousFrame = state.frame
    }
    mutating func postSchedule() {
        // 0x41fb4e..0x41fc61. Includes death after lethal block damage and
        // recovery from a falling frame with no airborne/pending velocity.
        let deadStanding = state.hp <= 0 && (state.frame < 12 || state.frame == 110 || state.frame == 111)
        let stuckFalling = state.iy == 0 && state.y == 0 && state.vy == 0 && state.hitVY == 0
            && (((180...189).contains(state.frame) && state.frame != 184) || (212...214).contains(state.frame))
        if deadStanding || stuckFalling {
            state.frame = 186; state.vy = -3; state.hitVY = -3; state.y = -1; state.iy = -1
        }
    }
    static func friction(_ value: Double) -> Double {
        var result = value
        if result > 0.0001 { result -= 1; if result <= 0.0001 { result = 0 } }
        if result < -0.0001 { result += 1; if result > -0.0001 { result = 0 } }
        return result
    }
}
