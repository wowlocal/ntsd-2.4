"""Apply the finite observed-bitmap bridge to an already pinned task-owned clone."""
import difflib,shutil
from pathlib import Path

def apply(root,candidate):
    changes={}
    def edit(name,replacements=(),append=None,source=None):
        path=candidate/name;before=path.read_text() if path.exists() else ''
        after=(root/source).read_text() if source else before
        for a,b in replacements:
            assert after.count(a)==1,(name,a,after.count(a));after=after.replace(a,b)
        if append:after+=(root/append).read_text()
        assert after!=before,name;path.write_text(after)
        changes[name]=dict(before=before,after=after)
    core='native/Sources/NTSDCore/'
    edit(core+'OriginalBitmapRequestExchange.swift',source='tools/OriginalBitmapRequestExchange.swift')
    edit(core+'OriginalApplicationObservedBitmapIteration.swift',source='tools/OriginalApplicationObservedBitmapIteration.swift')
    edit(core+'OriginalApplicationBitmapInputs.swift',append='tools/OriginalBitmapObservedResponse.swift.inc')
    edit(core+'OriginalApplicationPreparedStartupPlatform.swift',[
        ('OriginalApplicationWindowStartupPlatform, OriginalApplicationObservedStartupPlatform {','OriginalApplicationWindowStartupPlatform, OriginalApplicationObservedStartupPlatform, OriginalApplicationObservedBitmapPlatform {'),
        ('    public var startupExchange: OriginalStartupRequestExchange.Cursor?','    public var startupExchange: OriginalStartupRequestExchange.Cursor?\n    public var bitmapDelivery = OriginalBitmapDelivery()'),
        ('copy.startupExchange = startupExchange','copy.startupExchange = startupExchange; copy.bitmapDelivery = bitmapDelivery')])
    edit(core+'OriginalApplicationHostSession.swift',[
        ('case reentrantAttempt, sharedPlatform, pendingLoading, publicationExtent','case reentrantAttempt, sharedPlatform, pendingLoading, publicationExtent, staleSequence'),
        ('    public var snapshot: Application { locked { application } }','    public var snapshot: Application { locked { application } }\n    public var committedSequence: UInt64 { locked { sequence } }'),
        ('        beforeCommit: (Session.Loop, Session.State) throws -> Void = { _,_ in }) throws -> Outcome {',
         '''        beforeCommit: (Session.Loop, Session.State) throws -> Void = { _,_ in },
        bitmap: ((Application.Stage, OriginalBitmapSurfaceLoading.Request, Platform) throws -> OriginalBitmapSurfaceLoading.Response)? = nil,
        beforePublication: (Platform) throws -> Void = { _ in },
        expectedSequence: UInt64? = nil) throws -> Outcome {'''),
        ('            guard let session = application.session else { throw Application.Boundary.notStarted }',
         '''            guard expectedSequence == nil || expectedSequence == sequence else { throw Boundary.staleSequence }
            guard let session = application.session else { throw Application.Boundary.notStarted }'''),
        ('                beforeCommit: beforeCommit)\n            switch result {',
         '''                beforeCommit: beforeCommit,
                bitmap: bitmap.map { callback in { stage,q in try callback(stage,q,candidate) } })
            switch result {'''),
        ('                let context = try DeliveryContext(application: next, platform: candidate)\n                application = next; platform = candidate',
         '''                let context = try DeliveryContext(application: next, platform: candidate)
                // Final validation only: no IO or mutation of candidate in this hook.
                try beforePublication(candidate)
                application = next; platform = candidate'''),
        ('            case .loading(let loading):\n                pending =',
         '''            case .loading(let loading):
                try beforePublication(candidate)
                pending =''')])
    edit(core+'OriginalApplicationBootstrap.swift',[
        ('        beforeCommit: (Session.Loop,Session.State) throws -> Void = { _,_ in }) throws -> Session.Outcome {',
         '''        beforeCommit: (Session.Loop,Session.State) throws -> Void = { _,_ in },
        bitmap: ((Stage,OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response)? = nil) throws -> Session.Outcome {'''),
        ('        },initialization:inputs,bootstrapObserve:observe,lifecycle:{ q in',
         '        },initialization:inputs,initializationBitmap:bitmap,bootstrapObserve:observe,lifecycle:{ q in')])
    edit(core+'OriginalApplicationMenuSession.swift',[
        ('        initialization: OriginalApplicationBootstrap.MenuInputs? = nil,',
         '''        initialization: OriginalApplicationBootstrap.MenuInputs? = nil,
        initializationBitmap: ((OriginalApplicationBootstrap.Stage,OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response)? = nil,'''),
        ('        try state.validateAliases()\n        guard revision',
         '''        try state.validateAliases()
        if initializationBitmap != nil,let input = initialization {
            guard input.frontResponses.isEmpty,input.backgroundResponses.isEmpty else {
                throw Boundary.dependency("Observed bitmap requests cannot mix prepared response arrays")
            }
        }
        guard revision'''),
        ('''                                let replies = at == .resources ? input.frontResponses : input.backgroundResponses
                                let index = at == .resources ? frontAPIIndex : backgroundAPIIndex
                                guard index < replies.count else { throw Boundary.dependency("Initial bitmap response") }
                                let control = replies[index]
                                let response: OriginalBitmapSurfaceLoading.Response
                                if var bindings = bitmapInputs {
                                    response = try bindings.response(q,control:control);bitmapInputs = bindings
                                } else { response = control }
                                if at == .resources { frontAPIIndex += 1 } else { backgroundAPIIndex += 1 }''',
         '''                                let response: OriginalBitmapSurfaceLoading.Response
                                if let provider = initializationBitmap {
                                    let actual = try provider(at,q)
                                    guard var bindings = bitmapInputs else { throw Boundary.dependency("Observed bitmap input provenance") }
                                    response = try bindings.observed(q,response:actual);bitmapInputs = bindings
                                } else {
                                    let replies = at == .resources ? input.frontResponses : input.backgroundResponses
                                    let index = at == .resources ? frontAPIIndex : backgroundAPIIndex
                                    guard index < replies.count else { throw Boundary.dependency("Initial bitmap response") }
                                    let control = replies[index]
                                    if var bindings = bitmapInputs {
                                        response = try bindings.response(q,control:control);bitmapInputs = bindings
                                    } else { response = control }
                                    if at == .resources { frontAPIIndex += 1 } else { backgroundAPIIndex += 1 }
                                }''')])
    edit('native/Sources/NTSDMacPlatform/OriginalMacBitmapService.swift',source='tools/OriginalMacObservedBitmapService.swift')
    edit('native/Tests/NTSDCoreTests/OriginalApplicationObservedBitmapTests.swift',source='tools/OriginalApplicationObservedBitmapTests.swift')
    return changes

def patch(changes):
    return ''.join(''.join(difflib.unified_diff(v['before'].splitlines(True),v['after'].splitlines(True),
        fromfile='a/'+name if v['before'] else '/dev/null',tofile='b/'+name)) for name,v in changes.items())
