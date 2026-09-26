"""Append native front operations to the existing owner; retain Core and old tests."""
import difflib

def apply(root,candidate):
    changes={}
    def write(name,after):
        p=candidate/name;before=p.read_text() if p.exists() else ''
        assert before!=after;p.write_text(after);changes[name]=dict(before=before,after=after)
    name='native/Sources/NTSDMacPlatform/OriginalMacDisplayBackend.swift'
    old=(candidate/name).read_text();anchor='    public private(set) var bitmapOperations: [BitmapOperation] = []'
    assert old.count(anchor)==1
    new=old.replace(anchor,anchor+'\n    public private(set) var frontOperations: [FrontOperation] = []')+'\n'+(root/'tools/OriginalMacFrontRaster.swift').read_text()
    write(name,new)
    for name,template in [
        ('native/Sources/NTSDMacPlatform/OriginalMacFrontService.swift','OriginalMacFrontService.swift'),
        ('native/Tests/NTSDCoreTests/OriginalMacFrontRasterTests.swift','OriginalMacFrontRasterTests.swift')]:
        write(name,(root/'tools'/template).read_text())
    return changes

def patch(changes):
    return ''.join(''.join(difflib.unified_diff(v['before'].splitlines(True),v['after'].splitlines(True),
        fromfile='a/'+name if v['before'] else '/dev/null',tofile='b/'+name)) for name,v in changes.items())
