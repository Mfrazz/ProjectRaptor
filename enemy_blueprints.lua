-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        color = {0.7, 0.7, 0.7},
        maxHp = 140,
        attackStat = 60,
        defenseStat = 50,
        attacks = {
            {name = "standard_melee", power = 20, cost = 3}
        },
        moveDelay = 3.0,
        ai_type = "melee_chaser" -- Moves towards the player
    },
    archer = {
        color = {0.7, 0.7, 0.7},
        maxHp = 110,
        attackStat = 50,
        defenseStat = 40,
        attacks = {
            {name = "archer_shot", power = 10, cost = 2},
            {name = "archer_barrage", power = 5, cost = 4} -- New attack
        },
        moveDelay = 3.0,
        ai_type = "ranged_kiter" -- Moves away from the player
    },
    punter = {
        color = {0.7, 0.7, 0.7},
        maxHp = 120,
        attackStat = 50,
        defenseStat = 40,
        attacks = {
            {name = "punter_spin", power = 15, cost = 3}
        },
        moveDelay = 3.0,
        ai_type = "melee_chaser"
    }
}

return EnemyBlueprints