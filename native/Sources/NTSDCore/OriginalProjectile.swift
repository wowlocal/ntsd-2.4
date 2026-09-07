import Foundation

public struct ProjectileDefinition: Codable, Sendable {
    public var id: Int
    public var definitions: [String]
    public init(id: Int, definitions: [String]) { self.id = id; self.definitions = definitions }
    public static func frameNumbers(id: Int) -> Set<Int> {
        switch id {
        case 224: return Set(0...7)
        case 440: return Set(1...13)
        default: return []
        }
    }
}
public struct ProjectileState: Codable, Equatable, Sendable {
    public var slot: Int, id: Int, owner: Int, team: Int
    public var motion: FighterState
}
public struct ProjectilePose: Codable, Equatable, Sendable {
    public var slot: Int, id: Int, frame: Int, facing: Int, x: Int, y: Int, z: Int
}

/// Recovered type-3 motion and lifetime. No SpriteKit physics, homing or guessed
/// lifetime; only the declared original snake/needle/voice frames are accepted.
struct OriginalProjectile {
    var state: ProjectileState
    let frames: [Int: OriginalFrameRecord]
    var currentFrame: OriginalFrameRecord { frames[state.motion.frame]! }
    mutating func control() {
        let frame = currentFrame, direction = state.motion.facing == 0 ? 1.0 : -1.0
        let x = Double(frame.field("dvx")!)
        if x > 500 { state.motion.vx = x - 550 }
        else if x > 0 { state.motion.vx = max(state.motion.vx * direction, x) * direction }
        else if x < 0 { state.motion.vx = min(state.motion.vx * direction, x) * direction }
        let y = Double(frame.field("dvy")!)
        if y != 0 { state.motion.vy = y > 500 ? y - 550 : state.motion.vy + y }
        let z = Double(frame.field("dvz")!)
        if z > 500 { state.motion.vz = z - 550 }
    }
    mutating func physics() {
        if state.motion.freeze != 0 { state.motion.freeze += state.motion.freeze > 0 ? -1 : 1; return }
        state.motion.x += state.motion.vx; state.motion.z += state.motion.vz
        let hitJ = Int(currentFrame.field("hit_j")!)
        if hitJ > 0 { state.motion.z += Double(hitJ - 50) } // 0x40e5aa
        if state.motion.iy >= 0 {
            state.motion.vx = OriginalFighter.friction(state.motion.vx)
            state.motion.vz = OriginalFighter.friction(state.motion.vz)
        }
        state.motion.y += state.motion.vy // type 3 skips gravity and ground landing
        state.motion.ix = Int(state.motion.x); state.motion.iy = Int(state.motion.y); state.motion.iz = Int(state.motion.z)
    }
    mutating func bounds() -> Bool {
        state.motion.z = min(526, max(449, state.motion.z)); state.motion.iz = Int(state.motion.z)
        // 0x41b6ce: type-3 objects leave the world beyond arena ±300.
        return state.motion.x >= -300 && state.motion.x <= 1260
    }
    mutating func applyHitVelocity() {
        guard state.motion.freeze == 0 else { return }
        if state.motion.hitCount != 0 {
            let divisor = Double(state.motion.hitCount + 1)
            state.motion.vx = state.motion.hitVX * 2 / divisor
            state.motion.vy = state.motion.hitVY * 2 / divisor
            state.motion.vz = state.motion.hitVZ * 2 / divisor
            state.motion.hitCount = 0
        }
        state.motion.hitVX = 0; state.motion.hitVY = 0; state.motion.hitVZ = 0
    }
    /// Type 3 schedules while frozen (0x40d973); deletion uses next >=400.
    mutating func schedule(sounds: inout [String]) throws -> Bool {
        if state.motion.rest > 0 { state.motion.rest -= 1 }
        if state.motion.invulnerability > 0 { state.motion.invulnerability -= 1 }
        if state.motion.invulnerability < 0 { state.motion.invulnerability += 1 }
        if state.motion.fall > 0 { state.motion.fall -= 1 }
        if state.motion.guardDamage > 0 { state.motion.guardDamage -= 1 }
        if state.motion.superPunch > 0 { state.motion.superPunch -= 1 }
        if state.motion.frame != state.motion.previousFrame {
            if let sound = currentFrame.sound { sounds.append(sound) }
            state.motion.wait = 0
        }
        state.motion.wait += 1
        if state.motion.wait > Int(currentFrame.field("wait")!) {
            state.motion.wait = 0
            var next = Int(currentFrame.field("next")!)
            if next != 0 {
                if next < 0 { state.motion.facing = 1 - state.motion.facing; next = -next }
                if next == 999 { next = 0 }
                state.motion.frame = next
                if next >= 400 { return false }
                guard frames[next] != nil else { throw OriginalLoaderError.outsideVerifiedDomain("Projectile \(state.id), frame \(next)") }
                if let sound = currentFrame.sound { sounds.append(sound) }
            }
        }
        state.motion.previousFrame = state.motion.frame
        return true
    }
}
