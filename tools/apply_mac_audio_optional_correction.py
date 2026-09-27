"""Require the two optional values diagnosed by the frozen first build."""
from pathlib import Path
def apply(root):
    name='native/Tests/NTSDCoreTests/OriginalMacAudioBackendTests.swift'
    p=Path(root)/name;before=p.read_text();after=before
    for old,new in [
        ('XCTAssertEqual(r.initialStorage.first.bytes,[])','XCTAssertEqual(try XCTUnwrap(r.initialStorage).first.bytes,[])'),
        ('file($0.request.path,package.file($0.request.path))','file($0.request.path,XCTUnwrap(package.file($0.request.path)))')]:
        assert after.count(old)==1,old;after=after.replace(old,new)
    p.write_text(after)
    return {name:dict(before=before,after=after)}
