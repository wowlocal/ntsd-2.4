extension OriginalApplicationCatalogSession {
    /// Immutable original resources and declared presentation inputs. Expected
    /// records, captured structure writes and private source backing do not enter
    /// the runtime resource contract.
    public struct Resources {
        public let files: [String:[UInt8]], bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
        public let presentation: OriginalMenuPresentationInput
        public let drawResult: Int32, graphicsResult: Int32, allocationFill: UInt8
        public init(files: [String:[UInt8]],bitmaps: [String:OriginalApplicationStartupInputs.Bitmap],
                    presentation: OriginalMenuPresentationInput,drawResult: Int32,graphicsResult: Int32,allocationFill: UInt8) throws {
            guard files[OriginalLoadingFiles.temporaryPath] == nil else { throw Boundary.input("External temporary file") }
            self.files = files;self.bitmaps = bitmaps;self.presentation = presentation
            self.drawResult = drawResult;self.graphicsResult = graphicsResult;self.allocationFill = allocationFill
        }
    }
    /// A fresh provider belongs to one tentative attempt. Callbacks supply
    /// declared logical replies and must not publish platform effects. The
    /// session journals effects for its enclosing application continuation.
    /// Captured bitmap writes are rejected even for a callback-based provider.
    public struct Controls {
        public let allocate: (Allocation.Kind,Int) throws -> UInt32
        public let bitmap: (API.Request) throws -> API.Response
        public let file: (String,String) throws -> OriginalLoadingFileAllocation
        public let wave: (OriginalSoundRegistration,UInt32) throws -> OriginalWavePlatform
        public let volume: ([UInt32]) throws -> Int32
        public let time: () throws -> UInt32
        public let message: (String,[UInt8]) throws -> MessageInput
        public let finish: () throws -> Void
        public init(allocate: @escaping (Allocation.Kind,Int) throws -> UInt32,
                    bitmap: @escaping (API.Request) throws -> API.Response,
                    file: @escaping (String,String) throws -> OriginalLoadingFileAllocation,
                    wave: @escaping (OriginalSoundRegistration,UInt32) throws -> OriginalWavePlatform,
                    volume: @escaping ([UInt32]) throws -> Int32,time: @escaping () throws -> UInt32,
                    message: @escaping (String,[UInt8]) throws -> MessageInput,
                    finish: @escaping () throws -> Void = {}) {
            self.allocate = allocate;self.bitmap = bitmap;self.file = file;self.wave = wave
            self.volume = volume;self.time = time;self.message = message;self.finish = finish
        }
    }
    static func fixedControls(_ input: Inputs) -> Controls {
        let owner = FixedControls(input)
        return .init(allocate:{ _,_ in try owner.take(input.allocationTokens,&owner.ai,"allocation") },
            bitmap:{ _ in try owner.take(input.bitmapReplies,&owner.bi,"bitmap reply") },
            file:{ _,_ in try owner.take(input.fileAllocations,&owner.fi,"file allocation") },
            wave:{ _,_ in try owner.take(input.waves,&owner.wi,"registered WAV") },
            volume:{ _ in try owner.take(input.volumeReplies,&owner.vi,"volume reply") },
            time:{ try owner.take(input.times,&owner.ti,"clock") },
            message:{ _,_ in try owner.take(input.messages,&owner.mi,"message") },finish:owner.finish)
    }
    private final class FixedControls {
        let input: Inputs
        var ai = 0,bi = 0,fi = 0,wi = 0,vi = 0,ti = 0,mi = 0
        init(_ input: Inputs) { self.input = input }
        func take<T>(_ values: [T],_ index: inout Int,_ label: String) throws -> T {
            guard index < values.count else { throw Boundary.exhausted(label) }
            defer { index += 1 };return values[index]
        }
        func finish() throws {
            guard ai == input.allocationTokens.count,bi == input.bitmapReplies.count,fi == input.fileAllocations.count,
                  wi == input.waves.count,vi == input.volumeReplies.count,ti == input.times.count,mi == input.messages.count else {
                throw Boundary.input("Unused catalog controls")
            }
        }
    }
}
