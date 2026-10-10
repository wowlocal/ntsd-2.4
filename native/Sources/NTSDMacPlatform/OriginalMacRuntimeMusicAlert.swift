import AppKit
import NTSDCore

extension OriginalMacRuntimeMusic {
    /// MessageBoxA as a modal alert: caption as the message, text as details.
    public static let alert: ([UInt8],[UInt8]) -> Void = { text,caption in
        let alert = NSAlert(); alert.messageText = String(decoding:caption,as:UTF8.self)
        alert.informativeText = String(decoding:text,as:UTF8.self); alert.runModal()
    }
    /// The Mac runtime music: MessageBoxA text is shown as a modal alert.
    public convenience init(identities: OriginalMacResourceIdentityPool,heap: OriginalMacRuntimeHeap) {
        self.init(identities:identities,heap:heap,present:Self.alert)
    }
}
