import Foundation
import NTSDCore

public enum MatchSelectionReference {
    public struct Result {
        public let parent: CharacterScreenReference.Result
        public let cases: Int,events: Int,helpers: Int,records: Int,bytes: Int,draws: Int,checkpoints: Int,returns: Int
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Match selection reference: "+text) }
    public static func compare(selection: Data,character: Data,cycle: Data,returning: Data,screen: Data,startup: Data,menu: Data,loading: Data,catalog: Data,sounds: Data,
                               requireComplete: Bool = true) throws -> Result {
        let c = try JSONDecoder().decode(CharacterScreenReference.Corpus.self,from: MatchPreparationReference.unpack(selection,maximumCount: 128_000_000))
        let initial = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from: MatchPreparationReference.unpack(startup,maximumCount: 128_000_000))
        let catalogSource = try JSONDecoder().decode(CharacterScreenReference.Catalog.self,from: MatchPreparationReference.unpack(catalog,maximumCount: 192_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              c.parent.sha256 == MatchPreparationReference.digest(character),c.worldAddress == 0x22000020,
              c.actorAddresses == initial.actorAddresses,c.objectAddresses == initial.objectAddresses,
              requireComplete ? c.cases.count == 50 : (1...50).contains(c.cases.count) else { throw error("Source/parent identity") }
        var portion: CharacterScreenReference.Portion?,callbacks = 0
        let parent = try CharacterScreenReference.compare(character: character,cycle: cycle,returning: returning,screen: screen,startup: startup,menu: menu,loading: loading,catalog: catalog,sounds: sounds) { own,context,crt,music,resources in
            callbacks += 1
            let result = try CharacterScreenReference.compareCases(actorAddresses: c.actorAddresses,objectAddresses: c.objectAddresses,worldAddress: c.worldAddress,initial: initial,catalogSource: catalogSource,
                cases: c.cases,blobs: c.blobs,state: own,context: context,crt: crt,music: music,resources: resources,matchSelection: true)
            if requireComplete {
                let state = result.state
                for (address,value) in [(0x44d020,1),(0x451160,0),(0x4512c8,3),(0x44d070,0),(0x44d06c,0),(0x44d024,0),(0x44d028,0)] {
                    guard try state.globals.integer(at: address-0x44d000,as: Int32.self) == Int32(value) else { throw error("Own Start state "+String(address,radix:16)) }
                }
                guard result.returns == 49,c.cases.last?.screen.continuation == .matchPrelude,
                      try state.world.integer(at: 0,as: Int32.self) == 2 else { throw error("Match-prelude boundary") }
            }
            portion = result
        }
        guard callbacks == 1,let p = portion else { throw error("Own character parent") }
        return .init(parent: parent,cases: p.cases,events: p.events,helpers: p.helpers,records: p.records,bytes: p.bytes,draws: p.draws,checkpoints: p.checkpoints,returns: p.returns)
    }
}
