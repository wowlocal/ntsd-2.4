import Foundation

public struct OriginalSurfaceFillRequest: Codable, Equatable, Sendable {
    public let target: UInt32, rectangle: [Int32], flags: UInt32, effects: [UInt8], defined: [Bool]
}

/// Original415160 writes only DDBLTFX size and fill color. The other92 bytes
/// retain explicitly supplied stack backing; they are not initialized to zero.
public enum OriginalSurfaceFilling {
    public static func request(target: UInt32,x: Int32,y: Int32,width: Int32,height: Int32,color: UInt32,backing: [UInt8]) throws -> OriginalSurfaceFillRequest {
        guard backing.count == 100 else { throw OriginalStateError.invalidStorage("Fill effects extent") }
        var effects = try OriginalStateRecord(bytes: backing,defined: [Bool](repeating: false,count: 100))
        try effects.write(UInt32(100),at: 0);try effects.write(color,at: 0x50)
        return .init(target: target,rectangle: [x,y,x &+ width,y &+ height],flags: 0x1000400,effects: effects.bytes,defined: effects.defined)
    }
}

public struct OriginalFrontScreenEvent: Codable, Equatable, Sendable {
    public let kind: String
    public var arguments: [UInt32] = [], strings: [[UInt8]] = []
    public var fill: OriginalSurfaceFillRequest?, read: OriginalBitmapDrawRead?, clip: OriginalBitmapClip?, blit: OriginalBitmapBlit?
    public init(_ kind: String, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) { self.kind = kind;self.arguments = arguments;self.strings = strings }
}

public struct OriginalFrontScreenInput: Codable, Sendable {
    public let drawTarget: UInt32, milliseconds: UInt32, threadHandle: UInt32, threadID: UInt32, lastError: UInt32
    public let fillResult: Int32, drawResults: [Int32]
    public init(drawTarget: UInt32,milliseconds: UInt32,threadHandle: UInt32,threadID: UInt32,lastError: UInt32,fillResult: Int32,drawResults: [Int32]) {
        self.drawTarget = drawTarget;self.milliseconds = milliseconds;self.threadHandle = threadHandle;self.threadID = threadID
        self.lastError = lastError;self.fillResult = fillResult;self.drawResults = drawResults
    }
}

/// Real42709b..427127/4275cb, including4237e0/43c450,415160,423840/43ee50 and
/// the first actual43f010 caller. Worker execution, device raster and the next
/// screen body are separate. No source EXE or expected snapshots are used here.
public struct OriginalFrontScreenPrelude {
    public enum Continuation: String, Codable, Sendable { case critical, alternate, nullFillTarget, nullBitmap, nullDrawTarget }
    public private(set) var bitmaps: [UInt32:OriginalLoadedBitmap] = [:]
    public private(set) var surfaces: [UInt32:UInt32] = [:]
    public init() {}
    ///Transfer already owned background wrappers, preserving constructor bytes
    ///and the explicitly bound raw surface tokens across caller compositions.
    public init(bitmaps: [UInt32:OriginalLoadedBitmap],surfaces: [UInt32:UInt32]) throws {
        guard Set(bitmaps.keys) == Set(surfaces.keys),!bitmaps.keys.contains(0) else { throw OriginalStateError.invalidStorage("Background ownership inputs") }
        for (address,bitmap) in bitmaps {
            guard bitmap.storage.bytes.count == 0x1f50,try bitmap.storage.integer(at: 0,as: UInt32.self) == (surfaces[address] == 0 ? 0 : 1) else { throw OriginalStateError.invalidStorage("Background surface binding") }
        }
        self.bitmaps = bitmaps;self.surfaces = surfaces
    }

    public mutating func advance(globals: inout OriginalStateRecord,input: OriginalFrontScreenInput,fillBacking: [UInt8],
        allocate: () throws -> OriginalInterfaceAllocation,
        source: (String) throws -> (OriginalBitmapInput,UInt32,Int32),
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Continuation {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize, !input.drawResults.isEmpty else { throw OriginalStateError.invalidStorage("Front screen inputs") }
        var state = globals, candidate = self
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-base,as: UInt32.self) }
        func write(_ address: Int,_ value: UInt32) throws {
            try state.write(value,at: address-base);try observe(.init("write",[UInt32(address),4,value]))
        }
        func finish(_ end: Continuation) -> Continuation { globals = state;self = candidate;return end }
        if try word(0x44d064) == UInt32(bitPattern: -2) {
            let setting = try word(0x450be8)
            if setting == UInt32.max { try write(0x44d064,UInt32(bitPattern: -3)) }
            else { try write(0x44d064,0);if setting == 1 { try OriginalMenuWorkerRequest.run(globals: state,threadHandle: input.threadHandle,threadID: input.threadID,lastError: input.lastError,observe: observe) } }
        }
        let fill = try OriginalSurfaceFilling.request(target: word(0x455608),x: 0,y: 0,width: 794,height: 550,color: 0x10206c,backing: fillBacking)
        guard fill.target != 0 else { return finish(.nullFillTarget) }
        var filled = OriginalFrontScreenEvent("fill");filled.fill = fill;try observe(filled)
        if try word(0x4511ac) == 0 {
            try observe(.init("timer",[input.milliseconds]))
            let number = input.milliseconds%13+1, path = "MENU_BACK\(number)"
            var formatted = Array("MENU_BACK0000\0".utf8)
            for (i,b) in (Array(path.utf8)+[0]).enumerated() { formatted[i] = b }
            try observe(.init("format",[number,UInt32(path.utf8.count)],[Array("MENU_BACK%d".utf8),formatted]))
            try observe(.init("allocate",[0x1f50]))
            let allocation = try allocate()
            if allocation.address != 0 {
                guard candidate.bitmaps[allocation.address] == nil else { throw OriginalStateError.invalidStorage("Front background reused live allocation") }
                try observe(.init("construct",[allocation.address,0x40,0],[Array(path.utf8)]))
                let (resource,surface,key) = try source(path)
                guard resource.path == path else { throw OriginalStateError.invalidStorage("Front background resource binding") }
                candidate.bitmaps[allocation.address] = try OriginalBitmapConstructor.construct(resource,optional: false,backing: allocation.backing,
                    device: word(0x457578),flags: 0x40,surface: surface,colorKeyResult: key) { e in try observe(.init(e.kind.rawValue,e.arguments,e.strings)) }
                candidate.surfaces[allocation.address] = surface != 0 && key >= 0 ? surface : 0
            }
            try write(0x4511ac,allocation.address)
        }
        let token = try word(0x4511ac)
        let y = try word(0x44d064) == 0 ? Int32(bitPattern: word(0x453da4)) : 0
        try observe(.init("draw",[token,0,UInt32(bitPattern: y),UInt32.max,1,0,input.drawTarget]))
        guard token != 0 else { return finish(.nullBitmap) }
        guard let bitmap = candidate.bitmaps[token], let surface = candidate.surfaces[token] else { throw OriginalStateError.invalidStorage("Unbound front background wrapper") }
        let drawInput = try OriginalBitmapDrawInput(x: 0,y: y,frame: -1,colorKey: 1,mirrored: 0,sourceSurface: surface,targetSurface: input.drawTarget,
            viewportWidth: Int32(bitPattern: word(0x44d78c)),viewportHeight: Int32(bitPattern: word(0x44d790)))
        var blits = 0
        do {
            _ = try OriginalBitmapDrawing.draw(drawInput,bitmap: bitmap.storage,observeRead: { r in
                var e = OriginalFrontScreenEvent("read");e.read = r;try observe(e)
            },observeClip: { c in
                var e = OriginalFrontScreenEvent("clip");e.clip = c;try observe(e)
            },perform: { b in
                var e = OriginalFrontScreenEvent("blit");e.blit = b;try observe(e)
                let result = input.drawResults[blits%input.drawResults.count];blits += 1;return result
            })
        } catch OriginalStateError.invalidStorage(let detail) where detail == "Null bitmap target surface" { return finish(.nullDrawTarget) }
        return try finish(word(0x44d064) == 0 ? .critical : .alternate)
    }
}
