/// The round's epilogue exit: 41d714 returns `.epilogue` after the post-KO
/// restoration (timer 350) and 41bc90 jumps to its common epilogue 422a95.
/// No gameplay, menu or drawing body runs in this iteration; the enclosing
/// dispatcher return is the one accepted after gameplay. Owners and graphics
/// stay as the input continuation left them.
public enum OriginalApplicationEpilogueSession {
    public typealias Menu = OriginalApplicationLoadedMenuSession

    public static func finish(pending entry: OriginalApplicationInputSession.PendingContinuation,
                              outputInput: OriginalMenuPresentationInput) throws -> Menu.PendingReturn {
        try entry.state.validateAliases()
        guard entry.round.continuation == .epilogue else { throw Menu.Boundary.dependency("Epilogue continuation") }
        let a = try Menu.Attempt(entry,.init(bitmaps:[:]),(),
            .init(dcResult:outputInput.dcResult,dc:outputInput.dc,methodResult:outputInput.methodResult,
                  drawResults:[outputInput.methodResult],shellResult:33),outputInput,
            { _,_,_ in throw Menu.Boundary.dependency("Unexpected epilogue allocation") },
            { _,_ in throw Menu.Boundary.dependency("Unexpected epilogue bitmap") },
            { _,_ in throw Menu.Boundary.dependency("Unexpected epilogue music") },
            { _ in throw Menu.Boundary.dependency("Unexpected epilogue clock") },{ _,_ in },{ _,_,_ in })
        var state = a.state
        try a.bindings.store(entry.match,context:entry.inputContext,in:&state)
        let snapshot = Menu.Snapshot(state:state,match:entry.match,music:a.audio,resources:a.resources,
            backgrounds:a.backgrounds,local:a.local,operations:a.operations)
        let result = try OriginalApplicationDispatchEntry.finishWorldCall(globals:state.full)
        return .init(entry:entry,snapshot:snapshot,exit:.returned,dispatcherResult:result,graphics:a.graphics)
    }
}
