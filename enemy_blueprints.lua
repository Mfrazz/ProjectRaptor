-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        color = {0.7, 0.7, 0.7},
        maxHp = 140,
        attackStat = 60,
        defenseStat = 50,
        speedStat = 6,
        attackName = "standard_melee",
        attackPower = 40,
        attackDelay = 3.0,
        moveDelay = 3.0,
        ai_type = "melee_chaser" -- Moves towards the player
    },
    archer = {
        color = {0.7, 0.7, 0.7},
        maxHp = 110,
        attackStat = 50,
        defenseStat = 40,
        speedStat = 7,
        attackName = "archer_shot",
        attackPower = 40,
        attackDelay = 4.0,
        moveDelay = 3.0,
        ai_type = "ranged_kiter" -- Moves away from the player
    }
}

return EnemyBlueprints