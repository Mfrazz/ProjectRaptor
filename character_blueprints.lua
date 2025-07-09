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
        speedStat = 4,
        attacks = {
            j = {name = "cyan_j", power = 50, cost = 2},
            k = {name = "cyan_k", power = 20, cost = 2},
            l = {name = "cyan_l", power = 40, cost = 4},
        }
    },
    pinksquare = {
        color = {1, 0.4, 0.7},
        maxHp = 100, -- BASE_INITIAL_HP
        attackStat = 40,
        defenseStat = 50,
        speedStat = 5,
        attacks = {
            j = {name = "pink_j", power = 20, cost = 2},
            k = {name = "pink_k", power = 50, cost = 2}, -- Power here represents heal amount
            l = {name = "pink_l", power = 0, cost = 2},
        }
    },
    yellowsquare = {
        color = {1, 1, 0},
        maxHp = 60,
        attackStat = 60,
        defenseStat = 50,
        speedStat = 3,
        attacks = {
            j = {name = "yellow_j", power = 20, cost = 1},
            k = {name = "yellow_k", power = 20, cost = 2},
            l = {name = "yellow_l", power = 0, cost = 3},
        }
    },
    stripedsquare = {
        color = {0, 0, 0}, -- Base color is black, stripes are drawn manually
        maxHp = 80,
        attackStat = 50,
        defenseStat = 50,
        speedStat = 4,
        attacks = {
            j = {name = "striped_j", power = 30, cost = 3},
            k = {name = "striped_k", power = 0, cost = 2},
            l = {name = "striped_l", power = 0, cost = 2},
        }
    },
    orangesquare = {
        color = {1, 0.5, 0},
        maxHp = 100,
        attackStat = 50,
        defenseStat = 50,
        speedStat = 5,
        attacks = {
            j = {name = "orange_j", power = 20, cost = 5}, -- Continuous attack, power is per hit
            k = {name = "orange_k", power = 40, cost = 2},
            l = {name = "orange_l", power = 0, cost = 1},
        }
    }
}

return CharacterBlueprints