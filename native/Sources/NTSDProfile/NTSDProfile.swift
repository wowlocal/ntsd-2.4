import NTSDCore

/// NTSD 2.4's game profile (ENGINE_SPLIT E5): the object IDs the engine's passes
/// test, as the 2.0a EXE tests them. Which of these rules are LF2 2.0a's and
/// which NTSD's stays open until the second reference (D1, E6).
public enum NTSDProfile {
    public static let rules = OriginalGameRules(profile: "NTSD 2.4 2.0a",
        // Objects a reflector (209, 8, 213) sends back: OriginalHitDamage, OriginalWorldContacts.
        reflectable: OriginalIDSet([200, 203, 205, 206, 207, 215, 216]))
}
