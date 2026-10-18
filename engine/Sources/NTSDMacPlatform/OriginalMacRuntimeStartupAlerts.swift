import NTSDCore

extension OriginalMacRuntimeStartupService {
    /// The Mac startup service: runtime music whose MessageBoxA shows an NSAlert.
    public convenience init(windows: OriginalRuntimeWindowBackend,heap: OriginalMacRuntimeHeap,environment: Environment = .init()) {
        self.init(windows:windows,heap:heap,environment:environment,music:OriginalMacRuntimeMusic(identities:windows.identities,heap:heap))
    }
}
