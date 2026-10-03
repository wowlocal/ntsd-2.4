import AppKit
import NTSDCore

extension OriginalMacRuntimeMusic {
    /// The Mac runtime music: MessageBoxA text is shown as a modal alert.
    public convenience init(identities: OriginalMacResourceIdentityPool,heap: OriginalMacRuntimeHeap) {
        self.init(identities:identities,heap:heap) { text,caption in
            let alert = NSAlert(); alert.messageText = String(decoding:caption,as:UTF8.self)
            alert.informativeText = String(decoding:text,as:UTF8.self); alert.runModal()
        }
    }
}
