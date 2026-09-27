"""One test assertion correction plus a bounded read-only monitor observation."""
from pathlib import Path
from apply_startup_audio_candidate import once

def apply(candidate):
 path='native/Tests/NTSDCoreTests/OriginalStartupAudioTests.swift';f=candidate/path;s=f.read_text()
 a='''        XCTAssertThrowsError(try run(conflict)) { XCTAssertEqual($0 as? OriginalStateError,.invalidStorage("Wave loading: Conflicting Lock alias backing")) }'''
 b='''        XCTAssertThrowsError(try run(conflict)) {
            guard case OriginalStateError.invalidStorage(let text) = $0 else { return XCTFail("Wrong alias boundary: \\($0)") }
            XCTAssertEqual(text,"Wave loading: Conflicting Lock alias backing")
        }'''
 n=once(s,a,b);f.write_text(n);return {path:dict(before=s,after=n)}

def monitor(s):
 anchor='def main(config_path,config_sha):'
 helper='''def deferred_compiler_cwd(before,current,observed_cwd):
    """A read observation only; never an identity/cwd grant for an action."""
    fields=current.split(None,6)
    if observed_cwd!='' or current!=before or len(fields)!=7:return False
    executable=Path(fields[6].split(' ',1)[0])
    return str(executable).startswith('/Applications/Xcode.app/Contents/') and executable.name in {
        'swift-build','swiftc','swift-driver','swift-frontend','clang','ld','dsymutil','sandbox-exec'}


'''
 s=once(s,anchor,helper+anchor)
 anchor='''                        assert owned_cwd(where_now,pid,P),where_now'''
 new='''                        if a[0] in known and deferred_compiler_cwd(known[a[0]]['identity'],current,where_now):
                            observations=j.setdefault('deferredEmptyCwdObservations',[])
                            count=sum(row['pid']==pid for row in observations)
                            observations.append(dict(pid=pid,identity=current,cwd=where_now,ordinal=count+1,UTC=now(),lastValidated=known[a[0]]))
                            save()
                            assert count<3, 'repeated unavailable compiler cwd'
                            # Charge RSS and retain the last validated pair. A guard
                            # action still performs its original fresh pair checks.
                            live.append(a)
                            continue
'''+anchor
 return once(s,anchor,new)
