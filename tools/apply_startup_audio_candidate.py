"""Finite per-call sound/WAV candidate transform; original expectations stay intact."""
from pathlib import Path

def once(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)

def wave(s):
    s=once(s,'    public var format: OriginalStateRecord?, descriptor: OriginalStateRecord?','''    public var format: OriginalStateRecord?, descriptor: OriginalStateRecord?
    public var initialStorage: OriginalWaveStorage?
    public var lockReplies: [OriginalWaveResponse] = []
    public var regions: [UInt32: OriginalStateRecord] = [:]''')
    start=s.index('    public static func load(path:')
    body=s.index('        func close() throws',start)
    s=s[:start]+'''    public static func load(path: [UInt8], file: [UInt8], output: UInt32, platform p: OriginalWavePlatform,
                            audio: OriginalWaveRequest.Handler? = nil,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        try load(path:path,file:file,output:output,platform:p,outputStored:{ _ in },audio:audio,observe:observe)
    }

    public static func load(path: [UInt8], file: [UInt8], output: UInt32, platform p: OriginalWavePlatform,
                            outputStored: (UInt32) throws -> Void,
                            audio: OriginalWaveRequest.Handler? = nil,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        let legacy = try OriginalWaveLegacyReplies(p)
        if let audio {
            return try run(path:path,file:file,output:output,input:legacy.input,request:audio,
                legacyFirstPointer:nil,outputStored:outputStored,observe:observe)
        }
        return try run(path:path,file:file,output:output,input:legacy.input,request:legacy.reply,
            legacyFirstPointer:p.firstPointer,outputStored:outputStored,observe:observe)
    }

    public static func loadObserved(path: [UInt8],file: [UInt8],output: UInt32,input: OriginalWaveInput,
        request: OriginalWaveRequest.Handler,outputStored: (UInt32) throws -> Void = { _ in },
        observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        try run(path:path,file:file,output:output,input:input,request:request,legacyFirstPointer:nil,
            outputStored:outputStored,observe:observe)
    }

    private static func run(path: [UInt8],file: [UInt8],output: UInt32,input p: OriginalWaveInput,
        request: OriginalWaveRequest.Handler,legacyFirstPointer: UInt32?,outputStored: (UInt32) throws -> Void,
        observe: (OriginalWaveEvent) throws -> Void) throws -> OriginalWaveLoadResult {
        guard !path.contains(0),path.count < 256,p.descendResults.count == 3,
            p.storage.first.bytes.count <= 2_000_000,(p.storage.second?.bytes.count ?? 0) <= 2_000_000 else {
            throw error("Platform input extent")
        }
        func backing(_ count: Int,_ origin: Int = 0) throws -> OriginalStateRecord { try p.storage.backing(count,origin) }
        var result = try OriginalWaveLoadResult(output:output,first:p.storage.first.record(),second:p.storage.second?.record())
        result.initialStorage = p.storage
        func event(_ kind: OriginalWaveEvent.Kind,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws {
            try observe(.init(kind,args,strings))
        }
        func audio(_ q: OriginalWaveRequest) throws -> OriginalWaveResponse {
            try q.validate();try observe(q.event)
            let response = try request(q)
            guard q.accepts(response) else { throw error("Audio response family") }
            return response
        }
'''+s[body:]
    s=once(s,'        func message(_ text: String) throws { try event(.message, [0, 0], [bytes(text), []]) }','        func message(_ text: String) throws { _ = try audio(.init(.init(.message,[0,0],[bytes(text),[]]))) }')
    s=once(s,'            try event(.message, [0, 0], [bytes("Could not Open Wave File <")+path+bytes(">"), path])','            _ = try audio(.init(.init(.message,[0,0],[bytes("Could not Open Wave File <")+path+bytes(">"),path])))')
    s=once(s,'        try event(.create, [p.device, 0], [descriptor.bytes, format.bytes])\n        if p.createResult != 0 {','''        let created = try audio(.init(.init(.create,[p.device,0],[descriptor.bytes,format.bytes]),
            structures:[.init(descriptor),.init(format)]))
        guard case .created(let createResult,let createdBuffer) = created else { throw error("Create response") }
        if createResult != 0 {''')
    a=s.index('        guard p.buffer != 0, p.firstPointer != 0');b=s.index('        try event(.free); result.temporaryLive = false',a)
    s=s[:a]+'''        guard let buffer = createdBuffer,buffer != 0 else { throw error("Null device output") }
        // Preserve the old aggregate adapter's preflight boundary. Actual replies
        // have no future first pointer to inspect before issuing Lock.
        if let legacyFirstPointer,legacyFirstPointer == 0 { throw error("Null device output") }
        func lock() throws -> OriginalWaveResponse {
            let reply = try audio(.init(.init(.lock,[buffer,0,UInt32(data.count),0])))
            result.lockReplies.append(reply);return reply
        }
        var locked = try lock()
        guard case .locked(let firstResult,_) = locked else { throw error("Lock response") }
        if firstResult == 0x88780096 {
            _ = try audio(.init(.init(.restore,[buffer])))
            locked = try lock()
        }
        // Final HRESULT is ignored, while actual output spans must have owners.
        guard case .locked(_,let outputs?) = locked,
            outputs.firstPointer != 0,(0...2_000_000).contains(outputs.firstCount),
            (0...2_000_000).contains(outputs.secondCount),outputs.firstCount <= data.count,
            outputs.secondCount <= data.count-outputs.firstCount else { throw error("Lock output extent") }
        func bind(_ token: UInt32,_ count: Int,_ region: OriginalWaveRegion?) throws {
            guard let region,region.token == token,region.storage.bytes.count >= count,
                region.storage.bytes.count <= 2_000_000 else { throw error("Lock region binding") }
            let record = try region.storage.record()
            if let earlier = result.regions[token],earlier != record { throw error("Conflicting Lock alias backing") }
            result.regions[token] = record
        }
        try bind(outputs.firstPointer,outputs.firstCount,outputs.first)
        if outputs.secondPointer != 0 { try bind(outputs.secondPointer,outputs.secondCount,outputs.second) }
        func copy(_ index: UInt32,_ offset: Int,_ count: Int,_ token: UInt32) throws {
            guard let temporary = result.temporary,var region = result.regions[token] else { throw error("Copy storage") }
            let payload = Array(temporary.bytes[offset..<(offset+count)]),mask = Array(temporary.defined[offset..<(offset+count)])
            _ = try audio(.init(.init(.copy,[index,UInt32(offset),UInt32(count)]),target:token,bytes:payload,defined:mask))
            var raw = region.bytes,known = region.defined
            raw.replaceSubrange(0..<count,with:payload);known.replaceSubrange(0..<count,with:mask)
            region = try .init(bytes:raw,defined:known);result.regions[token] = region
        }
        try copy(0,0,outputs.firstCount,outputs.firstPointer)
        if outputs.secondPointer != 0 { try copy(1,outputs.firstCount,outputs.secondCount,outputs.secondPointer) }
        result.first = result.regions[outputs.firstPointer]!
        result.second = outputs.secondPointer == 0 ? nil : result.regions[outputs.secondPointer]
        _ = try audio(.init(.init(.unlock,[buffer,outputs.firstPointer,UInt32(outputs.firstCount),outputs.secondPointer,UInt32(outputs.secondCount)])))
'''+s[b:]
    s=once(s,'        result.output = p.buffer; result.returned = 1\n        try outputStored(p.buffer)','        result.output = buffer; result.returned = 1\n        try outputStored(buffer)')
    return s

def menu(s):
    end=s.index('    public static func load(')
    prefix=once(s[:end],'        var candidate = globals\n        let base = OriginalMatchPreparation.globalBase','''        try initializeDevice(globals:&globals,window:window,request:{ try OriginalSoundLegacyReplies.reply(platform,$0) },store:store,observe:observe)
    }
    public static func initializeDevice(globals: inout OriginalStateRecord,window: UInt32,
        request: (Event) throws -> OriginalSoundResponse,
        store: (Int,UInt32) throws -> Void = { _,_ in },
        observe: (Event,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Bool {
        var candidate = globals
        let base = OriginalMatchPreparation.globalBase''')
    s=prefix+s[end:]
    s=once(s,'        try observe(.init("deviceCreate", [0, 0x44eecc, 0]), candidate)\n        if let output = platform.createdDevice { try put(output) }\n        if platform.createResult != 0 {','''        let create = Event("deviceCreate",[0,0x44eecc,0]);try observe(create,candidate)
        let response = try request(create)
        if let output = response.output { try put(output) }
        if response.result != 0 {''')
    s=once(s,'        guard platform.createdDevice != nil, device != 0 else {','        guard response.output != nil, device != 0 else {')
    s=once(s,'        try observe(.init("cooperativeLevel", [device, window, 1]), candidate)','        let cooperative = Event("cooperativeLevel",[device,window,1]);try observe(cooperative,candidate);_ = try request(cooperative)')
    a=s.index('        var candidate = globals',s.index('    public static func load('))
    s=s[:a]+'''        var replies: [Int:OriginalWaveLegacyReplies] = [:]
        return try loadObserved(globals:&globals,soundRequest:{ try OriginalSoundLegacyReplies.reply(platform,$0) },
            waveInput:{ i,path,destination,device in
                let p = try wavePlatform(i,path,destination,device),r = try OriginalWaveLegacyReplies(p)
                replies[i] = r;return r.input
            },waveRequest:{ binding,q in
                guard let r = replies[binding.index] else { throw OriginalStateError.invalidStorage("Legacy WAV call binding") }
                return try r.reply(q)
            },fileSource:fileSource,afterWave:afterWave,store:store,observe:observe)
    }

    public static func loadObserved(globals: inout OriginalStateRecord,
        soundRequest: (Event) throws -> OriginalSoundResponse,
        waveInput: (Int,String,UInt32,UInt32) throws -> OriginalWaveInput,
        waveRequest: (OriginalWaveBinding,OriginalWaveRequest) throws -> OriginalWaveResponse,
        fileSource: (String) throws -> [UInt8],
        afterWave: (Int,OriginalWaveLoadResult,OriginalStateRecord) throws -> Void = { _,_,_ in },
        store: (Int,UInt32) throws -> Void = { _,_ in },
        observe: (Event,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
'''+s[a:]
    s=once(s,'let ready = try initializeDevice(globals: &candidate, window: window, platform: platform, store: store, observe: observe)','let ready = try initializeDevice(globals:&candidate,window:window,request:soundRequest,store:store,observe:observe)')
    s=once(s,'            try observe(.init("message", [currentWindow, 0x30], [Array("Could not initialize Direct Sound".utf8), []]), candidate)','''            let message = Event("message",[currentWindow,0x30],[Array("Could not initialize Direct Sound".utf8),[]])
            try observe(message,candidate);_ = try soundRequest(message)''')
    s=once(s,'            let p = try wavePlatform(index, path, destination, device)','            let p = try waveInput(index,path,destination,device)')
    s=once(s,'            let result = try OriginalWaveLoader.load(path: Array(path.utf8), file: file, output: before, platform: p) {','''            let binding = OriginalWaveBinding(index,path,destination,device)
            let result = try OriginalWaveLoader.loadObserved(path:Array(path.utf8),file:file,output:before,input:p,
                request:{ try waveRequest(binding,$0) }) {''')
    return s

def input_startup(s):
    a=s.index('        var state = globals',s.index('    public static func load('))
    s=s[:a]+'''        try loadBody(globals:&globals,request:request,sound:{ state in
            try OriginalMenuSoundStartup.load(globals:&state,platform:soundPlatform,wavePlatform:wavePlatform,
                fileSource:fileSource,afterWave:afterWave,store:{ try store($0,little($1)) },observe:observeSound)
        },store:store,capabilities:capabilities)
    }

    public static func loadObserved(globals: inout OriginalStateRecord,
        request: (Request,OriginalStateRecord) throws -> Response,
        soundRequest: (OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse,
        waveInput: (Int,String,UInt32,UInt32) throws -> OriginalWaveInput,
        waveRequest: (OriginalWaveBinding,OriginalWaveRequest) throws -> OriginalWaveResponse,
        fileSource: (String) throws -> [UInt8],store: OriginalWindowInput.Store = { _,_ in },
        capabilities: (Int,OriginalStateRecord) throws -> Void = { _,_ in },
        afterWave: (Int,OriginalWaveLoadResult,OriginalStateRecord) throws -> Void = { _,_,_ in },
        observeSound: (OriginalMenuSoundStartup.Event,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
        try loadBody(globals:&globals,request:request,sound:{ state in
            try OriginalMenuSoundStartup.loadObserved(globals:&state,soundRequest:soundRequest,waveInput:waveInput,
                waveRequest:waveRequest,fileSource:fileSource,afterWave:afterWave,
                store:{ try store($0,little($1)) },observe:observeSound)
        },store:store,capabilities:capabilities)
    }

    private static func loadBody(globals: inout OriginalStateRecord,
        request: (Request,OriginalStateRecord) throws -> Response,
        sound: (inout OriginalStateRecord) throws -> OriginalMenuSoundStartup.Result,
        store: OriginalWindowInput.Store,capabilities: (Int,OriginalStateRecord) throws -> Void) throws -> Result {
'''+s[a:]
    s=once(s,'        let sounds = try OriginalMenuSoundStartup.load(globals:&state,platform:soundPlatform,wavePlatform:wavePlatform,\n            fileSource:fileSource,afterWave:afterWave,store:{ try store($0,little($1)) },observe:observeSound)','        let sounds = try sound(&state)')
    return s

def winmain(s):
    s=once(s,'    var sound: OriginalMenuSoundStartup.Platform { get }','''    var sound: OriginalMenuSoundStartup.Platform { get }
    var observesAudio: Bool { get }
    func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse
    func waveInput(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput
    func waveRequest(_ binding: OriginalWaveBinding,_ request: OriginalWaveRequest) throws -> OriginalWaveResponse''')
    anchor='/// Actual WinMain entry through43d100'
    s=once(s,anchor,'''public extension OriginalWinMainStartupPlatform {
    var observesAudio: Bool { false }
    func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        throw OriginalStateError.invalidStorage("No observed sound provider")
    }
    func waveInput(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput {
        throw OriginalStateError.invalidStorage("No prepared WAV inputs")
    }
    func waveRequest(_ binding: OriginalWaveBinding,_ request: OriginalWaveRequest) throws -> OriginalWaveResponse {
        throw OriginalStateError.invalidStorage("No observed WAV provider")
    }
}

'''+anchor)
    a=s.index('        candidate.input = try OriginalInputStartup.load(');b=s.index('        try p.observe(.stage("input-return"',a)
    old=s[a:b]
    s=s[:a]+'''        if p.observesAudio {
            candidate.input = try OriginalInputStartup.loadObserved(globals:&state,request:p.joystick,
                soundRequest:p.soundRequest,waveInput:p.waveInput,waveRequest:p.waveRequest,fileSource:{ path in
                    guard let bytes = try p.file(path) else { throw OriginalStateError.invalidStorage("Missing declared menu WAV source") }
                    return bytes
                },store:store,capabilities:{ try p.observe(.capabilities($0,$1)) },
                afterWave:{ try p.observe(.wave($0,$1,$2)) },observeSound:{ try p.observe(.sound($0,$1)) })
        } else {
'''+old+'''        }
'''+s[b:]
    return s

def exchange(s):
    s=once(s,'    case wave(OriginalApplicationPreparedStartupPlatform.Wave)','''    case wave(OriginalApplicationPreparedStartupPlatform.Wave)
    case sound(OriginalMenuSoundStartup.Event), waveAudio(OriginalWaveBinding,OriginalWaveRequest)''')
    s=once(s,'        default: return false','''        case (.sound,.sound):return true
        case let (.waveAudio(_,q),.waveAudio(r)):return q.accepts(r)
        default: return false''')
    s=once(s,'    case cursor(UInt32), joystick(OriginalInputStartup.Response), wave(OriginalWavePlatform)','''    case cursor(UInt32), joystick(OriginalInputStartup.Response), wave(OriginalWavePlatform)
    case sound(OriginalSoundResponse), waveAudio(OriginalWaveResponse)''')
    return s

def prepared(s):
    s=once(s,'        public var sound: OriginalMenuSoundStartup.Platform','''        public var sound: OriginalMenuSoundStartup.Platform
        public var observesAudio = false
        public var waveInputs: [Reply<OriginalWaveBinding,OriginalWaveInput>] = []''')
    s=once(s,'    public var sound: OriginalMenuSoundStartup.Platform { prepared.sound }','''    public var sound: OriginalMenuSoundStartup.Platform { prepared.sound }
    public var observesAudio: Bool { prepared.observesAudio }''')
    s=once(s,'            .joystick:prepared.joysticks.count,.wave:prepared.waves.count]','            .joystick:prepared.joysticks.count,.wave:prepared.observesAudio ? prepared.waveInputs.count : prepared.waves.count]')
    s=once(s,'        for kind in Kind.allCases {','''        guard prepared.observesAudio ? prepared.waves.isEmpty : prepared.waveInputs.isEmpty else {
            throw Boundary.unconsumed(.wave,prepared.waves.count+prepared.waveInputs.count)
        }
        for kind in Kind.allCases {''')
    s=once(s,'    public func observe(_ event: OriginalWinMainStartup.Observation) throws {}','''    public func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        guard observesAudio,startupExchange != nil else { throw Boundary.invalidResponse }
        return try response(.sound(event),{ if case .sound(let v) = $0 { return v };return nil },
            otherwise:{ throw Boundary.invalidResponse }())
    }
    public func waveInput(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput {
        guard observesAudio else { throw Boundary.invalidResponse }
        return try take(.wave,prepared.waveInputs,OriginalWaveBinding(index,path,destination,device))
    }
    public func waveRequest(_ binding: OriginalWaveBinding,_ request: OriginalWaveRequest) throws -> OriginalWaveResponse {
        guard observesAudio,startupExchange != nil else { throw Boundary.invalidResponse }
        return try response(.waveAudio(binding,request),{ if case .waveAudio(let v) = $0 { return v };return nil },
            otherwise:{ throw Boundary.invalidResponse }())
    }
    public func observe(_ event: OriginalWinMainStartup.Observation) throws {}''')
    return s

def bridge(s):
    s=once(s,'    case wave(OriginalWaveEvent,OriginalWavePlatform)','''    case wave(OriginalWaveEvent,OriginalWavePlatform)
    case soundReply(OriginalMenuSoundStartup.Event,OriginalSoundResponse)
    case waveReply(OriginalWaveBinding,OriginalWaveRequest,OriginalWaveResponse)
    case wavePrepared(OriginalWaveBinding,OriginalWaveEvent,OriginalWaveInput)''')
    s=once(s,'        default:return .platform','''        case let .wavePrepared(_,event,_):return [.allocate,.free].contains(event.kind) ? .ownedMemory : .platform
        default:return .platform''')
    s=once(s,'    private var currentWave: OriginalWavePlatform?','''    private var currentWave: OriginalWavePlatform?
    private var currentAudioWave: (OriginalWaveBinding,OriginalWaveInput)?''')
    s=once(s,'    var sound: OriginalMenuSoundStartup.Platform { platform.sound }','''    var sound: OriginalMenuSoundStartup.Platform { platform.sound }
    var observesAudio: Bool { platform.observesAudio }
    func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        let response = try platform.soundRequest(event);operations.append(.soundReply(event,response));return response
    }
    func waveInput(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput {
        let input = try platform.waveInput(index,path,destination,device)
        currentAudioWave = (.init(index,path,destination,device),input);return input
    }
    func waveRequest(_ binding: OriginalWaveBinding,_ request: OriginalWaveRequest) throws -> OriginalWaveResponse {
        let response = try platform.waveRequest(binding,request)
        operations.append(.waveReply(binding,request,response));return response
    }''')
    s=once(s,'            if let wave = event.wave {','''            if observesAudio {
                if let wave = event.wave, ![.load,.create,.lock,.restore,.copy,.unlock,.message].contains(wave.kind) {
                    guard let (binding,input) = currentAudioWave else { throw OriginalStateError.invalidStorage("Startup audio input lifetime") }
                    operations.append(.wavePrepared(binding,wave,input))
                }
            } else if let wave = event.wave {''')
    return s

def initial(s):
    s=once(s,'                            observe: (OriginalInitialSoundEvent) throws -> Void = { _ in }) throws {','''                            audio: OriginalWaveRequest.Factory? = nil,
                            observe: (OriginalInitialSoundEvent) throws -> Void = { _ in }) throws {''')
    s=once(s,'                }) {\n                    try observe(.init(wave: $0))','                },audio:try audio?(input)) {\n                    try observe(.init(wave: $0))')
    return s

def reference(s):
    s=once(s,'    public static func compare(_ input: Data) throws -> Result {','    public static func compare(_ input: Data,audio: OriginalWaveRequest.Factory? = nil) throws -> Result {')
    s=once(s,'output: item.outputBefore, platform: item.input) { events.append($0) }','output: item.outputBefore, platform: item.input,audio:try audio?(item.input)) { events.append($0) }')
    s=once(s,'            }) { events.append($0) }','            },audio:audio) { events.append($0) }')
    return s

def apply(candidate,templates):
    changes={}
    funcs={'OriginalWaveLoader':wave,'OriginalMenuSoundStartup':menu,'OriginalInputStartup':input_startup,
        'OriginalWinMainStartup':winmain,'OriginalApplicationStartupPlatform':bridge,
        'OriginalStartupRequestExchange':exchange,'OriginalApplicationPreparedStartupPlatform':prepared,
        'OriginalInitialSoundLoading':initial}
    for name,transform in funcs.items():
        path='native/Sources/NTSDCore/'+name+'.swift';f=candidate/path;before=f.read_text();after=transform(before)
        f.write_text(after);changes[path]=dict(before=before,after=after)
    path='native/Sources/NTSDReferenceChecks/WaveLoaderReference.swift';f=candidate/path;before=f.read_text();after=reference(before)
    f.write_text(after);changes[path]=dict(before=before,after=after)
    path='native/Tests/NTSDCoreTests/OriginalApplicationObservedStartupTests.swift';f=candidate/path;before=f.read_text()
    after=once(before,'            case .wave(let w):return .wave(try values.wave(w.index,w.path,w.destination,w.device))','''            case .wave(let w):return .wave(try values.wave(w.index,w.path,w.destination,w.device))
            case .sound,.waveAudio:throw Stop.missingOutcome // This legacy helper never serves the new audio path.''')
    assert before[before.index('    func testWholeWinMainWithObservedRequests'):]==after[after.index('    func testWholeWinMainWithObservedRequests'):]
    f.write_text(after);changes[path]=dict(before=before,after=after)
    for path,name in [('native/Sources/NTSDCore/OriginalStartupAudio.swift','OriginalStartupAudio.swift'),
        ('native/Tests/NTSDCoreTests/OriginalStartupAudioTests.swift','OriginalStartupAudioTests.swift'),
        ('native/Tests/NTSDCoreTests/OriginalStartupAudioMenuCorpus.swift','OriginalStartupAudioMenuCorpus.swift')]:
        f=candidate/path;assert not f.exists();after=(templates/name).read_text();f.write_text(after);changes[path]=dict(before=None,after=after)
    return changes
