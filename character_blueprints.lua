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
        attack_style = "melee",
        attacks = {
            j = {name = "cyan_j", power = 40, cost = 2, type = "damage"},
            k = {name = "cyan_k", power = 20, cost = 2, type = "damage"},
            l = {name = "cyan_l", power = 40, cost = 4, type = "damage"},
        }
    },
    pinksquare = {
        color = {1, 0.4, 0.7},
        maxHp = 100,
        attackStat = 40,
        defenseStat = 50,
        attack_style = "melee",
        attacks = {
            j = {name = "pink_j", power = 20, cost = 2, type = "damage"},
            k = {name = "pink_k", power = 40, cost = 5, type = "support"}, -- Power here represents heal amount
            l = {name = "pink_l", power = 0, cost = 2, type = "support"},
        }
    },
    yellowsquare = {
        color = {1, 1, 0},
        maxHp = 60,
        attackStat = 60,
        defenseStat = 50,
        attack_style = "ranged",
        attacks = {
            j = {name = "yellow_j", power = 20, cost = 1, type = "damage"},
            k = {name = "yellow_k", power = 20, cost = 2, type = "damage"},
            l = {name = "yellow_l", power = 0, cost = 3, type = "support"},
        }
    },
    stripedsquare = {
        color = {0, 0, 0}, -- Base color is black, stripes are drawn manually
        maxHp = 80,
        attackStat = 50,
        defenseStat = 50,
        attack_style = "melee",
        attacks = {
            j = {name = "striped_j", power = 30, cost = 3, type = "damage"},
            k = {name = "striped_k", power = 0, cost = 2, type = "support"},
            l = {name = "striped_l", power = 0, cost = 2, type = "support"},
        }
    },
    orangesquare = {
        color = {1, 0.5, 0},
        maxHp = 100,
        attackStat = 50,
        defenseStat = 50,
        attack_style = "melee",
        attacks = {
            j = {name = "orange_j", power = 20, cost = 5, type = "damage"}, -- Continuous attack, power is per hit
            k = {name = "orange_k", power = 40, cost = 2, type = "damage"},
            l = {name = "orange_l", power = 0, cost = 1, type = "support"},
        }
    }
}

return CharacterBlueprints