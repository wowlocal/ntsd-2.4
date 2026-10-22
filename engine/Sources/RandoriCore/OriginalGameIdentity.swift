/// What a game is called where the engine shows or stores something for it
/// (ENGINE_SPLIT E3b): its name in the stop message and its user-data folder.
/// The original EXE's own strings ("Little Fighter 2", "Marti", "LF2") are
/// the game's behaviour and stay where the EXE model uses them.
public struct OriginalGameIdentity: Equatable, Sendable {
    public let name: String, userDataFolder: String
    public init(name: String,userDataFolder: String) { self.name = name; self.userDataFolder = userDataFolder }
}
