import Foundation

/// Bit layout of the original replay input reader at 0x4198f0.
/// Combat/defend inputs are deliberately absent from this movement milestone.
public struct MovementInput: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue & 0xf4 }
    public static let up = Self(rawValue: 0x80), down = Self(rawValue: 0x40)
    public static let left = Self(rawValue: 0x20), right = Self(rawValue: 0x10)
    public static let jump = Self(rawValue: 0x04)
}

public struct MovementState: Codable, Equatable, Sendable {
    public var phase = 0, tap = 0, ix = 480, iy = 0, iz = 490
    public var frame = 0, previousFrame = 0, wait = 0
    public var vx = 0.0, vy = 0.0, vz = 0.0, x = 480.0, y = 0.0, z = 490.0
    public var facing = 0, jumpBuffer = 0, rightBuffer = 0, leftBuffer = 0, upBuffer = 0, downBuffer = 0
    public var sounds: [String] = []
    public var cameraX = 0, cameraVelocity = 0
    public var renderFrame = 0, renderFacing = 0
    public init() {}
}

/// Single unarmed Naruto only. Recovered from the identified NTSD Windows EXE;
/// no SpriteKit physics. Reference addresses, domain and oracle: docs/MOVEMENT.md.
public struct OriginalMovement {
    public static let frameNumbers = Set(0...3).union(5...11).union(210...219)
    public let frames: [Int: OriginalFrameRecord]
    private let parameters: Fields
    public private(set) var state: MovementState
    private var previousInput: MovementInput = []
    public let width: Double, zMin: Double, zMax: Double

    public static func sections(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"<frame>\s+(-?\d+)\s+.*?<frame_end>"#, options: .dotMatchesLineSeparators)
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard let n = Int(ns.substring(with: $0.range(at: 1))), frameNumbers.contains(n) else { return nil }
            return ns.substring(with: $0.range)
        }
    }

    public init(header: Fields, definitions: [String], initial: MovementState = .init(),
                width: Double = 960, zMin: Double = 450, zMax: Double = 525) throws {
        var loader = OriginalFrameLoader()
        for definition in definitions { try loader.apply(definition) }
        guard Set(loader.frames.keys) == Self.frameNumbers,
              header["name"] == "Naruto", width.isFinite, width >= 794,
              zMin.isFinite, zMax.isFinite, zMin <= zMax else {
            throw OriginalLoaderError.outsideVerifiedDomain("Movement currently supports the original Naruto movement frames only")
        }
        for key in ["walking_frame_rate", "running_frame_rate", "walking_speed", "walking_speedz",
                    "running_speed", "running_speedz", "jump_height", "jump_distance", "jump_distancez",
                    "dash_height", "dash_distance", "dash_distancez"] {
            guard let value = header[key].flatMap(Double.init), value.isFinite else {
                throw OriginalLoaderError.outsideVerifiedDomain("Missing original motion parameter: \(key)")
            }
        }
        guard header.integer("walking_frame_rate") > 0, header.integer("running_frame_rate") > 0 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Invalid motion frame rate")
        }
        for record in loader.frames.values {
            let next = Int(record.field("next")!)
            guard [0, 1, 2, 4, 5, 15].contains(record.field("state")!),
                  next == 999 || Self.frameNumbers.contains(next), record.field("wait")! >= 0,
                  record.field("dvx") == (record.number == 218 ? 1 : 0),
                  ["dvy", "dvz", "hit_a", "hit_d", "hit_j", "mp"].allSatisfy({ record.field($0) == 0 }),
                  record[0x58] == 0, record[0x88] == 0, record.interactions.isEmpty else {
                throw OriginalLoaderError.outsideVerifiedDomain("Unsupported movement frame: \(record.number)")
            }
        }
        frames = loader.frames; parameters = header; state = initial
        self.width = width; self.zMin = zMin; self.zMax = zMax
    }

    public var currentFrame: OriginalFrameRecord { frames[state.frame]! }
    private var frameState: Int { Int(currentFrame.field("state")!) }
    private func p(_ key: String) -> Double { parameters.number(key) }
    private mutating func walkPhase() {
        let rate = parameters.integer("walking_frame_rate")
        state.phase = (state.phase + 1) % (rate * 6)
        state.frame = state.phase < rate * 4 ? state.phase / rate + 5 : 11 - state.phase / rate
    }
    private mutating func frameSound() {
        if let sound = currentFrame.sound { state.sounds.append(sound) }
    }

    /// One simulation tick. The original normal timer advances by 33 ms, with a
    /// strict elapsed > 33 test. Rendering never interpolates simulation state.
    @discardableResult public mutating func tick(_ input: MovementInput) -> MovementState {
        state.sounds.removeAll(keepingCapacity: true)
        let right = input.contains(.right), left = input.contains(.left)
        let up = input.contains(.up), down = input.contains(.down), jump = input.contains(.jump)
        let rightOnly = right && !left, leftOnly = left && !right
        let upOnly = up && !down, downOnly = down && !up
        // 0x413080–0x413208: positive buffers decay before rising-edge capture.
        for (key, button) in [(\MovementState.rightBuffer, MovementInput.right), (\.leftBuffer, .left),
                              (\.upBuffer, .up), (\.downBuffer, .down), (\.jumpBuffer, .jump)] {
            if state[keyPath: key] > 0 { state[keyPath: key] -= 1 }
            if input.contains(button) && !previousInput.contains(button) { state[keyPath: key] = 5 }
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
            if jump && state.jumpBuffer > 0 { state.tap = 0; state.wait = 0; state.frame = 210 }
        }
        if frameState == 4 && state.iy < 0 {
            if rightOnly { state.facing = 0 }
            if leftOnly { state.facing = 1 }
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
        }
        // DAT movement fields at 0x414247. Among the allowed source frames only
        // stop-running has a nonzero value: dvx: 1. Validate this domain on load.
        let dvx = Double(currentFrame.field("dvx")!)
        if dvx != 0 {
            let direction = state.facing == 0 ? 1.0 : -1.0
            state.vx = max(state.vx * direction, dvx) * direction
        }
        // 0x40e490: position integrates before ground friction and gravity.
        state.x += state.vx; state.z += state.vz
        if state.iy >= 0 { state.vx = Self.friction(state.vx); state.vz = Self.friction(state.vz) }
        state.y += state.vy
        if state.y < 0 {
            state.vy += 1.7
        } else if (state.y > 0 && state.vy > 0) || (state.frame == 212 && state.vy == 0) {
            state.y = 0; state.vy = 0; state.vx /= 3
            state.frame = state.frame == 212 ? 215 : 219; state.wait = 0
        }
        state.ix = Int(state.x); state.iy = Int(state.y); state.iz = Int(state.z)
        // 0x417f80 / 0x41b5d0, player slot 0, stage scrolling disabled.
        state.z = min(zMax, max(zMin, state.z)); state.iz = Int(state.z)
        state.x = min(width, max(0, state.x)); state.ix = Int(state.x)
        // 0x41b910–0x41bc74: one living local player, original look-ahead and
        // integer camera smoothing. Position is sampled before frame scheduling.
        let target = min(Int(width) - 794, max(0, state.ix + 130 - state.facing * 260 - 397))
        state.cameraVelocity = ((target - state.cameraX) / 14 + state.cameraVelocity * 6) / 7
        if state.cameraVelocity == 0 && target != state.cameraX { state.cameraVelocity = target > state.cameraX ? 1 : -1 }
        state.cameraX = min(Int(width) - 794, max(0, state.cameraX + state.cameraVelocity))
        // 0x41f4a7 draws the actor BEFORE the 0x41fb06 scheduler call. Capture the
        // displayed frame separately; rendering post-scheduler would be one tick early.
        state.renderFrame = state.frame; state.renderFacing = state.facing
        // 0x40d960 frame scheduler, after physics, bounds and sprite drawing.
        if state.frame != state.previousFrame { frameSound(); state.wait = 0 }
        state.wait += 1
        if frameState == 0 && state.iy < 0 { state.frame = 212 }
        if state.wait > Int(currentFrame.field("wait")!) {
            state.wait = 0
            var next = Int(currentFrame.field("next")!)
            if next != 0 {
                if next < 0 { state.facing = 1 - state.facing; next = -next }
                let airReturn = next == 999 && state.iy != 0
                state.frame = next == 999 ? (airReturn ? 212 : 0) : next
                if state.frame == 212 && !airReturn {
                    state.vy = p("jump_height")
                    if rightOnly { state.vx = p("jump_distance") }
                    if leftOnly { state.vx = -p("jump_distance") }
                    if upOnly || downOnly { state.vz = p("jump_distancez") * (upOnly ? -1 : 1) }
                }
                frameSound()
            }
        }
        state.previousFrame = state.frame; previousInput = input
        return state
    }

    private static func friction(_ value: Double) -> Double {
        var result = value
        if result > 0.0001 { result -= 1; if result <= 0.0001 { result = 0 } }
        if result < -0.0001 { result += 1; if result > -0.0001 { result = 0 } }
        return result
    }
}
