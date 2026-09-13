import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Immutable saved observations for the first body and16 following calls.
/// Decoding/normalization is test-only; no snapshot is supplied to Core.
final class OriginalApplicationGameplaySource {
    typealias R = MatchLaunchReference
    typealias Stage = OriginalGameplayBody.Stage
    typealias C = ContinuousGameplayReference
    struct Write: Decodable { let pc: UInt32,address: UInt32,size: Int,value: UInt64 }
    struct PCs: Decodable { let instructions: [UInt32],writes: [Write]? }
    struct FirstPCs: Decodable { let control: Bool,cases: [PCs] }
    struct Trace: Decodable {
        struct Call: Decodable { let globalsWrites: [Write],stages: [PCs],output: PCs }
        let cases: [Call]
    }
    struct Section {
        let stage: Stage,before: R.State,after: R.State,pcs: Set<UInt32>,end: UInt32
        let first: R.Control.Section?
        let continued: C.Section?,output: C.Output?
        let writes: [Write]
    }
    struct Call {
        let sections: [Section],beforeInput: R.State?,writes: [Write]
        let continued: C.Case?
    }
    static let specifications: [(Stage,String,UInt32)] = [
        (.control,"control",0x41e634),(.physics,"physics",0x41eed1),
        (.links,"depth-attachments",0x41eed8),(.contacts,"contacts",0x41eefb),
        (.hits,"hits-items",0x41f2ac),(.cpointActions,"cpoint-actions",0x41f2b3),
        (.cpointPlacement,"cpoint-placement",0x41f2b8),(.cpointCleanup,"cpoint-cleanup",0x41f47d),
        (.attachments,"cpoint-attachments",0x41f484),(.camera,"camera-background",0x41f496),
        (.drawing,"world-drawing",0x41f4ac),(.impulses,"post-draw-impulses",0x41f550),
        (.lifecycle,"post-draw-lifecycle",0x4214d5),(.commands,"post-draw-commands",0x421a15),
        (.hud,"world-hud",0x421a2d),(.notices,"post-hud-notices",0x421cdc),
        (.recording,"result-recording",0x422944),(.layout,"result-layout",0x422994),
        (.output,"gameplay-return",0x30000000)]
    private(set) var calls: [Call] = []
    private(set) var blobs: [String:InputControlReference.Blob] = [:]
    private var cache: [String:[UInt8]] = [:]
    private(set) var actorAddresses: [UInt32] = [],objectAddresses: [UInt32] = []
    private(set) var initializedImpulseControlWord: UInt32?
    let reverse: Bool
    init(_ reverse: Bool) throws {
        self.reverse = reverse
        var first: [Section] = []
        var previousSnapshot: [String:Any]?
        var previousSHA: String?
        var impulsesRoot: [String:Any]?
        let names = ["control","links","contacts","hits","cpoints","camera","drawing","impulses",
                     "lifecycle","commands","hud","notices","result-recording","result-layout","return"]
        for name in names {
            let data = try Self.fixture("original-gameplay-"+name+(reverse ? "-control" : ""))
            let raw = try MatchPreparationReference.unpack(data,maximumCount:128_000_000)
            let c = try JSONDecoder().decode(R.Control.self,from:raw)
            let pcs = try JSONDecoder().decode(FirstPCs.self,from:raw)
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
            var expectedParent = previousSHA
            if name == "lifecycle" {
                // Lifecycle names an initialized-gameplay aggregate as parent.
                // Verify its actual impulse snapshot bridge, not a renamed SHA.
                let bridgeData = try Self.fixture("original-initialized-gameplay"+(reverse ? "-control" : ""))
                let bridgeRaw = try MatchPreparationReference.unpack(bridgeData,maximumCount:128_000_000)
                let bridge = try XCTUnwrap(JSONSerialization.jsonObject(with:bridgeRaw) as? [String:Any])
                let impulses = try XCTUnwrap(impulsesRoot)
                for key in ["exeSHA256","dllSHA256","control","worldAddress","actorAddresses","objectAddresses","parent"] {
                    try Self.same(XCTUnwrap(bridge[key]),XCTUnwrap(impulses[key]),"Initialized bridge "+key)
                }
                let a = try XCTUnwrap(bridge["cases"] as? [[String:Any]])
                let b = try XCTUnwrap(impulses["cases"] as? [[String:Any]])
                guard a.count == 1,b.count == 1 else { throw Self.error("Initialized bridge count") }
                for key in ["label","before","after","end"] {
                    try Self.same(XCTUnwrap(a[0][key]),XCTUnwrap(b[0][key]),"Initialized impulse bridge "+key)
                }
                var initialized = try XCTUnwrap(a[0]["impulses"] as? [String:Any])
                var historical = try XCTUnwrap(b[0]["impulses"] as? [String:Any])
                // INITIALIZED_GAMEPLAY records this exact metadata difference:
                // historical reported CW0, initialized game CPU CW023f.
                // Records/events coincide; the two environments are not equal.
                try Self.same(XCTUnwrap(initialized.removeValue(forKey:"fpcw")),0x23f,"Initialized impulse CW")
                try Self.same(XCTUnwrap(historical.removeValue(forKey:"fpcw")),0,"Historical impulse CW")
                try Self.same(initialized,historical,"Initialized impulse non-CW fields")
                initializedImpulseControlWord = 0x23f
                expectedParent = MatchPreparationReference.digest(bridgeData)
            }
            guard pcs.control == reverse,c.worldAddress == 0x22000020,
                  expectedParent == nil || c.parent.sha256 == expectedParent else { throw Self.error("First parent identity") }
            previousSHA = MatchPreparationReference.digest(data)
            if name == "impulses" { impulsesRoot = root }
            let rawCases = try XCTUnwrap(root["cases"] as? [[String:Any]])
            for part in rawCases {
                let before = try XCTUnwrap(part["before"] as? [String:Any])
                if let previousSnapshot { try Self.continuity(previousSnapshot,before) }
                previousSnapshot = try XCTUnwrap(part["after"] as? [String:Any])
            }
            try identity(c.exeSHA256,c.dllSHA256,c.actorAddresses,c.objectAddresses)
            try merge(c.blobs)
            guard c.cases.count == pcs.cases.count else { throw Self.error("First PC inventory") }
            for (part,pc) in zip(c.cases,pcs.cases) {
                let specification = try XCTUnwrap(Self.specifications.first { $0.1 == part.label })
                guard part.end.pc == specification.2 else { throw Self.error("First stop "+part.label) }
                first.append(.init(stage:specification.0,before:part.before,after:part.after,
                    pcs:Set(pc.instructions),end:part.end.pc,first:part,continued:nil,output:nil,
                    writes:part.gameplayReturn?.writes.map { .init(pc:$0.pc,address:$0.address,size:$0.size,value:UInt64($0.value)) } ?? []))
            }
        }
        guard first.map(\.stage) == Self.specifications.map(\.0) else { throw Self.error("First stage order") }
        calls.append(.init(sections:first,beforeInput:nil,writes:[],continued:nil))
        let data = try Self.fixture("original-continuous-gameplay"+(reverse ? "-control" : ""))
        let document = try C.Document(data),c = document.corpus
        let raw = try MatchPreparationReference.unpack(data,maximumCount:256_000_000)
        let trace = try JSONDecoder().decode(Trace.self,from:raw)
        guard c.control == reverse,c.worldAddress == 0x22000020,c.parent.sha256 == previousSHA else { throw Self.error("Continuous parent identity") }
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
        let components = try XCTUnwrap(root["components"] as? [String:Any])
        let rawCalls = try XCTUnwrap(root["cases"] as? [[String:Any]])
        var initial: [String:Any] = [:]
        for (key,value) in c.initial { initial[key] = try XCTUnwrap(components[value]) }
        try Self.continuity(XCTUnwrap(previousSnapshot),initial)
        try identity(c.exeSHA256,c.dllSHA256,c.actorAddresses,c.objectAddresses);try merge(c.blobs)
        guard c.cases.count == 16,trace.cases.count == 16,rawCalls.count == 16 else { throw Self.error("Continuous call count") }
        var previous = c.initial,previousFPU = 1614
        for (index,part) in c.cases.enumerated() {
            let pc = trace.cases[index]
            guard part.index == index+1,part.stages.count == 18,pc.stages.count == 18 else { throw Self.error("Continuous identity") }
            guard part.before == previous,part.fpuStart == previousFPU,part.fpuEnd > previousFPU,
                  part.acquired == nil,part.acquisition == nil,
                  part.keyboardBefore == [UInt8](repeating:117,count:300),part.keyboardAfter == part.keyboardBefore,
                  part.cycle.stimulus.isEmpty,part.cycle.local.dispatch.isEmpty,
                  part.cycle.prefix.paused == 0,part.cycle.round.paused == 0,
                  part.cycle.round.continuation == .gameplay,part.cycle.round.endPC == 0x41e339,
                  part.cycle.end.pc == 0x41e339,
                  part.cycle.prefix.phase == UInt32(index%2),part.end.pc == 0x30000000,
                  part.end.sp == 0x1000f42c else { throw Self.error("Continuous input/return continuity") }
            previous = part.after;previousFPU = part.fpuEnd
            let cycle = try XCTUnwrap(rawCalls[index]["cycle"] as? [String:Any])
            let round = try XCTUnwrap(cycle["round"] as? [String:Any])
            let entry = part.stages[0].before
            for (refs,field,other) in [(part.before,"state",cycle["before"]),
                (part.before,"early",cycle["earlyBefore"]),(entry,"state",cycle["after"]),
                (entry,"state",round["after"]),(entry,"early",cycle["earlyAfter"])] {
                let key = try XCTUnwrap(refs[field])
                try Self.same(XCTUnwrap(components[key]),XCTUnwrap(other),"Input handoff "+field)
            }
            var sections: [Section] = []
            for (n,stage) in part.stages.enumerated() {
                let expected = Self.specifications[n]
                guard stage.label == expected.1,stage.end.pc == expected.2 else { throw Self.error("Continuous stage") }
                if n > 0 {
                    guard stage.before == part.stages[n-1].after else { throw Self.error("Continuous stage continuity") }
                }
                sections.append(.init(stage:expected.0,before:try document.snapshot(stage.before),
                    after:try document.snapshot(stage.after),pcs:Set(pc.stages[n].instructions),end:stage.end.pc,
                    first:nil,continued:stage,output:nil,writes:[]))
            }
            guard part.output.label == "gameplay-return",part.output.end.pc == 0x30000000,
                  part.output.before == part.stages.last?.after,
                  part.output.after == part.after.filter({ !["frameHeap","objects","objectStrings"].contains($0.key) }) else { throw Self.error("Continuous return") }
            sections.append(.init(stage:.output,before:try document.snapshot(part.output.before),
                after:try document.snapshot(part.after),pcs:Set(pc.output.instructions),end:part.output.end.pc,
                first:nil,continued:nil,output:part.output,writes:try XCTUnwrap(pc.output.writes)))
            calls.append(.init(sections:sections,beforeInput:try document.snapshot(part.before),
                writes:pc.globalsWrites,continued:part))
        }
    }
    /// Compare all fields present on both sides. Older first-stage captures
    /// omit optional heaps; this establishes no observation for missing fields.
    private static func continuity(_ before: [String:Any],_ after: [String:Any]) throws {
        let required: Set<String> = ["state","early","backgrounds","bitmaps","music","released"]
        guard required.isSubset(of:Set(before.keys)),required.isSubset(of:Set(after.keys)) else { throw error("Snapshot fields") }
        for key in Set(before.keys).intersection(after.keys) {
            try same(before[key]!,after[key]!,"Snapshot continuity "+key)
        }
    }
    private static func same(_ before: Any,_ after: Any,_ label: String) throws {
        let options: JSONSerialization.WritingOptions = [.sortedKeys,.fragmentsAllowed,.withoutEscapingSlashes]
        guard try JSONSerialization.data(withJSONObject:before,options:options) == JSONSerialization.data(withJSONObject:after,options:options) else { throw error(label) }
    }
    static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Owned gameplay source: "+detail) }
    static func fixture(_ name: String) throws -> Data {
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        guard MatchPreparationReference.digest(data) == fixtureSHA256[name] else { throw error("Pinned fixture "+name) }
        return data
    }
    private func identity(_ exe: String,_ dll: String,_ actors: [UInt32],_ objects: [UInt32]) throws {
        guard exe == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              dll == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              actors.count == 400,objects.count == 137,
              Set(actors).count == 400,Set(objects).count == 137 else { throw Self.error("Artifact/owner identity") }
        if actorAddresses.isEmpty { actorAddresses = actors;objectAddresses = objects }
        guard actorAddresses == actors,objectAddresses == objects else { throw Self.error("Changed source owner identities") }
    }
    private func merge(_ values: [String:InputControlReference.Blob]) throws {
        for (key,value) in values {
            if let old = blobs[key] { guard old.count == value.count else { throw Self.error("Blob extent collision") } }
            else { blobs[key] = value }
        }
    }
    func bytes(_ key: String) throws -> [UInt8] {
        if let value = cache[key] { return value }
        let item = try XCTUnwrap(blobs[key])
        let value = try MatchPreparationReference.inflate(item.deflate,count:item.count,maximumCount:8_000_000)
        guard MatchPreparationReference.digest(Data(value)) == key else { throw Self.error("Blob SHA256") }
        cache[key] = value;return value
    }
    func record(_ value: R.Storage) throws -> OriginalStateRecord { try record(value.bytes,value.defined) }
    func record(_ data: String,_ mask: String) throws -> OriginalStateRecord {
        let b = try bytes(data),m = try bytes(mask)
        guard b.count == m.count,m.allSatisfy({ $0 < 2 }) else { throw Self.error("Record mask") }
        return try .init(bytes:b,defined:m.map { $0 != 0 })
    }
    func globals(_ value: R.State) throws -> OriginalStateRecord {
        let b = try bytes(value.state.globals)
        guard b.count == OriginalMatchPreparation.globalSize else { throw Self.error("Globals extent") }
        return try .init(bytes:b,defined:[Bool](repeating:true,count:b.count))
    }
    func pool(_ value: R.State) throws -> OriginalStateRecord {
        var record = try record(value.state.poolBytes,value.state.poolMask)
        guard record.bytes.count == 0x7d8+400*0x420 else { throw Self.error("Pool extent") }
        let actors = Dictionary(uniqueKeysWithValues:actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues:objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        for i in 0..<400 {
            try record.write(XCTUnwrap(actors[record.integer(at:0x194+4*i,as:UInt32.self)]),at:0x194+4*i)
            let offset = 0x7d8+i*0x420+0x368
            try record.write(XCTUnwrap(objects[record.integer(at:offset,as:UInt32.self)]),at:offset)
        }
        guard try record.integer(at:0x7d4,as:UInt32.self) == 0x60000020 else { throw Self.error("World catalog") }
        try record.write(UInt32(0),at:0x7d4);return record
    }
}

extension OriginalApplicationGameplaySource {
    static let fixtureSHA256: [String:String] = [
        "original-initialized-gameplay":"4bb7d30ed264080448ea3bfc4caf23ea19b034b6072a4e7ff635ccd0059f2021",
        "original-initialized-gameplay-control":"12a76740835532182976f6b04acca7b2481c36299f15cf35d346486b359b7b6a",
        "original-gameplay-control":"e4f40b4a2006af544e264771e68717fd36d9ab285a56f3f445ee0c2cf80ddc34",
        "original-gameplay-links":"a1f9c4bcaee2a7f8aa45a98244cd497028c455f36e9fd189ee008b069af753f1",
        "original-gameplay-contacts":"805799981ce2b9be32f42985272e31e20378a0972e8ba4f64543edfb3fc34d55",
        "original-gameplay-hits":"5457f8de24023e45609f54d0979ebf38c749acd24f5173a321fd5f278252fb64",
        "original-gameplay-cpoints":"61e8ffa9e4e70961604f369fe7d8ec9f8e43a0e1b05862a4254e99b973bfdf5c",
        "original-gameplay-camera":"37644de333eca58bb194173ac06de4cf7a4cd987c01777a97f60b3b5502e60a2",
        "original-gameplay-drawing":"e67f51ba2123a6d83772f2485e5ab66a5704787f5b470955d2c134735cc5d475",
        "original-gameplay-impulses":"dfa37eb7cc99ae7700568eae32e2b503b79db37e6bbe6824b765c5cff0531127",
        "original-gameplay-lifecycle":"4fbc875297342a98a4f08aa85d5f885c45131c5877447bcc3161d7cd5f595d36",
        "original-gameplay-commands":"7e7d2dfb65ad8098b134a8e7d4122ea4cefde855b66a2be8c6b47eacb5e5a5bc",
        "original-gameplay-hud":"cabd4bba5fcb0b30018991da3ebe6033f0146cee6049348de74e6f8d3b3ea2fc",
        "original-gameplay-notices":"13a20c9a69a13f17683a754de9d0b01ef26ebf619f0ffca502689ecc916e17b0",
        "original-gameplay-result-recording":"4eb6c300d097caa0976672fea3421669d70a47fcf7e94929da7b0ce3dacf6f9e",
        "original-gameplay-result-layout":"46dadb7f012dc872cfba1154fba96ade055679753f0e89fc5c11d5116b21bf59",
        "original-gameplay-return":"14d6e0a1422becb638fbf0998d6ca14f1fb0cf71f2b1cf8c8409c6c0bfab8f1b",
        "original-gameplay-control-control":"84819383c9b90c4b1f842831a479450968f4ce508375ae24aa2c564666ad2c2a",
        "original-gameplay-links-control":"a4093ee349a2d6e93699991264e6d7c2f74983ea77dbc5fd8ac328d8c7a312b9",
        "original-gameplay-contacts-control":"c57fb48ab17a72403a20704c8d5ea60cb8c9043a44fba9e08a75dd2c62509730",
        "original-gameplay-hits-control":"a8c195ce46689b8023f7b2d4d0cdade16a646ee0f0c907965c9fa2ff64c3d3ff",
        "original-gameplay-cpoints-control":"04975e952326314b92d050f91914f69505f27cb86652c0e1b491470f451dd77b",
        "original-gameplay-camera-control":"53648008dddc6aa95d4c7c731491b33b97bb83f0d501f6ccd903b7f8a7bc4d00",
        "original-gameplay-drawing-control":"af26827730b0d2d5ead105904aa6b8c05f0b71302cd9a15bf997f482ccf699de",
        "original-gameplay-impulses-control":"2701607a611892c6e431d31dc570fdd7b041a015c66873e11861c22ed9f8ba55",
        "original-gameplay-lifecycle-control":"47ad9a281bc0d11350c75b2d2d6d08cae94e010fd4989ac3d7747c766a835ebb",
        "original-gameplay-commands-control":"134b0930f1e1feb4e49a53139059b6daea9b32990feed4bb95e5bd7eace4bb1e",
        "original-gameplay-hud-control":"6127e7368b0b3a553f9a53bd0ec7ed78d132eb063e724df6dfa368f7eee7f62c",
        "original-gameplay-notices-control":"34bbdd39bde852d12c03ae9898cd8b27001719a40c792f434def7c77aaf79024",
        "original-gameplay-result-recording-control":"b73b3a39266cb8830496ace238748ecc3f0bdc8be08f2ecbda5866b933be0db2",
        "original-gameplay-result-layout-control":"8b10d326d1183fc6154d36c3431eaa6f66c72457711973d8a87690a14655f353",
        "original-gameplay-return-control":"5a95942f5240529df5dbb661ce18b9ae0801ad1a5c4c6b3353268f86abf995f2",
        "original-continuous-gameplay":"2e4184b1617ab41d31a502f407a5fa296a57664e8f8e60e0ebef6ec58efe4471",
        "original-continuous-gameplay-control":"24a1fe4f91da3491df12076c827e01214a4329a8aa65d7aaf8b7dfd28ca50f2c",
    ]
}
