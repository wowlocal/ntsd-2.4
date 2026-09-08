import Foundation

/// Device portion shared by frame410a20..410a67 and weapon40be01..40be37.
/// The caller's path cache is committed only after this method returns.
public struct OriginalRegisteredSoundLoading {
    public private(set) var buffers: [Int: OriginalWaveLoadResult] = [:]
    public init() {}

    public mutating func load(_ request: OriginalSoundRegistration, device: UInt32, outputBefore: UInt32,
                              platform: OriginalWavePlatform, fileSource: (String) throws -> [UInt8],
                              onWave: (OriginalWaveEvent) throws -> Void = { _ in },
                              onVolume: ([UInt32]) throws -> Void = { _ in }) throws {
        // The parent skips the helper entirely when audio is disabled.
        guard device != 0 else { return }
        guard request.index >= 0, request.index <= (0x2e00-1)/20,
              platform.device == device, platform.destination == 0x452948+UInt32(request.index)*4,
              buffers[request.index] == nil else { throw OriginalStateError.invalidStorage("Registered sound device/index binding") }
        let file = try platform.stream == 0 ? [] : fileSource(request.path)
        let result = try OriginalWaveLoader.load(path: request.path.unicodeScalars.map { UInt8($0.value) },
            file: file, output: outputBefore, platform: platform, observe: onWave)
        guard result.exit == .returned, result.output != 0 else {
            // The EXE dereferences the resulting buffer even after an ordinary
            // false return. Do not silently advance the cache past that fault.
            throw OriginalStateError.invalidStorage("Original registry reaches invalid SetVolume continuation")
        }
        try onVolume([result.output, UInt32(bitPattern: -10000)])
        // SetVolume's HRESULT is ignored; no buffer is released by this caller.
        buffers[request.index] = result
    }
}
