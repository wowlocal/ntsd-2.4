/// Shared loading-session state. Parent, Object and BG mutate the same checksum
/// and bitmap order. Object calls also share the sound cache and raw Frame heap.
/// Kept as a value so failed public loads cannot partially commit the session.
struct OriginalLoaderResources {
    var checksum: UInt32 = 0
    var bitmaps: [OriginalLoadedBitmap] = []
    var sounds = OriginalSoundRegistry()
    var frameHeap = OriginalFrameHeap()
}
