import NTSDCore

/// ENGINE_SPLIT E5c-2d (survey F11): a copy of a profile with some families
/// replaced, so a test names only the family it moves and a new family edits
/// only this helper, the game's profile and the engine tests' value.
extension OriginalGameRules {
    func with(profile: String = "moved",reflection: Reflection? = nil,armour: Armour? = nil,interaction: Interaction? = nil,
              impact: Impact? = nil,items: Items? = nil,roster: Roster? = nil,modes: Modes? = nil,
              physics: Physics? = nil,drawing: Drawing? = nil,effects: Effects? = nil,lifecycle: Lifecycle? = nil,fusion: Fusion? = nil,
              weaponBreak: WeaponBreak? = nil,
              characterAI: CharacterAI? = nil,characterAISpecial: (any OriginalCharacterAISpecial)? = nil) -> OriginalGameRules {
        OriginalGameRules(profile: profile,reflection: reflection ?? self.reflection,armour: armour ?? self.armour,
                          interaction: interaction ?? self.interaction,impact: impact ?? self.impact,items: items ?? self.items,
                          roster: roster ?? self.roster,modes: modes ?? self.modes,physics: physics ?? self.physics,
                          drawing: drawing ?? self.drawing,effects: effects ?? self.effects,lifecycle: lifecycle ?? self.lifecycle,fusion: fusion ?? self.fusion,
                          weaponBreak: weaponBreak ?? self.weaponBreak,
                          characterAI: characterAI ?? self.characterAI,characterAISpecial: characterAISpecial ?? self.characterAISpecial)
    }
}
