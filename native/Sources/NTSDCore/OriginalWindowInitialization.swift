/// Whole43bec0 and its original window/DirectDraw children at declared platform
/// and helper-entry backing boundaries. No Windows code or CPU runs natively.
public enum OriginalWindowInitialization {
    public struct Request: Codable, Equatable, Sendable {
        public let kind: String, words: [UInt32], strings: [[UInt8]]
        public let bytes: [UInt8]?, defined: [Bool]?
        public init(_ kind: String, _ words: [UInt32] = [], strings: [[UInt8]] = [],
                    structure: OriginalStateRecord? = nil) {
            self.kind = kind; self.words = words; self.strings = strings
            bytes = structure?.bytes; defined = structure?.defined
        }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32, output: UInt32?, bytes: [UInt8]?
        public init(result: Int32 = 0, output: UInt32? = nil, bytes: [UInt8]? = nil) {
            self.result = result; self.output = output; self.bytes = bytes
        }
    }
    public struct Result: Equatable, Sendable {
        public let returnCode: Int32, written: [Bool]
    }

    /// Scratch is the opaque storage at each actual helper entry, before that
    /// helper's own field writes. It is not a completed expected descriptor or
    /// recovered WinMain stack. Callers must resolve its provenance explicitly.
    /// Buffer platform effects: a thrown adapter/backing error rolls back globals.
    public static func initialize(instance: UInt32, show: Int32,
        globals: inout OriginalStateRecord,
        backing: (String, Int) throws -> [UInt8],
        perform: (Request) throws -> Response,
        store: OriginalWindowInput.Store = { _,_ in }) throws -> Result {
        try run(wrapperInstance: instance,globals: &globals,backing: backing,perform: perform,store: store)
    }
    /// Whole43bdd0 without43bec0's instance store and extra ShowWindow. The
    /// lifecycle caller supplies its own previously initialized instance global.
    public static func configure(globals: inout OriginalStateRecord,
        backing: (String, Int) throws -> [UInt8],
        perform: (Request) throws -> Response,
        store: OriginalWindowInput.Store = { _,_ in }) throws -> Result {
        try run(wrapperInstance: nil,globals: &globals,backing: backing,perform: perform,store: store)
    }
    private static func run(wrapperInstance: UInt32?,globals: inout OriginalStateRecord,
        backing: (String, Int) throws -> [UInt8],perform: (Request) throws -> Response,
        store: OriginalWindowInput.Store) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Window initialization globals extent")
        }
        var state = globals, written = [Bool](repeating: false, count: globals.bytes.count)
        let instance = try wrapperInstance ?? state.integer(at: 0x4554c0-0x44d000,as: UInt32.self)
        func word(_ address: Int) throws -> UInt32 {
            try state.integer(at: address-0x44d000, as: UInt32.self)
        }
        func put(_ address: Int, _ value: UInt32) throws {
            try state.write(value, at: address-0x44d000)
            for offset in (address-0x44d000)..<(address-0x44d000+4) { written[offset] = true }
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) })
        }
        func frame(_ kind: String, _ count: Int) throws -> OriginalStateRecord {
            let bytes = try backing(kind,count)
            guard bytes.count == count else { throw OriginalStateError.invalidStorage("Window \(kind) backing extent") }
            return try .init(bytes: bytes, defined: [Bool](repeating: false,count: count))
        }
        func call(_ kind: String, _ words: [UInt32] = [], structure: OriginalStateRecord? = nil,
                  strings: [[UInt8]] = []) throws -> Response {
            try perform(.init(kind,words,strings: strings,structure: structure))
        }
        func numeric(_ kind: String, _ words: [UInt32] = []) throws -> Int32 {
            try call(kind,words).result
        }
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func debug(_ text: String) throws { _ = try call("debug",strings: [Array(text.utf8)]) }
        func output(_ response: Response, _ address: Int) throws {
            guard let handle = response.output, handle != 0 else {
                throw OriginalStateError.invalidStorage("Missing successful window/COM output provenance")
            }
            try put(address,handle)
        }
        func createSurface(_ draw: UInt32, _ address: Int, _ description: OriginalStateRecord) throws -> Int32 {
            let response = try call("createSurface",[draw,UInt32(address),0],structure: description)
            if response.result >= 0 { try output(response,address) }
            return response.result
        }
        func createWindow(fullscreen: Bool) throws -> UInt32 {
            var wc = try frame("windowClass",40)
            if !fullscreen {
                let x = try bits(numeric("metric",[7]))
                let y1 = try bits(numeric("metric",[8]))
                let y2 = try bits(numeric("metric",[8]))
                let caption = try bits(numeric("metric",[4]))
                try put(0x44d014,word(0x44d78c) &+ x &+ x)
                try put(0x44d018,word(0x44d790) &+ y1 &+ y2 &+ caption)
            }
            for (offset,value): (Int,UInt32) in [(0,3),(4,0x43b3d0),(8,0),(12,0),(16,instance)] {
                try wc.write(value,at: offset)
            }
            try wc.write(bits(numeric("icon",[instance,0x7f00])),at: 20)
            if !fullscreen { try wc.write(bits(numeric("cursor",[0,0x7f00])),at: 24) }
            // The fullscreen helper leaves hCursor's four backing bytes alone.
            for (offset,value): (Int,UInt32) in [(28,0),(32,0x447634),(36,0x447634)] {
                try wc.write(value,at: offset)
            }
            _ = try call("registerClass",structure: wc)
            let width: UInt32, height: UInt32
            if fullscreen {
                height = try bits(numeric("metric",[1]));width = try bits(numeric("metric",[0]))
            } else { width = try word(0x44d014);height = try word(0x44d018) }
            let handle = try bits(call("createWindow",[
                fullscreen ? 8 : 0,0x447634,0x447620,fullscreen ? 0x80000000 : 0x10cb0000,
                fullscreen ? 0 : 0x80000000,fullscreen ? 0 : 5,width,height,0,0,instance,0],
                strings: [Array("Marti".utf8),Array("Little Fighter 2".utf8)]).result)
            if !fullscreen && handle != 0 { _ = try numeric("updateWindow",[handle]) }
            return handle
        }
        func directDraw(fullscreen: Bool) throws -> Int32 {
            let response = try call("directDrawCreate",[0,0x457578,0])
            guard response.result >= 0 else { return response.result }
            try output(response,0x457578)
            let status = try numeric("cooperativeLevel",[word(0x457578),word(0x4546f4),fullscreen ? 0x11 : 8])
            if fullscreen {
                guard status >= 0 else {
                    try debug("DDStartup: Couldn't set exclusive mode.\n");return status
                }
                try debug("DDStartup: Setting exclusive mode...\n")
                return try numeric("displayMode",[word(0x457578),word(0x44d78c),word(0x44d790),8])
            }
            try debug("DDStartup: Setting windowed mode...\n");return status
        }
        func plainSurfaces(_ draw: UInt32) throws -> Int32 {
            var description = try frame("surfaceDescription",108)
            try description.write(UInt32(108),at: 0);try description.write(UInt32(1),at: 4)
            try description.write(UInt32(0x200),at: 104)
            let primary = try createSurface(draw,0x455634,description)
            guard primary >= 0 else {
                try debug("DDCreateFakeFlipper: Couldn't create primary.\n");return primary
            }
            try description.write(word(0x44d790),at: 8);try description.write(word(0x44d78c),at: 12)
            try description.write(UInt32(7),at: 4);try description.write(UInt32(0x40),at: 104)
            let back = try createSurface(draw,0x455608,description)
            guard back >= 0 else {
                try debug("DDCreateFakeFlipper: Couldn't create backbuffer.\n");return back
            }
            try debug("DDCreateFakeFlipper: Using fake flipper.\n");return back
        }
        func swapSurfaces(_ draw: UInt32, _ count: UInt32) throws -> Int32 {
            var description = try frame("surfaceDescription",108)
            for (offset,value): (Int,UInt32) in [(0,108),(4,0x21),(8,try word(0x44d790)),
                (12,try word(0x44d78c)),(20,count),(104,0x4218)] {
                try description.write(value,at: offset)
            }
            let status = try createSurface(draw,0x455634,description)
            guard status >= 0 else { return status }
            let response = try call("attachedSurface",[word(0x455634),4,0x455608])
            if response.result >= 0 { try output(response,0x455608) }
            return response.result
        }
        func clearSetup() throws -> Int32 {
            var format = try frame("pixelFormat",32);try format.write(UInt32(32),at: 0)
            _ = try call("pixelFormat",[word(0x455634)],structure: format)
            let effects = try backing("fillEffects",100)
            let status = try OriginalSurfaceClearing.clear(target: word(0x455608),color: 0,backing: effects) { request in
                let structure = try OriginalStateRecord(bytes: request.effects,defined: request.defined)
                return try call("blt",[request.target,0,0,0,request.flags],structure: structure).result
            }
            if status < 0 { try debug("UpdateFrame: Couldn't fill back buffer.\n");return 0 }
            try debug("LoadGameArt: Art loaded.\n");return 1
        }
        func fullConfigure(_ draw: UInt32) throws -> Int32 {
            if try swapSurfaces(draw,2) >= 0 {
                _ = try clearSetup()
                //43e8e0 is0/1: the signed-negative retry cannot execute here.
                return 1
            }
            if try swapSurfaces(draw,1) < 0 {
                guard try plainSurfaces(draw) >= 0 else {
                    try debug("DDFullConfigure: Couldn't create fake flipper.\n");return 0
                }
                try debug("DDFullConfigure: Using fake flipper.\n")
            }
            return try clearSetup()
        }
        func windowedConfigure(_ draw: UInt32) throws -> Int32 {
            let surfaces = try plainSurfaces(draw)
            guard surfaces >= 0 else { return surfaces }
            let clip = try call("createClipper",[draw,0,0x457584,0])
            guard clip.result >= 0 else { return clip.result }
            try output(clip,0x457584)
            let status = try numeric("clipperWindow",[word(0x457584),0,word(0x4546f4)])
            guard status >= 0 else { return status }
            _ = try numeric("setClipper",[word(0x455634),word(0x457584)])
            _ = try numeric("release",[word(0x457584)])
            _ = try numeric("showWindow",[word(0x4546f4),5])
            return 1
        }
        func display() throws -> Int32 {
            let fullscreen = try word(0x458430) != 0
            let window = try createWindow(fullscreen: fullscreen);try put(0x4546f4,window)
            guard window != 0 else { return 0 }
            guard try directDraw(fullscreen: fullscreen) >= 0 else {
                try debug("DDStartup failed.\n");return 0
            }
            if fullscreen {
                // Even fullConfigure's all-surface-fail return0 is accepted.
                guard try fullConfigure(word(0x457578)) >= 0 else { return 0 }
                try put(0x458348,2)
            } else {
                guard try windowedConfigure(word(0x457578)) >= 0 else { return 0 }
                //The format-word pointer is passed but4011d0 never writes it.
                try put(0x458348,word(0x453e0c) == 0 ? 3 : 1)
            }
            return 1
        }
        if wrapperInstance != nil { try put(0x4554c0,instance) }
        let displayed = try display()
        //43bdd0 returns0/1. The outer negative-only error branch never handles0,
        //and ignores nCmdShow; it always calls ShowWindow, even for a null HWND.
        if wrapperInstance != nil { _ = try numeric("showWindow",[word(0x4546f4),5]) }
        globals = state
        return .init(returnCode: wrapperInstance == nil ? displayed : 1,written: written)
    }
}
