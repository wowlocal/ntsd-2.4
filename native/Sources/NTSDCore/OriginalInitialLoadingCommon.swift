import Foundation

/// Own non-playback41bc90 prologue and common sound prefix, ending before the
/// catalog allocation. The complete loading call and outer tick remain pending.
public struct OriginalInitialLoadingCommon {
    public let globals: OriginalStateRecord
    public let sounds: [OriginalWaveLoadResult]
    public let paused: Bool
    /// Two distinct10-byte command arrays; intervening private padding is unknown.
    public let commands: [[UInt8]]

    public static func load(globals initial: OriginalStateRecord, targetSurface: UInt32,
                            fileSource: (String) throws -> [UInt8],
                            platform: (Int, String, UInt32) throws -> OriginalWavePlatform,
                            afterPrologue: (OriginalStateRecord, Bool) throws -> Void = { _, _ in },
                            afterWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
                            store: (Int, [UInt8]) throws -> Void = { _, _ in },
                            observe: (OriginalInitialSoundEvent) throws -> Void = { _ in },
                            beforeCommit: (Self) throws -> Void = { _ in }) throws -> Self {
        var globals = initial, sounds: [OriginalWaveLoadResult] = []
        let paused = try OriginalInitialLoading.begin(globals:&globals,store:store)
        try afterPrologue(globals,paused)
        try OriginalInitialSoundLoading.load(globals:&globals,targetSurface:targetSurface,
            fileSource:fileSource,platform:platform,afterWave:{ i,wave,state in
                sounds.append(wave);try afterWave(i,wave,state)
            },store:store,observe:observe)
        let result = Self(globals:globals,sounds:sounds,paused:paused,
                          commands:[[UInt8](repeating:0,count:10),[UInt8](repeating:0,count:10)])
        try beforeCommit(result)
        return result
    }
}
