import NTSDCore

/// Compare output and both actual returns from independently rebuilt own state.
/// Source machine frames establish provenance only; they never seed native state.
enum GameplayReturnReference {
    struct Input: Decodable {
        struct Position: Decodable, Equatable {
            let pc: UInt32, sp: UInt32, saved: [UInt32], seh: UInt32
            let returnPC: UInt32?, argument: UInt32?
        }
        struct Write: Decodable { let pc: UInt32, address: UInt32, size: Int, value: UInt32 }
        struct Binding: Decodable { let table: UInt32, offset: UInt32, before: UInt32, after: UInt32, argumentCount: Int }
        let input: OriginalMenuPresentationInput, events: [OriginalFrontScreenEvent], writes: [Write]
        let methodBindings: [Binding], loadedSoundBuffers: [UInt32]
        let entryObservations: [Position], returnObservations: [Position]
        let resourceSurfaces: [String:UInt32], drawResults: [Int32]
        let fpcw: UInt16, fpswBefore: UInt16, fpswAfter: UInt16, fptagBefore: UInt16, fptagAfter: UInt16
    }
    struct Result { let helpers: Int, events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay return reference: "+text) }

    static func compare(_ section: MatchLaunchReference.Control.Section, state: inout OriginalMatchPreparation,
        context: inout OriginalInputControlContext,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32)) throws -> Result {
        guard let n = section.gameplayReturn, section.label == "gameplay-return", section.end.pc == 0x30000000,
              section.end.sp == 0x1000f42c, section.checkpoints.isEmpty,
              section.before.frameHeap != nil, section.after.frameHeap != nil,
              section.before.menuBitmaps != nil, section.after.menuBitmaps != nil,
              state.arithmeticPrecision == .bits53, n.drawResults == [0,1],
              n.fpcw == 0x23f, n.fpswBefore == 0x4000, n.fpswAfter == n.fpswBefore,
              n.fptagBefore == 0xffff, n.fptagAfter == n.fptagBefore else { throw error("Own source/FPU boundary") }
        let p = n.input
        guard p.targetSurface == (try state.globals.integer(at: 0x455608-0x44d000, as: UInt32.self)),
              p.methodResult == 0, p.queryResult == 0, p.audioGetResult == 0, p.audioSetResult == 0,
              p.dcResult == 0, p.dc == 0x12345678, p.postResult == 0,
              try state.globals.integer(at: 0x44eecc-0x44d000, as: UInt32.self) != 0 else { throw error("Enabled own platform context") }
        guard n.entryObservations.count == 2, n.returnObservations.count == 4 else { throw error("Actual caller inventory") }
        let outer = n.entryObservations[0], inner = n.entryObservations[1]
        guard outer.pc == 0x4246b0, outer.sp == 0x1000f424, outer.returnPC == 0x30000000,
              outer.argument == p.targetSurface, outer.saved == [0x11223344,0x22334455,0x33445566,0x44556677], outer.seh == 0x12345678,
              inner.pc == 0x41bc90, inner.sp == 0x1000eff8, inner.returnPC == 0x424746,
              inner.argument == p.targetSurface, inner.saved == [outer.saved[0],outer.saved[1],0x22000020,p.targetSurface], inner.seh == 0x1000f418,
              n.returnObservations.map(\.pc) == [0x422a95,0x424746,0x4287de,0x30000000],
              n.returnObservations.map(\.sp) == [0x1000e9bc,0x1000f000,0x1000f000,0x1000f42c],
              n.returnObservations[1].saved == inner.saved, n.returnObservations[1].seh == inner.seh,
              n.returnObservations[2].saved == inner.saved, n.returnObservations[2].seh == inner.seh,
              n.returnObservations[3].saved == outer.saved, n.returnObservations[3].seh == outer.seh else { throw error("Actual saved-frame restoration") }
        var buffers = Set<UInt32>()
        for (count,base) in [(400,0x452948),(80,0x451db0),(5,0x45560c)] {
            for index in 0..<count {
                let token = try state.globals.integer(at: base+index*4-0x44d000, as: UInt32.self)
                if token != 0 { buffers.insert(token) }
            }
        }
        guard buffers.sorted() == n.loadedSoundBuffers else { throw error("Own loaded sound buffers") }
        let methods: [UInt32:Int] = [0x40:2,0x3c:2,0x48:1,0x34:2,0x30:4]
        guard !n.methodBindings.isEmpty else { throw error("Missing COM response bindings") }
        for b in n.methodBindings {
            guard methods[b.offset] == b.argumentCount, (0x33006000..<0x33006100).contains(b.after) else { throw error("COM adapter signature") }
        }
        var fonts = Set<UInt32>()
        for address in [0x44faf4,0x44f888,0x44fcbc] {
            let token = try state.globals.integer(at: address-0x44d000, as: UInt32.self)
            let (_,surface) = try resourceBitmap(token)
            guard surface == n.resourceSurfaces[String(token)] else { throw error("Own font surface") }
            fonts.insert(token)
        }
        guard Set(n.resourceSurfaces.keys) == Set(fonts.map(String.init)) else { throw error("Font resource inventory") }
        for h in section.helpers {
            guard h.returnSP == h.entrySP+4+h.pop, h.saved.count == 4 else { throw error("Helper return ABI") }
        }
        guard section.helpers.filter({ $0.entry == 0x4450b2 }).count == 3,
              n.events.filter({ $0.kind == "stage" }).map(\.arguments) == [[0x41b130],[0x4028a0],[0x43e940],[0x419e60]],
              n.writes.last?.pc == 0x424746, n.writes.last?.address == 0x457580, n.writes.last?.value == 0 else { throw error("Output/return order") }
        for read in section.readsBeforeWrites {
            guard read.kind == "bitmap", read.size == 4, (0..<0x1f50).contains(read.offset),
                  (0x43f010...0x43f2fe).contains(read.pc),
                  n.events.contains(where: { $0.read?.offset == read.offset && $0.read?.defined == false }) else { throw error("Undefined output read") }
        }
        // The last observer fails after all graphics/audio requests and the
        // outer flag clear, proving that the public composition still rolls back.
        var trial = state, trialMemory = context.memory, rejected = false, trialEvents = 0
        do {
            try OriginalGameplayOutput.returnFromDispatcher(world: &trial.world, globals: &trial.globals,
                memory: &trialMemory, input: p, resourceBitmap: resourceBitmap, performBlit: { _ in 0 }, soundRequest: { _ in 0 }) { event in
                    trialEvents += 1
                    if event.kind == "dispatcherWrite" { throw error("Late dispatcher observer") }
                }
        } catch OriginalStateError.invalidStorage(let message) where message == "Gameplay return reference: Late dispatcher observer" { rejected = true }
        guard rejected, trialEvents == n.events.count, trial.world == state.world, trial.globals == state.globals,
              trialMemory.replayPointers == context.memory.replayPointers, trialMemory.allocations == context.memory.allocations else { throw error("Whole output rollback") }
        var seen = 0, blits = 0
        try OriginalGameplayOutput.returnFromDispatcher(world: &state.world, globals: &state.globals, memory: &context.memory,
            input: p, resourceBitmap: resourceBitmap, performBlit: { _ in
                defer { blits += 1 }; return n.drawResults[blits%n.drawResults.count]
            }, soundRequest: { _ in 0 }, observe: { event in
                guard seen < n.events.count, event == n.events[seen] else {
                    throw error("Event \(seen): \(event); expected \(seen < n.events.count ? String(describing: n.events[seen]) : "end")")
                }
                seen += 1
            })
        guard seen == n.events.count, blits == n.events.filter({ $0.kind == "blit" }).count else { throw error("Missing output requests") }
        return .init(helpers: section.helpers.count, events: seen)
    }
}
