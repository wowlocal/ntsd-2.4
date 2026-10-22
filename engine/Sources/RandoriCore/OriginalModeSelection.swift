import Foundation

public enum OriginalModeSelectionExit: String, Codable, Sendable {
    case panel, playback
}

public struct OriginalModeSelectionEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case soundRequest, soundMethod, method, free, postMessage, postQuit }
    public let kind: Kind
    public let arguments: [UInt32]
    public init(_ kind: Kind, _ arguments: [UInt32]) { self.kind = kind; self.arguments = arguments }
}

/// Mode-screen keyboard body4322ad..4328f8, with actual shared input, sound,
/// background and sound-device release rules. Rendering belongs to its caller.
/// Playback returns BEFORE43249c/input reset and its not-yet-connected file IO.
public enum OriginalModeSelection {
    public static func advance(world: OriginalStateRecord, actors: [OriginalStateRecord],
        globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
        observe: (OriginalModeSelectionEvent) throws -> Void = { _ in }) throws -> OriginalModeSelectionExit {
        var state = globals, owned = memory
        let base = OriginalMatchPreparation.globalBase
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base, as: Int32.self) }
        func write(_ address: Int, _ value: Int32) throws { try state.write(value, at: address-base) }
        func presentation(_ event: OriginalMenuPresentationEvent) throws {
            guard let kind = OriginalModeSelectionEvent.Kind(rawValue: event.kind.rawValue), event.strings.isEmpty else {
                throw OriginalStateError.invalidStorage("Mode selection presentation event")
            }
            try observe(.init(kind,event.arguments))
        }
        try OriginalMenuInput.advance(world: world, actors: actors, globals: &state)
        if try word(0x4513a4) != 0 {
            let value = try word(0x451160) &- 1
            try write(0x451160,value); try write(0x4513c0,0)
            if value < 0 { try write(0x451160,7) }
            if try state.integer(at: 0x44f1af-base, as: Int8.self) > 0, try word(0x451160) == 6 {
                try write(0x451160,5)
            }
        }
        if try word(0x4513a8) != 0 {
            let value = try (word(0x451160) &+ 1) % 8
            try write(0x4513c0,0); try write(0x451160,value)
            if try state.integer(at: 0x44f1af-base, as: Int8.self) > 0, value == 6 { try write(0x451160,7) }
        }
        var continuation = OriginalModeSelectionExit.panel
        if try word(0x4513b4) != 0 {
            try write(0x4513c0,0)
            if try word(0x451160) < 7 {
                try OriginalMatchPrelude.confirmationSound(in: state) { event in
                    switch event {
                    case .soundRequest(let loop): try observe(.init(.soundRequest,[loop ? 1 : 0]))
                    case .soundMethod(let resource, let offset, let arguments):
                        try observe(.init(.soundMethod,[resource,UInt32(offset)]+arguments))
                    default: throw OriginalStateError.invalidStorage("Mode selection sound event")
                    }
                }
            }
            for mode: Int32 in 0...5 where try word(0x451160) == mode {
                switch mode {
                case 0,1,4:
                    try write(0x4512c8,0); try write(0x44d020,3)
                    try write(0x44d024,100); try write(0x44d028,1)
                case 2,3:
                    try write(0x44d020,mode == 2 ? 20 : 120)
                    try write(0x44d024,0); try write(0x44d028,0)
                default: try write(0x44d020,2); try write(0x450c2c,1)
                }
                try write(0x4513c0,0); try write(0x44d780,-1)
                try OriginalMenuPresentation.releaseBackground(globals: &state, memory: &owned, observe: presentation)
            }
            if try word(0x451160) == 6 { continuation = .playback }
            else if try word(0x451160) == 7 {
                try OriginalMenuPresentation.releaseSoundDevice(globals: &state, observe: presentation)
                if try word(0x458434) == 0 { try observe(.init(.postQuit,[0])) }
            }
        }
        globals = state; memory = owned
        return continuation
    }
}
