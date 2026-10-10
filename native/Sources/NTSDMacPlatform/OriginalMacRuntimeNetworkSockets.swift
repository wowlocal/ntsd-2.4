import NTSDCore

extension OriginalMacRuntimeNetwork {
    /// The Mac network runtime: Darwin sockets with Dispatch readiness sources.
    public convenience init(localAddresses: [UInt32]? = nil) {
        self.init(localAddresses:localAddresses,sockets:OriginalMacWinsock())
    }
}
