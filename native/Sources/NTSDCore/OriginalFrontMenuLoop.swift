import Foundation

///Control flow of4246b0 with retained early-menu state. Each callback composes
///the recovered shared mechanism with its live resources and platform inputs.
///The loading branch and unimplemented selectors remain explicit continuations.
public enum OriginalFrontMenuLoop {
    public enum Completion: String, Codable, Sendable { case main, tail, worldOne }
    public enum Continuation: String, Codable, Sendable {
        case returned, loading, settingsLoading, resourceBoundary, prefixBoundary, panelBoundary, bodyBoundary, alternateBoundary, otherSelector
    }
    public static func run(world: inout OriginalStateRecord,globals: inout OriginalStateRecord,
        initialize: (OriginalStateRecord,inout OriginalStateRecord) throws -> OriginalFrontMenuResourceResult,
        prefix: (inout OriginalStateRecord) throws -> OriginalFrontScreenPrelude.Continuation,
        update: (inout OriginalStateRecord) throws -> OriginalMenuPanelUpdate.Result,
        body: (inout OriginalStateRecord) throws -> OriginalFrontScreenBody.Continuation,
        alternate: (inout OriginalStateRecord,Int32) throws -> OriginalFrontScreenAlternate.Continuation,
        completion: (Completion,inout OriginalStateRecord,inout OriginalStateRecord) throws -> Void) throws -> Continuation {
        var ownWorld = world,state = globals
        func finish(_ end: Continuation) -> Continuation { world = ownWorld;globals = state;return end }
        switch try ownWorld.integer(at: 0,as: Int32.self) {
        case 1:try completion(.worldOne,&ownWorld,&state);return finish(.returned)
        case 2:return finish(.loading)
        default:break
        }
        switch try initialize(ownWorld,&state).continuation {
        case .settings:return finish(.settingsLoading)
        case .nullBitmap:return finish(.resourceBoundary)
        case .ready:break
        }
        switch try prefix(&state) {
        case .critical:
            guard try update(&state) == .ready else { return finish(.panelBoundary) }
            guard try body(&state) == .alternateDispatch else { return finish(.bodyBoundary) }
        case .alternate:break
        default:return finish(.prefixBoundary)
        }
        let selector = try state.integer(at: 0x44d064-OriginalMatchPreparation.globalBase,as: Int32.self)
        switch try alternate(&state,selector) {
        case .mainMenu:try completion(.main,&ownWorld,&state)
        case .presentation:try completion(.tail,&ownWorld,&state)
        case .otherSelector:return finish(.otherSelector)
        default:return finish(.alternateBoundary)
        }
        return finish(.returned)
    }
}
