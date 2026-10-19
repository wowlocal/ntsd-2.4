import NTSDCore

/// NTSD 2.4's game profile (ENGINE_SPLIT E5): the object IDs the engine's passes
/// test, as the 2.0a EXE tests them. Which of these rules are LF2 2.0a's and
/// which NTSD's stays open until the second reference (D1, E6).
public enum NTSDProfile {
    public static let rules = OriginalGameRules(profile: "NTSD 2.4 2.0a",
        // Objects a reflector sends back, the reflector, and the attackers whose hit (8)
        // or held hit (213) rebinds them to it: OriginalHitDamage, OriginalWorldContacts.
        reflection: .init(reflectable: OriginalIDSet([200, 203, 205, 206, 207, 215, 216]), reflector: 209, rebinder: 8, heldRebinder: 213),
        // The automatic guards: OriginalActorHits.guarded, OriginalHitGuard.
        armour: .init(guardPenetrators: OriginalIDSet([214, 208]), steadyArmour: 37, openingArmour: 6, attackerArmour: 52,
                      alwaysBlocked: OriginalIDSet([124, 220, 221, 222]), armourGuardSound: OriginalIDSet([37, 6])),
        // Special interactions: OriginalHitSpecial, OriginalWorldContacts.
        interaction: .init(holdKind101: OriginalIDSet([120, 124]), pullImmune: OriginalIDSet([201, 202]), teamBypass: 212,
                           countsAsCharacter: OriginalIDSet([201, 202])),
        // What an attacker's hit does to it or to the defender's x impulse: OriginalHitDamage.
        impact: .init(vanishingAttacker: 201, spentAttacker: 214, heavyHeldWeapon: 100))
}
