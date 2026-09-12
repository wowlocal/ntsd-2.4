import Foundation

public struct OriginalInitialSoundEvent: Codable, Equatable, Sendable {
    public let wave: OriginalWaveEvent?
    public let presentation: OriginalMenuPresentationEvent?
    public init(wave: OriginalWaveEvent) { self.wave = wave; presentation = nil }
    public init(presentation: OriginalMenuPresentationEvent) { self.presentation = presentation; wave = nil }
}

/// Loading prefix41be98..41bfeb: before the catalog/400-slot pool allocation.
/// Shared fixed resources are listed in the EXE, not inferred from characters.
public enum OriginalInitialSoundLoading {
    public static let paths = ["data\\001.wav","data\\002.wav","data\\006.wav","data\\010.wav","data\\011.wav","data\\004.wav",
        "data\\016.wav","data\\017.wav","data\\020.wav","data\\021.wav","data\\025.wav","data\\032.wav",
        "data\\033.wav","data\\039.wav","data\\065.wav","data\\066.wav","data\\068.wav","data\\085.wav"]

    public static func load(globals: inout OriginalStateRecord, targetSurface: UInt32,
                            fileSource: (String) throws -> [UInt8],
                            platform: (Int, String, UInt32) throws -> OriginalWavePlatform,
                            afterWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
                            attemptedWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
                            store: (Int, [UInt8]) throws -> Void = { _, _ in },
                            observe: (OriginalInitialSoundEvent) throws -> Void = { _ in }) throws {
        var candidate = globals
        let base = OriginalMatchPreparation.globalBase
        guard candidate.bytes.count == OriginalMatchPreparation.globalSize,
              try candidate.integer(at: 0x44d05c-base, as: Int32.self) == 1 else {
            throw OriginalStateError.invalidStorage("Initial sound loading context")
        }
        try observe(.init(presentation: .init(.bitmap, [candidate.integer(at: 0x45118c-base, as: UInt32.self),
                                                       0,0,UInt32.max,0,0,targetSurface])))
        for (address, count) in [(0x457588,1600),(0x453e10,320)] {
            for i in stride(from: 0, to: count, by: 4) {
                try candidate.write(UInt32(0), at: address-base+i)
                try store(address+i, [0,0,0,0])
            }
        }
        for (index,path) in paths.enumerated() {
            let destination = UInt32(0x451db0+index*4), input = try platform(index,path,destination)
            guard input.destination == destination,
                  try candidate.integer(at: 0x44eecc-base, as: UInt32.self) == input.device else {
                throw OriginalStateError.invalidStorage("Initial sound device/destination binding")
            }
            try observe(.init(wave: .init(.load, [destination], [Array(path.utf8)])))
            let file = try input.device == 0 || input.stream == 0 ? [] : fileSource(path)
            let result = try OriginalWaveLoader.load(path: Array(path.utf8), file: file,
                output: candidate.integer(at: Int(destination)-base, as: UInt32.self), platform: input,
                outputStored: { value in
                    try candidate.write(value, at: Int(destination)-base)
                    try store(Int(destination),(0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
                }) {
                    try observe(.init(wave: $0))
                }
            try attemptedWave(index,result,candidate)
            guard result.exit == .returned else { throw OriginalStateError.invalidStorage("Invalid original CreateSoundBuffer continuation") }
            try candidate.write(result.output, at: Int(destination)-base)
            try afterWave(index,result,candidate)
        }
        // Individual false returns are ignored by this caller. Count is always
        //18, including when audio is disabled or an individual file can't open.
        try candidate.write(Int32(18), at: 0x45843c-base)
        try store(0x45843c,[18,0,0,0])
        try OriginalMenuPresentation.presentSurface(globals: candidate) { try observe(.init(presentation: $0)) }
        globals = candidate
    }
}
