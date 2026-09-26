"""Apply the bounded Native geometry/whole-WM_MOVE bridge to a task-owned clone."""
import difflib

def apply(root,candidate):
    changes={}
    def edit(name,replacements=(),append=None,source=None):
        path=candidate/name;before=path.read_text() if path.exists() else ''
        after=(root/source).read_text() if source else before
        for a,b in replacements:
            assert after.count(a)==1,(name,a,after.count(a));after=after.replace(a,b)
        if append:after+=(root/append).read_text()
        assert after!=before,name;path.write_text(after);changes[name]=dict(before=before,after=after)
    core='native/Sources/NTSDCore/'
    edit(core+'OriginalLifecycleRequestExchange.swift',source='tools/OriginalLifecycleRequestExchange.swift')
    edit(core+'OriginalApplicationObservedLifecycleIteration.swift',source='tools/OriginalApplicationObservedLifecycleIteration.swift')
    edit(core+'OriginalApplicationPreparedStartupPlatform.swift',[
        ('OriginalApplicationObservedBitmapPlatform {','OriginalApplicationObservedBitmapPlatform, OriginalApplicationObservedLifecyclePlatform {'),
        ('    public var bitmapDelivery = OriginalBitmapDelivery()','    public var bitmapDelivery = OriginalBitmapDelivery()\n    public var lifecycleDelivery = OriginalLifecycleDelivery()'),
        ('copy.bitmapDelivery = bitmapDelivery','copy.bitmapDelivery = bitmapDelivery; copy.lifecycleDelivery = lifecycleDelivery')])
    edit(core+'OriginalApplicationHostSession.swift',[
        ('        beforePublication: (Platform) throws -> Void = { _ in },\n        expectedSequence:',
         '        lifecycle: ((OriginalWindowInitialization.Request, Platform) throws -> OriginalWindowInitialization.Response)? = nil,\n        beforePublication: (Platform) throws -> Void = { _ in },\n        expectedSequence:'),
        ('bitmap: bitmap.map { callback in { stage,q in try callback(stage,q,candidate) } })',
         'bitmap: bitmap.map { callback in { stage,q in try callback(stage,q,candidate) } },\n                lifecycleProvider: lifecycle.map { callback in { q in try callback(q,candidate) } })')])
    edit(core+'OriginalApplicationBootstrap.swift',[
        ('        bitmap: ((Stage,OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response)? = nil) throws -> Session.Outcome {',
         '        bitmap: ((Stage,OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response)? = nil,\n        lifecycleProvider: ((OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response)? = nil) throws -> Session.Outcome {'),
        ('        var qi = 0,wi = 0,si = 0,li = 0',
         '        if lifecycleProvider != nil && !lifecycle.isEmpty { throw Session.Boundary.dependency("Observed lifecycle requests cannot mix prepared response arrays") }\n        var qi = 0,wi = 0,si = 0,li = 0'),
        ('            let r = try take(lifecycle,&li,"lifecycle");try observe(.lifecycleResponse(q,r));return r',
         '            let r = try lifecycleProvider?(q) ?? take(lifecycle,&li,"lifecycle");try observe(.lifecycleResponse(q,r));return r')])
    edit(core+'OriginalApplicationMenuSession.swift',[
        ('                        if input.message == 5 {','                        if input.message == 3 || input.message == 5 {'),
        ('        func store(_ address: Int,_ bytes: [UInt8]) throws {\n            guard [1,2,4].contains(bytes.count)',
         '        func store(_ address: Int,_ bytes: [UInt8]) throws {\n            if [8,16].contains(bytes.count) {\n                // API rectangle writes are retained whole in lifecycle replies.\n                // Project their words into the existing scalar observation format.\n                for i in stride(from:0,to:bytes.count,by:4) { try store(address+i,Array(bytes[i..<i+4])) }\n                return\n            }\n            guard [1,2,4].contains(bytes.count)')])
    edit('native/Sources/NTSDMacPlatform/OriginalMacWindowBackend.swift',[
        ('"showWindow","destroyWindow"].contains(request.kind)','"showWindow","destroyWindow","clientRect","screenPoint"].contains(request.kind)'),
        ('if q.kind != "registerClass" { try require(q.bytes == nil && q.defined == nil) }',
         'if !["registerClass","clientRect","screenPoint"].contains(q.kind) { try require(q.bytes == nil && q.defined == nil) }'),
        ('        case "metric": try require(q.words.count == 1 && [7,8,4].contains(q.words[0]))',
         '        case "clientRect","screenPoint": try validateGeometry(q)\n        case "metric": try require(q.words.count == 1 && [7,8,4].contains(q.words[0]))'),
        ('        case "metric": result = .init(result:try metric(q.words[0]))',
         '        case "clientRect","screenPoint":\n            let owner = try lease(q.words[0]);resources = [owner];result = try performGeometry(q)\n        case "metric": result = .init(result:try metric(q.words[0]))')],append='tools/OriginalMacWindowGeometry.swift.inc')
    edit('native/Sources/NTSDMacPlatform/OriginalMacWindowGeometryService.swift',source='tools/OriginalMacWindowGeometryService.swift')
    edit('native/Tests/NTSDCoreTests/OriginalMacWindowGeometryTests.swift',source='tools/OriginalMacWindowGeometryTests.swift')
    return changes

def patch(changes):
    return ''.join(''.join(difflib.unified_diff(v['before'].splitlines(True),v['after'].splitlines(True),
        fromfile='a/'+name if v['before'] else '/dev/null',tofile='b/'+name)) for name,v in changes.items())
