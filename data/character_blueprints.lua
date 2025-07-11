-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table now contains string identifiers for attack functions,
-- which are implemented in systems.lua.

local CharacterBlueprints = {
    cyansquare = {
        color = {0, 1, 1},
        maxHp = 120,
        attackStat = 50,
        defenseStat = 50,
        passive = "cyan_action_on_kill",
        attacks = {
            j = {name = "cyan_j", power = 40, cost = 2, type = "damage", attack_style = "melee"},
            k = {name = "cyan_k", power = 20, cost = 2, type = "damage", attack_style = "melee"},
            l = {name = "cyan_l", power = 40, cost = 4, type = "damage", attack_style = "melee"},
        }
    },
    pinksquare = {
        color = {1, 0.4, 0.7},
        maxHp = 100,
        attackStat = 40,
        defenseStat = 50,
        passive = "pink_regen",
        attacks = {
            j = {name = "pink_j", power = 20, cost = 2, type = "damage", attack_style = "melee"},
            k = {name = "pink_k", power = 40, cost = 5, type = "support", attack_style = "melee"}, -- Power here represents heal amount
            l = {name = "pink_l", power = 0, cost = 2, type = "support", attack_style = "melee"},
        }
    },
    yellowsquare = {
        color = {1, 1, 0},
        maxHp = 60,
        attackStat = 60,
        defenseStat = 50,
        passive = "yellow_crit_bonus",
        attacks = {
            j = {name = "yellow_j", power = 20, cost = 1, type = "damage", attack_style = "ranged"},
            k = {name = "yellow_k", power = 20, cost = 2, type = "damage", attack_style = "ranged"},
            l = {name = "yellow_l", power = 0, cost = 3, type = "support", attack_style = "ranged"},
        }
    },
    stripedsquare = {
        color = {0, 0, 0}, -- Base color is black, stripes are drawn manually
        maxHp = 80,
        attackStat = 50,
        defenseStat = 50,
        -- No team-wide passive, but has unique attack mechanics
        attacks = {
            j = {name = "striped_j", power = 30, cost = 3, type = "damage", attack_style = "melee"},
            k = {name = "striped_k", power = 0, cost = 2, type = "support", attack_style = "melee"},
            l = {name = "striped_l", power = 0, cost = 2, type = "support", attack_style = "melee"},
        }
    },
    orangesquare = {
        color = {1, 0.5, 0},
        maxHp = 100,
        attackStat = 50,
        defenseStat = 50,
        passive = "orange_comet_damage",
        attacks = {
            j = {name = "orange_j", power = 20, cost = 5, type = "damage", attack_style = "ranged"}, -- Continuous attack, power is per hit
            k = {name = "orange_k", power = 40, cost = 2, type = "damage", attack_style = "ranged"},
            l = {name = "orange_l", power = 0, cost = 1, type = "support", attack_style = "melee"},
        }
    },
    purplesquare = {
        color = {0.4, 0, 0.4},
        maxHp = 101,
        attackStat = 50,
        defenseStat = 50,
        passive = "purple_careen_double",
        attacks = {
            j = {name = "purple_j", power = 10, cost = 3, type = "damage", attack_style = "ranged"}, -- Grappling Hook
            k = {name = "purple_k", power = 0, cost = 4, type = "support", attack_style = "ranged"}, -- Team Shield
            l = {name = "purple_l", power = 10, cost = 5, type = "damage", attack_style = "ranged"}, -- Mass Grapple
        }
    }
}

return CharacterBlueprints