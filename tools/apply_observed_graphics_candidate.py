"""Connect the whole menu graphics request order on a task-owned Native clone."""
import difflib

def apply(root,candidate):
    changes={}
    def edit(name,replacements=(),source=None):
        path=candidate/name;before=path.read_text() if path.exists() else ''
        after=(root/source).read_text() if source else before
        for a,b in replacements:
            assert after.count(a)==1,(name,a,after.count(a));after=after.replace(a,b)
        assert after!=before,name;path.write_text(after);changes[name]=dict(before=before,after=after)
    core='native/Sources/NTSDCore/'
    edit(core+'OriginalMenuGraphicsRequestExchange.swift',source='tools/OriginalMenuGraphicsRequestExchange.swift')
    edit(core+'OriginalApplicationObservedGraphicsIteration.swift',source='tools/OriginalApplicationObservedGraphicsIteration.swift')
    edit(core+'OriginalApplicationPreparedStartupPlatform.swift',[
        ('OriginalApplicationObservedLifecyclePlatform {','OriginalApplicationObservedLifecyclePlatform, OriginalApplicationObservedGraphicsPlatform {'),
        ('    public var lifecycleDelivery = OriginalLifecycleDelivery()','    public var lifecycleDelivery = OriginalLifecycleDelivery()\n    public var graphicsDelivery = OriginalMenuGraphicsDelivery()'),
        ('copy.lifecycleDelivery = lifecycleDelivery','copy.lifecycleDelivery = lifecycleDelivery; copy.graphicsDelivery = graphicsDelivery')])
    edit(core+'OriginalApplicationHostSession.swift',[
        ('        beforePublication: (Platform) throws -> Void = { _ in },\n        expectedSequence:',
         '''        surface: ((OriginalWindowInitialization.Request, Platform) throws -> OriginalWindowInitialization.Response)? = nil,
        front: ((Application.Stage, OriginalFrontScreenEvent, Platform) throws -> OriginalLibSurfaceText.Response)? = nil,
        beforePublication: (Platform) throws -> Void = { _ in },
        expectedSequence:'''),
        ('lifecycleProvider: lifecycle.map { callback in { q in try callback(q,candidate) } })',
         '''lifecycleProvider: lifecycle.map { callback in { q in try callback(q,candidate) } },
                surfaceProvider: surface.map { callback in { q in try callback(q,candidate) } },
                frontProvider: front.map { callback in { stage,q in try callback(stage,q,candidate) } })''')])
    edit(core+'OriginalApplicationBootstrap.swift',[
        ('        lifecycleProvider: ((OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response)? = nil) throws -> Session.Outcome {',
         '''        lifecycleProvider: ((OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response)? = nil,
        surfaceProvider: ((OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response)? = nil,
        frontProvider: ((Stage,OriginalFrontScreenEvent) throws -> OriginalLibSurfaceText.Response)? = nil) throws -> Session.Outcome {'''),
        ('        var qi = 0,wi = 0,si = 0,li = 0',
         '        if surfaceProvider != nil && !surface.isEmpty { throw Session.Boundary.dependency("Observed surface requests cannot mix prepared response arrays") }\n        var qi = 0,wi = 0,si = 0,li = 0'),
        ('            let r = try take(surface,&si,"surface");try observe(.surfaceResponse(q,r));return r',
         '            let r = try surfaceProvider?(q) ?? take(surface,&si,"surface");try observe(.surfaceResponse(q,r));return r'),
        ('},initialization:inputs,initializationBitmap:bitmap,bootstrapObserve:observe,lifecycle:',
         '},initialization:inputs,initializationBitmap:bitmap,frontProvider:frontProvider,bootstrapObserve:observe,lifecycle:')])
    edit(core+'OriginalApplicationGraphics.swift',[
        ('        case let .getDC(e,r,output):return try front(e,result:r,output:output,inputs:inputs)',
         '''        case let .getDC(e,r,output):return try front(e,result:r,output:output,inputs:inputs)
        case let .frontAPI(e,r):return try front(e,result:r.result,output:r.output,inputs:inputs)''')])
    edit(core+'OriginalApplicationMenuSession.swift',[
        ('        case graphics(OriginalFrontScreenEvent,result: Int32)',
         '        case graphics(OriginalFrontScreenEvent,result: Int32)\n        case frontAPI(OriginalFrontScreenEvent,OriginalLibSurfaceText.Response)'),
        ('        bootstrapObserve: @escaping (OriginalApplicationBootstrap.Observation)',
         '        frontProvider: ((OriginalApplicationBootstrap.Stage,OriginalFrontScreenEvent) throws -> OriginalLibSurfaceText.Response)? = nil,\n        bootstrapObserve: @escaping (OriginalApplicationBootstrap.Observation)'),
        ('        var stage: OriginalApplicationBootstrap.Stage = .menu',
         '        var stage: OriginalApplicationBootstrap.Stage = .menu\n        var lastBltResult: Int32 = 0, lastPresentationResult: Int32?'),
        ('                try emit(.blit(b,result:drawResult))',
         '''                if let reply = try frontProvider?(stage,e) {
                    lastBltResult = reply.result;try emit(.frontAPI(e,reply))
                } else { lastBltResult = drawResult;try emit(.blit(b,result:drawResult)) }'''),
        ('                try emit(.fill(f,result:stage == .prefix ? initialization?.prefix.fillResult ?? responses.draw : responses.draw))',
         '''                if let reply = try frontProvider?(stage,e) { try emit(.frontAPI(e,reply)) }
                else { try emit(.fill(f,result:stage == .prefix ? initialization?.prefix.fillResult ?? responses.draw : responses.draw)) }'''),
        ('''                if e.arguments[1] == 8 {
                    if var bindings = bitmapInputs {''',
         '''                if e.arguments[1] == 8 {
                    let reply = try frontProvider?(stage,e),value = reply?.result ?? responses.release
                    if var bindings = bitmapInputs {'''),
        ('control:.init(result:responses.release))','control:.init(result:value))'),
        ('                    try emit(.release(e,ignoredResult:responses.release))',
         '                    if let reply { try emit(.frontAPI(e,reply)) }\n                    else { try emit(.release(e,ignoredResult:value)) }'),
        ('                else if e.arguments[1] == 0x14 || e.arguments[1] == 0x2c { try emit(.present(e,result:responses.presentation)) }',
         '''                else if e.arguments[1] == 0x14 || e.arguments[1] == 0x2c {
                    if let reply = try frontProvider?(stage,e) {
                        lastPresentationResult = reply.result;try emit(.frontAPI(e,reply))
                    } else { lastPresentationResult = responses.presentation;try emit(.present(e,result:responses.presentation)) }
                }'''),
        ('            case "getDC": try emit(.getDC(e,result:stage == .body ? initialization?.body.dcResult ?? responses.dcResult : responses.dcResult,output:stage == .body ? initialization?.body.dc ?? responses.dc : responses.dc))',
         '''            case "getDC":
                // The installed body response callback already emitted its
                // terminal effect. Keep this original event as observation.
                if frontProvider == nil || stage != .body {
                    try emit(.getDC(e,result:stage == .body ? initialization?.body.dcResult ?? responses.dcResult : responses.dcResult,output:stage == .body ? initialization?.body.dc ?? responses.dc : responses.dc))
                }'''),
        ('''                if let input = initialization,stage == .body { try emit(.startupGraphics(e,result:input.body.methodResult)) }
                else { try emit(.graphics(e,result:responses.draw)) }''',
         '''                if frontProvider == nil || stage != .body {
                    if let input = initialization,stage == .body { try emit(.startupGraphics(e,result:input.body.methodResult)) }
                    else { try emit(.graphics(e,result:responses.draw)) }
                }'''),
        ('try event(e);return drawResult })','try event(e);return lastBltResult })'),
        ('drawResults:[responses.draw],shellResult:0),draw:draw,observe:event)',
         '''drawResults:[responses.draw],shellResult:0),draw:draw,
                            textPerform:frontProvider.map { provider in { q in
                                try provider(stage,.init(q.kind.rawValue,q.arguments,q.strings))
                            } },textDidRespond:{ q,r in
                                try emit(.frontAPI(.init(q.kind.rawValue,q.arguments,q.strings),r))
                            },observe:event)'''),
        ('try point(.worldReturn,owned.full,initialization == nil ? nil : responses.presentation)',
         'try point(.worldReturn,owned.full,initialization == nil ? nil : lastPresentationResult ?? responses.presentation)')])
    edit('native/Sources/NTSDMacPlatform/OriginalMacBitmapService.swift',[
        ('        try serve(permit,begin:{ try exchange.beginService(permit) },',
         '        try serve(permit.request.value,begin:{ try exchange.beginService(permit) },'),
        ('        try serve(permit,begin:{ try driver.beginService(permit) },',
         '        try serve(permit.request.value,begin:{ try driver.beginService(permit) },'),
        ('    private func serve(_ permit: Exchange.Permit,begin: () throws -> Void,',
         '''    public func serve<P>(_ permit: OriginalMenuGraphicsRequestExchange.Permit,
        on driver: OriginalApplicationObservedGraphicsIteration<P>) throws {
        guard case .bitmap(_,let q) = permit.request else {
            throw OriginalMacDisplayBackend.Boundary.unsupported("menu graphics bitmap family")
        }
        try serve(q,begin:{ try driver.beginService(permit) },
            answer:{ try driver.answer(permit,response:.bitmap($0),retaining:$1) },
            fail:{ try driver.fail(permit,diagnostic:$0,retaining:$1) })
    }
    private func serve(_ q: OriginalBitmapSurfaceLoading.Request,begin: () throws -> Void,'''),
        ('        let q = permit.request.value\n','')])
    edit('native/Tests/NTSDCoreTests/OriginalApplicationObservedGraphicsTests.swift',source='tools/OriginalApplicationObservedGraphicsTests.swift')
    return changes

def patch(changes):
    return ''.join(''.join(difflib.unified_diff(v['before'].splitlines(True),v['after'].splitlines(True),
        fromfile='a/'+name if v['before'] else '/dev/null',tofile='b/'+name)) for name,v in changes.items())
