"""Finite Native diagnostic-consumer correction; never edits reference expectations."""
from pathlib import Path

def once(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)

def apply(candidate):
    changes={}
    name='native/Sources/NTSDMacPlatform/OriginalMacFrontService.swift'
    p=candidate/name;before=p.read_text();s=before
    s=once(s,'    public let backend: OriginalMacDisplayBackend\n    public init(backend: OriginalMacDisplayBackend) { self.backend = backend }', '''    public typealias Diagnostic = (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response
    public let backend: OriginalMacDisplayBackend
    private let diagnostic: Diagnostic?
    public init(backend: OriginalMacDisplayBackend,diagnostic: Diagnostic? = nil) {
        self.backend = backend;self.diagnostic = diagnostic
    }''')
    s=once(s,'        case front(OriginalMacDisplayBackend.FrontPrepared)','''        case front(OriginalMacDisplayBackend.FrontPrepared)
        case diagnostic(OriginalWindowInitialization.Request,Diagnostic)''')
    s=once(s,'            if OriginalMacDisplayBackend.handles(q)', '''            if q.kind == "debug" {
                guard let diagnostic else { throw OriginalMacDisplayBackend.Boundary.unsupported("window debug consumer") }
                guard q.words.isEmpty,q.bytes == nil,q.defined == nil,q.strings.count == 1 else {
                    throw OriginalMacDisplayBackend.Boundary.arguments("window debug")
                }
                prepared = .diagnostic(q,diagnostic)
            } else if OriginalMacDisplayBackend.handles(q)''')
    s=once(s,'            case .front(let q):let r = try backend.performFront(q);try answer(.front(r.response),r.resources)', '''            case .front(let q):let r = try backend.performFront(q);try answer(.front(r.response),r.resources)
            case .diagnostic(let q,let consume):
                let response = try consume(q)
                try answer(.window(response),backend.retainedResources+backend.windows.retainedResources)''')
    p.write_text(s);changes[name]=dict(before=before,after=s)
    name='native/Tests/NTSDCoreTests/OriginalMacFrontRasterTests.swift'
    p=candidate/name;before=p.read_text();s=before
    s=once(s,'        let driver = G.Driver(host:host),bitmap = G.O().service(r,ready.package),service = Service(backend:r.setup.display)', '''        var windowIndex = 0,diagnostics: [[UInt8]] = []
        let driver = G.Driver(host:host),bitmap = G.O().service(r,ready.package)
        let service = Service(backend:r.setup.display,diagnostic:{ q in
            guard packet.surface.indices.contains(windowIndex) else { throw Stop.limit }
            diagnostics.append(q.strings[0])
            // Saved declared API input response, not an expected after-state.
            return packet.surface[windowIndex]
        })''')
    s=once(s,'                    case .window:try service.serve(permit,on:driver)','                    case .window:try service.serve(permit,on:driver);windowIndex += 1')
    s=once(s,'                    checkpoints = points','''                    checkpoints = points
                    XCTAssertEqual(windowIndex,packet.surface.count)
                    XCTAssertEqual(diagnostics,[Array("LoadGameArt: Art loaded.\\n".utf8)])''')
    anchor='        let release = E(),ticket = try G().ticket(release,.front(.menu,.init("method",[back,8])))'
    s=once(s,anchor,'''        // Controlled diagnostic inputs exercise the same retained service boundary.
        let debug = OriginalWindowInitialization.Request("debug",strings:[[0xff,0,0x41]])
        let missing = E(),missingTicket = try G().ticket(missing,.window(debug))
        XCTAssertThrowsError(try service.serve(missingTicket,on:missing)) { XCTAssertEqual($0 as? B.Boundary,.unsupported("window debug consumer")) }
        XCTAssertFalse(missing.snapshot.serviceStarted);XCTAssertTrue(missing.snapshot.receipts.isEmpty)
        var diagnostics: [OriginalWindowInitialization.Request] = []
        let reply = OriginalWindowInitialization.Response(result:-23,output:0xa7,bytes:[0xff,0,0x12])
        let diagnosticService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);return reply })
        let structure = try OriginalStateRecord(bytes:[0],defined:[true])
        for malformed in [OriginalWindowInitialization.Request("debug"),.init("debug",[1],strings:[[1]]),
            .init("debug",strings:[[1],[2]]),.init("debug",strings:[[1]],structure:structure)] {
            let exchange = E(),permit = try G().ticket(exchange,.window(malformed))
            XCTAssertThrowsError(try diagnosticService.serve(permit,on:exchange)) { XCTAssertEqual($0 as? B.Boundary,.arguments("window debug")) }
            XCTAssertFalse(exchange.snapshot.serviceStarted);XCTAssertTrue(exchange.snapshot.receipts.isEmpty)
        }
        let diagnosticExchange = E(),foreignExchange = E()
        let diagnosticPermit = try G().ticket(diagnosticExchange,.window(debug)),foreignPermit = try G().ticket(foreignExchange,.window(debug))
        XCTAssertThrowsError(try diagnosticService.serve(foreignPermit,on:diagnosticExchange)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        foreignExchange.cancel()
        XCTAssertThrowsError(try diagnosticService.serve(foreignPermit,on:foreignExchange)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        XCTAssertTrue(diagnostics.isEmpty)
        try diagnosticService.serve(diagnosticPermit,on:diagnosticExchange)
        XCTAssertEqual(diagnostics,[debug]);XCTAssertEqual(diagnosticExchange.snapshot.receipts.count,1)
        XCTAssertEqual(diagnosticExchange.snapshot.receipts[0].request,.window(debug))
        XCTAssertEqual(diagnosticExchange.snapshot.receipts[0].response,.window(reply))
        XCTAssertFalse(diagnosticExchange.snapshot.receipts[0].resources.isEmpty)
        XCTAssertThrowsError(try diagnosticService.serve(diagnosticPermit,on:diagnosticExchange))
        XCTAssertEqual(diagnostics,[debug])
        let thrown = E(),thrownPermit = try G().ticket(thrown,.window(debug))
        let throwingService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);throw Stop.late })
        XCTAssertThrowsError(try throwingService.serve(thrownPermit,on:thrown)) { XCTAssertTrue($0 is Stop) }
        XCTAssertEqual(diagnostics,[debug,debug]);XCTAssertEqual(thrown.snapshot.status,.indeterminate)
        XCTAssertTrue(thrown.snapshot.receipts.isEmpty)
        let failure = try XCTUnwrap(thrown.snapshot.failure)
        XCTAssertEqual(failure.request,.window(debug));XCTAssertFalse(failure.afterCancellation);XCTAssertFalse(failure.resources.isEmpty)
        XCTAssertThrowsError(try throwingService.serve(thrownPermit,on:thrown));XCTAssertEqual(diagnostics.count,2)
        let late = E(),latePermit = try G().ticket(late,.window(debug))
        let lateService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);late.cancel();return reply })
        try lateService.serve(latePermit,on:late)
        XCTAssertEqual(late.snapshot.status,.cancelled);XCTAssertEqual(late.snapshot.receipts.count,1)
        XCTAssertEqual(late.snapshot.receipts[0].response,.window(reply));XCTAssertFalse(late.snapshot.receipts[0].resources.isEmpty)
        XCTAssertThrowsError(try lateService.serve(latePermit,on:late));XCTAssertEqual(diagnostics.count,3)
        XCTAssertEqual(try b.pixels(back),pixels);XCTAssertEqual(b.frontOperations.count,count+1)
'''+anchor)
    # Old pixel/mask calculation and its assertions remain byte-for-byte present.
    for start,end in [('    func expected(', '    func whole('),('    func checkFrame(', '    func testProtocolPreflightResourcesAndReleaseKeepDistinctOutcomes')]:
        assert before[before.index(start):before.index(end)]==s[s.index(start):s.index(end)]
    p.write_text(s);changes[name]=dict(before=before,after=s)
    return changes
