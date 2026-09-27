"""Produce separately identified audio comparisons from pinned retained methods."""
from pathlib import Path
from apply_startup_audio_candidate import once
BASE=Path('build/research/application-mac-front-raster-correction2-20260927/candidate1/native/Tests/NTSDCoreTests')
OUT=Path('tools')
def method(s,name,next_name):
 return s[s.index('    func '+name+'('):s.index('    func '+next_name+'(')]
def main():
 old=(BASE/'OriginalMenuSoundStartupTests.swift').read_text()
 menu=old[:old.index('    func testMissingDeviceAndLateObserverRollback')]+ '}\n'
 menu=once(menu,'final class OriginalMenuSoundStartupTests','final class OriginalStartupAudioMenuCorpus')
 menu=once(menu,'func testWholeMenuSoundStartupAgainstOriginal','func compareWholeMenuSoundStartupAgainstOriginal')
 menu=once(menu,'            var caught = false','            var caught = false\n            var replies: [Int:OriginalWaveLegacyReplies] = [:]')
 menu=once(menu,'OriginalMenuSoundStartup.load(globals: &globals, platform: item.spec.device, wavePlatform:',
  'OriginalMenuSoundStartup.loadObserved(globals: &globals, soundRequest:{ try OriginalSoundLegacyReplies.reply(item.spec.device,$0) }, waveInput:')
 menu=once(menu,'                    return l.input\n                }, fileSource:',
 '''                    let r = try OriginalWaveLegacyReplies(l.input);replies[index] = r;return r.input
                }, waveRequest:{ binding,q in try XCTUnwrap(replies[binding.index]).reply(q) }, fileSource:''')
 menu=once(menu,'                let native = try OriginalWaveLoader.load(path: failed.path, file: blob(failed.file), output: failed.outputBefore, platform: failed.input)',
 '''                let replies = try OriginalWaveLegacyReplies(failed.input)
                let native = try OriginalWaveLoader.loadObserved(path:failed.path,file:blob(failed.file),output:failed.outputBefore,input:replies.input,request:replies.reply)''')
 (OUT/'OriginalStartupAudioMenuCorpus.swift').write_text(menu)
 old=(BASE/'OriginalApplicationObservedStartupTests.swift').read_text()
 whole=method(old,'testWholeWinMainWithObservedRequests','testLateFailuresRetriesAndOwners')
 whole=once(whole,'func testWholeWinMainWithObservedRequests','func testWholeWinMainAudioRequestsMatchSourceAndPreparedState')
 whole=once(whole,'try D().encoded(value.operations)','try D().encoded(service.project(value.operations))')
 whole=once(whole,'                XCTAssertEqual(value.graphics,expected.graphics)','''                XCTAssertEqual(value.graphics,expected.graphics)
                try service.verify(driver.exchangeSnapshot,value.operations,try XCTUnwrap(host.snapshot.startup))''')
 whole=once(whole,'            XCTAssertEqual(service.calls,driver.exchangeSnapshot.receipts.count)','''            XCTAssertEqual(service.calls,driver.exchangeSnapshot.receipts.count)
            try service.verifyReceipts(driver.exchangeSnapshot)''')
 late=method(old,'testLateFailuresRetriesAndOwners','testTypedRequestsAndProtocolBoundaries')
 late=once(late,'func testLateFailuresRetriesAndOwners','func testLateStartupAudioFailuresDoNotRepeatServedCopies')
 late=once(late,'["window-return","panel-return","secondDate","output-return","fifthWave","after","publication-copy"]','["fifthWave","publication-copy"]')
 late=once(late,'            let calls = service.calls','''            let calls = service.calls,copyWrites = service.owner.copyWrites
            XCTAssertGreaterThan(copyWrites,0)''')
 late=once(late,'            XCTAssertEqual(try host.takeCommitted()?.sequence,1); XCTAssertNil(try host.takeCommitted())','''            let batch = try XCTUnwrap(host.takeCommitted())
            XCTAssertEqual(batch.sequence,1); XCTAssertNil(try host.takeCommitted())
            guard case .startup(let value) = batch.contents else { throw Stop.missingOutcome }
            try service.verify(driver.exchangeSnapshot,value.operations,try XCTUnwrap(host.snapshot.startup))
            XCTAssertEqual(service.owner.copyWrites,copyWrites)
            var reference = OriginalApplicationBootstrap(),referencePlatform = try p.stagedCopy()
            let expected = try reference.start(instance:0x400000,show:10,initial:initial,platform:&referencePlatform,
                store:{ $0.store($1,$2) },beforeCommit:{ owner,session,candidate in
                    try candidate.complete(owner,self.globals(session))
                })
            try B.sameStartup(XCTUnwrap(host.snapshot.startup),XCTUnwrap(reference.startup))
            B.same(try XCTUnwrap(host.snapshot.session),try XCTUnwrap(reference.session))
            XCTAssertEqual(try D().encoded(service.project(value.operations)),try D().encoded(expected.operations))
            XCTAssertEqual(value.graphics,expected.graphics)''')
 service=old[old.index('        func answer(_ q:'):old.index('    func globals(')]
 service=once(service,'            case .wave(let w):return .wave(try values.wave(w.index,w.path,w.destination,w.device))','''            case .wave:throw Stop.missingOutcome
            case .sound(let q):
                let r = try OriginalSoundLegacyReplies.reply(full.sound,q)
                audio.append(.soundReply(q,r));return .sound(r)
            case .waveAudio(let binding,let q):
                try q.validate()
                let input = try wave(binding),reply = try XCTUnwrap(waves[binding.index]).reply(q)
                XCTAssertEqual(input.destination,binding.destination);XCTAssertEqual(input.device,binding.device)
                if case .locked(_,let lock?) = reply {
                    for region in [lock.first,lock.second].compactMap({ $0 }) {
                        owner.regions[binding.index,default:[:]][region.token] = try region.storage.record()
                    }
                }
                if q.event.kind == .copy {
                    let token = try XCTUnwrap(q.target),bytes = try XCTUnwrap(q.bytes),mask = try XCTUnwrap(q.defined)
                    let prior = try XCTUnwrap(owner.regions[binding.index]?[token])
                    guard bytes.count <= prior.bytes.count else { throw Stop.missingOutcome }
                    var raw = prior.bytes,known = prior.defined
                    raw.replaceSubrange(0..<bytes.count,with:bytes);known.replaceSubrange(0..<mask.count,with:mask)
                    owner.regions[binding.index,default:[:]][token] = try .init(bytes:raw,defined:known)
                    owner.copyWrites += 1
                }
                audio.append(.waveReply(binding,q,reply));return .waveAudio(reply)''')
 # The copied switch remains unchanged for every old non-audio request.
 head=(OUT/'OriginalStartupAudioTestHelpers.part').read_text()
 controls=(OUT/'OriginalStartupAudioTestControls.part').read_text()
 text=head.replace('/* SERVICE_ANSWER */',service)+whole+late+controls+'}\n'
 (OUT/'OriginalStartupAudioTests.swift').write_text(text)
 print('Generated two new test sources; old source methods unmodified.')
if __name__=='__main__':main()
