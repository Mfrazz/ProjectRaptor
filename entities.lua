-- entities.lua
-- Contains functions for creating game entities.
-- It relies on the global Config, CharacterBlueprints, and EnemyBlueprints tables.

local function createSquare(startX, startY, type, subType)
    local square = {}
    square.size = Config.SQUARE_SIZE
    square.moveStep = Config.MOVE_STEP
    square.speed = Config.SLIDE_SPEED
    square.type = type or "player" -- "player" or "enemy"
    square.lastDirection = "down" -- Default starting direction

    -- Set properties based on type/playerType
    if square.type == "player" then
        square.playerType = subType -- e.g., "cyansquare"
        local blueprint = CharacterBlueprints[subType]
        square.color = {blueprint.color[1], blueprint.color[2], blueprint.color[3], 1}
        square.maxHp = blueprint.maxHp
        square.attackStat = blueprint.attackStat
        square.defenseStat = blueprint.defenseStat
        square.speedStat = blueprint.speedStat
        square.pendingAttackKey = nil -- For player: stores 'j' or 'k' or 'l' if attack is queued
        square.ai_mode = "normal" -- The current AI mode for this player
        square.ai_last_attack_key = nil -- The last attack used, for the AI to repeat
        square.aiMoveTimer = 0 -- Timer to control how often the AI makes a move decision
        square.ai_path = {} -- Stores a sequence of moves for the AI to follow
        square.regenTimer = 0 -- For Pink Square's passive
        square.shakeTimer = 0
        square.speedMultiplier = 1 -- For special movement speeds like dashes
        square.afterimageTimer = 0 -- For visual afterimage effect
        square.shakeIntensity = 0
        square.flashTimer = 0 -- For player flash effect
    elseif square.type == "enemy" then
        square.enemyType = subType -- e.g., "standard"
        local blueprint = EnemyBlueprints[subType]
        square.color = {blueprint.color[1], blueprint.color[2], blueprint.color[3], 1}
        square.maxHp = blueprint.maxHp
        square.attackStat = blueprint.attackStat
        square.defenseStat = blueprint.defenseStat
        square.speedStat = blueprint.speedStat
        square.attackName = blueprint.attackName -- Store the name of the attack function
        square.attackPower = blueprint.attackPower
        square.ai_type = blueprint.ai_type -- Store the AI type
        square.shakeTimer = 0
        square.shakeIntensity = 0
        square.originalSpeedStat = blueprint.speedStat
    end

    square.actionBarCurrent = square.speedStat -- Action bar starts full
    square.hp = square.maxHp -- All squares start with full HP

    -- A scalable way to handle status effects
    square.statusEffects = {}

    -- Initialize current and target positions
    square.x = math.floor((startX / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    square.y = math.floor((startY / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    square.targetX = square.x
    square.targetY = square.y

    -- Enemy specific timers
    if square.type == "enemy" then
        local blueprint = EnemyBlueprints[subType]
        square.moveDelay = blueprint.moveDelay
        square.moveTimer = math.random() * square.moveDelay
        square.attackDelay = blueprint.attackDelay
        square.attackTimer = math.random() * square.attackDelay
    end

    return square
end

return createSquare