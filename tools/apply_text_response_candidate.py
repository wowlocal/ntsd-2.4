"""Add per-request installed text replies to a bounded task-owned Native clone."""
import difflib

def apply(root,candidate):
    changes={}
    def edit(name,replacements=(),source=None):
        path=candidate/name;before=path.read_text() if path.exists() else ''
        after=(root/source).read_text() if source else before
        for a,b in replacements:
            assert after.count(a)==1,(name,a,after.count(a));after=after.replace(a,b)
        assert after!=before,name;path.write_text(after);changes[name]=dict(before=before,after=after)
    edit('native/Sources/NTSDCore/OriginalLibSurfaceText.swift',source='tools/OriginalLibSurfaceText.swift')
    name='native/Sources/NTSDCore/OriginalFrontScreenBody.swift'
    before=(candidate/name).read_text();after=before
    # Both installed-library public entries gain optional providers before their
    # existing final observer. Pristine advance still uses only prepared input.
    signature='        draw: ([UInt32]) throws -> Void,observe: (OriginalFrontScreenEvent) throws -> Void = { _ in })'
    assert after.count(signature)==2
    extra='''        draw: ([UInt32]) throws -> Void,
        textPerform: ((OriginalMenuPresentationEvent) throws -> OriginalLibSurfaceText.Response)? = nil,
        textDidRespond: (OriginalMenuPresentationEvent, OriginalLibSurfaceText.Response) throws -> Void = { _,_ in },
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in })'''
    after=after.replace(signature,extra)
    replacements=[
      ('input:input,draw:draw,observe:observe)','input:input,draw:draw,textPerform:textPerform,textDidRespond:textDidRespond,observe:observe)'),
      ('libraryText: &text,input: input,draw: draw,observe: observe)','libraryText: &text,input: input,draw: draw,textPerform: textPerform,textDidRespond: textDidRespond,observe: observe)'),
      ('        draw: ([UInt32]) throws -> Void,observe: (OriginalFrontScreenEvent) throws -> Void) throws -> Continuation {',
       '''        draw: ([UInt32]) throws -> Void,
        textPerform: ((OriginalMenuPresentationEvent) throws -> OriginalLibSurfaceText.Response)? = nil,
        textDidRespond: (OriginalMenuPresentationEvent, OriginalLibSurfaceText.Response) throws -> Void = { _,_ in },
        observe: (OriginalFrontScreenEvent) throws -> Void) throws -> Continuation {'''),
      ('''                try ownText!.draw(bytes,target: target,background: 0x602010,color: color,x: x,y: y,dcResult: input.dcResult,dc: input.dc) { e in
                    try emit(e.kind.rawValue,e.arguments,e.strings)
                }''',
       '''                if let textPerform {
                    try ownText!.draw(bytes,target: target,background: 0x602010,color: color,x: x,y: y,
                        perform: textPerform,didRespond: textDidRespond) { e in
                        try emit(e.kind.rawValue,e.arguments,e.strings)
                    }
                } else {
                    try ownText!.draw(bytes,target: target,background: 0x602010,color: color,x: x,y: y,dcResult: input.dcResult,dc: input.dc) { e in
                        try emit(e.kind.rawValue,e.arguments,e.strings)
                    }
                }''')]
    for a,b in replacements:
        assert after.count(a)==1,(a,after.count(a));after=after.replace(a,b)
    (candidate/name).write_text(after);changes[name]=dict(before=before,after=after)
    edit('native/Tests/NTSDCoreTests/OriginalApplicationTextResponseTests.swift',source='tools/OriginalApplicationTextResponseTests.swift')
    return changes

def patch(changes):
    return ''.join(''.join(difflib.unified_diff(v['before'].splitlines(True),v['after'].splitlines(True),
        fromfile='a/'+name if v['before'] else '/dev/null',tofile='b/'+name)) for name,v in changes.items())
