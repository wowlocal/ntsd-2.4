/// Whole original Actor control with the bundled library's state85/86 hook.
/// Other installed hooks and their enclosing initialized callers remain separate.
/// This native operation does not execute or load the reference DLL.
public enum OriginalLibActorControl {
    public static func apply(actor: inout OriginalStateRecord, object: OriginalLoadedObject,
                             globals: inout OriginalStateRecord, phase _: Int32, mode _: Int32,
                             precision: OriginalArithmeticPrecision = .bits64,
                             observe: (OriginalActorControlEvent) throws -> Void = { _ in }) throws {
        try OriginalActorControl.apply(actor: &actor, header: object.header, globals: &globals, frame: { index in
            guard object.frameStorage.indices.contains(Int(index)) else {
                throw OriginalStateError.invalidStorage("Library Actor control frame outside Object: \(index)")
            }
            return object.frameStorage[Int(index)]
        }, precision: precision, bundledLibrary: true, observe: observe)
    }
}
