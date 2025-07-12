-- ai_systems.lua
-- Contains all AI logic for game entities, driven by components.

local Navigation = require("modules.navigation")
local EnemyAttacks = require("data.enemy_attacks")
local WorldQueries = require("modules.world_queries")
local AttackPatterns = require("modules.attack_patterns")
local AttackHandler = require("modules.attack_handler")

local AISystems = {}

-- Helper to shuffle a table. Creates a copy to avoid modifying the original blueprint.
local function shuffle(tbl)
    -- Create a shallow copy of the table
    local new_tbl = {}
    for i = 1, #tbl do new_tbl[i] = tbl[i] end
    -- Perform Fisher-Yates shuffle on the copy
    for i = #new_tbl, 2, -1 do
        local j = math.random(i)
        new_tbl[i], new_tbl[j] = new_tbl[j], new_tbl[i]
    end
    return new_tbl
end

-- Helper function for ranged kiting movement.
-- Moves the entity away from the target if it's too close.
local function perform_kiting_move(entity, target, world)
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
    local dx, dy = target.x - entity.x, target.y - entity.y
    local preferredMove, fallbackMove

    if math.abs(dx) > math.abs(dy) then
        preferredMove = { x = (dx > 0) and -entity.moveStep or entity.moveStep, y = 0 }
        fallbackMove = { x = 0, y = (dy > 0) and -entity.moveStep or entity.moveStep }
    else
        preferredMove = { x = 0, y = (dy > 0) and -entity.moveStep or entity.moveStep }
        fallbackMove = { x = (dx > 0) and -entity.moveStep or entity.moveStep, y = 0 }
    end

    local potentialTargetX = math.max(0, math.min(entity.x + preferredMove.x, windowWidth - entity.size))
    local potentialTargetY = math.max(0, math.min(entity.y + preferredMove.y, windowHeight - entity.size))
    if not WorldQueries.isTileOccupied(potentialTargetX, potentialTargetY, entity.size, entity, world) then
        entity.targetX, entity.targetY = potentialTargetX, potentialTargetY
    else
        potentialTargetX = math.max(0, math.min(entity.x + fallbackMove.x, windowWidth - entity.size))
        potentialTargetY = math.max(0, math.min(entity.y + fallbackMove.y, windowHeight - entity.size))
        if not WorldQueries.isTileOccupied(potentialTargetX, potentialTargetY, entity.size, entity, world) then
            entity.targetX, entity.targetY = potentialTargetX, potentialTargetY
        end
    end
end

-- This single function updates all AI entities based on their component data.
function AISystems.update(dt, world)
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

    local players = world.players
    local enemies = world.enemies

    -- Loop 1: Player AI
    for i, p in ipairs(world.players) do
        -- This system only operates on entities with an AI component
        if p.components.ai and (world.isAutopilotActive or i ~= world.activePlayerIndex) and p.hp > 0 and not p.statusEffects.stunned and not p.statusEffects.careening and not p.continuousAttack and not p.components.pidgeot_l_attack then
            local ai = p.components.ai
            local isMoving = (p.x ~= p.targetX) or (p.y ~= p.targetY)

            -- Force AI to face the correct target when idle.
            if not isMoving then
                local lastAttackData = ai.last_attack_key and CharacterBlueprints[p.playerType].attacks[ai.last_attack_key]
                local isSupportMode = lastAttackData and lastAttackData.type == "support"
                local target = nil

                if isSupportMode then
                    local lowestHpRatio = 1
                    for _, ally in ipairs(players) do
                        if ally ~= p and ally.hp > 0 and ally.hp < ally.maxHp then
                            local hpRatio = ally.hp / ally.maxHp
                            if hpRatio < lowestHpRatio then
                                lowestHpRatio, target = hpRatio, ally
                            end
                        end
                    end
                else
                    local shortestDistSq = math.huge
                    for _, enemy in ipairs(enemies) do
                        if enemy.hp > 0 then
                            local distSq = (enemy.x - p.x)^2 + (enemy.y - p.y)^2
                            if distSq < shortestDistSq then
                                shortestDistSq, target = distSq, enemy
                            end
                        end
                    end
                end

                if target then
                    local dx, dy = target.x - p.x, target.y - p.y
                    if math.abs(dx) > math.abs(dy) then
                        p.lastDirection = (dx > 0) and "right" or "left"
                    else
                        p.lastDirection = (dy > 0) and "down" or "up"
                    end
                end
            end

            -- 1. AI Attack Logic
            if ai.last_attack_key and not isMoving then
                local attackData = CharacterBlueprints[p.playerType].attacks[ai.last_attack_key]
                if attackData and attackData.cost and p.actionBarCurrent >= p.actionBarMax and attackData.name then
                    local canAttack = false
                    local patternFunc = AttackPatterns[attackData.name]
 
                    if not patternFunc then
                        canAttack = true -- Assume non-pattern attacks can always be used.
                    elseif attackData.name == "florges_k" then
                        -- Special check for Florges K: only consider it usable if a valid target is in the pattern.
                        local validTargets = {}
                        for _, ally in ipairs(players) do
                            if ally.hp > 0 and (ally.hp < ally.maxHp or (ally.statusEffects and ally.statusEffects.poison)) then
                                table.insert(validTargets, ally)
                            end
                        end
                        -- If there are any allies who need help, check if any of them are in range.
                        if #validTargets > 0 then
                            canAttack = WorldQueries.isTargetInPattern(p, patternFunc, validTargets, world)
                        end
                    else
                        -- Standard attack logic
                        local targetList = (attackData.type == "support") and players or enemies
                        canAttack = WorldQueries.isTargetInPattern(p, patternFunc, targetList, world)
                    end

                    if canAttack then
                        local wasContinuousBefore = p.continuousAttack
                        local attackFired = AttackHandler.execute(p, ai.last_attack_key, world)
                        if attackFired and not (wasContinuousBefore and not p.continuousAttack) then
                            p.actionBarCurrent = 0
                            p.actionBarMax = attackData.cost
                        end
                    end
                end
            end

            -- 2. AI Movement Logic
            if not isMoving then
                if #ai.path > 0 then
                    local nextStep = table.remove(ai.path, 1)
                    p.targetX, p.targetY = nextStep.x, nextStep.y
                    if p.targetX ~= p.x then p.lastDirection = (p.targetX > p.x) and "right" or "left"
                    elseif p.targetY ~= p.y then p.lastDirection = (p.targetY > p.y) and "down" or "up" end
                else
                    ai.move_timer = ai.move_timer - dt
                    if ai.move_timer <= 0 then
                        local closestEnemy, shortestDistSq = nil, math.huge
                        for _, enemy in ipairs(enemies) do
                            if enemy.hp > 0 then
                                local distSq = (enemy.x - p.x)^2 + (enemy.y - p.y)^2
                                if distSq < shortestDistSq then
                                    shortestDistSq, closestEnemy = distSq, enemy
                                end
                            end
                        end

                        if ai.last_attack_key then
                            local lastAttackData = CharacterBlueprints[p.playerType].attacks[ai.last_attack_key]
                            local isSupportMode = lastAttackData and lastAttackData.type == "support"

                            if isSupportMode then
                                local targetAlly, lowestMetric = nil, 1
                                for _, ally in ipairs(players) do
                                    if ally ~= p and ally.hp > 0 then
                                        local metric = ally.hp / ally.maxHp
                                        if metric < lowestMetric then
                                            lowestMetric, targetAlly = metric, ally
                                        end
                                    end
                                end
                                if targetAlly then
                                    ai.path = Navigation.findPath(p, targetAlly, world)
                                    if #ai.path == 0 then
                                        local patternFunc = lastAttackData and AttackPatterns[lastAttackData.name]
                                        if patternFunc and not WorldQueries.isTargetInPattern(p, patternFunc, {targetAlly}, world) then
                                            Navigation.repositionForAttack(p, targetAlly, world, patternFunc)
                                        end
                                    end
                                end
                            elseif closestEnemy then
                                if lastAttackData and lastAttackData.attack_style == "melee" then
                                    ai.path = Navigation.findPath(p, closestEnemy, world)
                                    if #ai.path == 0 then
                                        local patternFunc = lastAttackData and AttackPatterns[lastAttackData.name]
                                        if patternFunc and not WorldQueries.isTargetInPattern(p, patternFunc, {closestEnemy}, world) then
                                            Navigation.repositionForAttack(p, closestEnemy, world, patternFunc)
                                        end
                                    end
                                elseif lastAttackData and lastAttackData.attack_style == "ranged" then
                                    local desiredKitingDistSq = (3 * Config.MOVE_STEP)^2 -- Minimum safe distance
                                    local patternFunc = lastAttackData and AttackPatterns[lastAttackData.name]

                                    if shortestDistSq < desiredKitingDistSq then
                                        -- Too close, move away.
                                        perform_kiting_move(p, closestEnemy, world)
                                    else
                                        -- Not too close. If we can't hit from here, find a better spot.
                                        if patternFunc and not WorldQueries.isTargetInPattern(p, patternFunc, {closestEnemy}, world) then
                                            Navigation.repositionForAttack(p, closestEnemy, world, patternFunc)
                                        end
                                    end
                                end
                            end
                        end
                        ai.move_timer = 0.2
                    end
                end
            end
        end
    end

    -- Loop 2: Enemy AI
    for _, enemy in ipairs(enemies) do
        -- This system only operates on entities with an AI component
        if enemy.components.ai then
            local ai = enemy.components.ai
            local targetPlayer, shortestDistanceSq = nil, math.huge
            if #players > 0 then
                for _, player in ipairs(players) do
                    if player.hp > 0 then
                        local distSq = (player.x - enemy.x)^2 + (player.y - enemy.y)^2
                        if distSq < shortestDistanceSq then
                            shortestDistanceSq, targetPlayer = distSq, player
                        end
                    end
                end
            end

            if targetPlayer then
                local dx, dy = targetPlayer.x - enemy.x, targetPlayer.y - enemy.y
                if math.abs(dx) > math.abs(dy) then
                    enemy.lastDirection = (dx > 0) and "right" or "left"
                else
                    enemy.lastDirection = (dy > 0) and "down" or "up"
                end
            end

            ai.move_timer = ai.move_timer - dt
            local isEnemyMoving = (enemy.x ~= enemy.targetX) or (enemy.y ~= enemy.targetY)

            -- All enemy actions (moving and attacking) are now gated by the move_timer.
            if ai.move_timer <= 0 and not isEnemyMoving and not enemy.statusEffects.stunned and not enemy.statusEffects.paralyzed and not enemy.statusEffects.careening and not enemy.statusEffects.airborne then
                local actionTaken = false

                -- Priority 1: Attack if the action bar is full and an attack is possible.
                if enemy.actionBarCurrent >= enemy.actionBarMax then
                    local blueprintAttacks = EnemyBlueprints[enemy.enemyType].attacks
                    if blueprintAttacks and #blueprintAttacks > 0 then
                        local availableAttacks = shuffle(blueprintAttacks)
                        for _, attackData in ipairs(availableAttacks) do
                            local patternFunc = AttackPatterns[attackData.name]
                            if not patternFunc or WorldQueries.isTargetInPattern(enemy, patternFunc, players, world) then
                                if EnemyAttacks[attackData.name] then
                                    EnemyAttacks[attackData.name](enemy, attackData, world)
                                    enemy.actionBarCurrent = 0
                                    enemy.actionBarMax = attackData.cost
                                    actionTaken = true
                                    break
                                end
                            end
                        end
                    end
                end

                -- Priority 2: If no attack was made, but the action bar is full, try to reposition.
                if not actionTaken and enemy.actionBarCurrent >= enemy.actionBarMax and targetPlayer then
                    local blueprintAttacks = EnemyBlueprints[enemy.enemyType].attacks
                    if blueprintAttacks and #blueprintAttacks > 0 then
                        local repositionAttack = blueprintAttacks[1]
                        local patternToReposition = AttackPatterns[repositionAttack.name]
                        if patternToReposition then
                            Navigation.repositionForAttack(enemy, targetPlayer, world, patternToReposition)
                            actionTaken = true
                        end
                    end
                end

                -- Priority 3: If no other action was taken, perform standard movement.
                if not actionTaken then
                    if targetPlayer then
                        local intendedAttack = EnemyBlueprints[enemy.enemyType].attacks[1]
                        if intendedAttack and intendedAttack.attack_style == "melee" then
                            local path = Navigation.findPath(enemy, targetPlayer, world)
                            if #path > 0 then enemy.targetX, enemy.targetY = path[1].x, path[1].y end
                        elseif intendedAttack and intendedAttack.attack_style == "ranged" then
                            -- If moving to reposition for a ranged attack, face the player.
                            local dx, dy = targetPlayer.x - enemy.x, targetPlayer.y - enemy.y
                            enemy.lastDirection = (math.abs(dx) > math.abs(dy)) and ((dx > 0) and "right" or "left") or ((dy > 0) and "down" or "up")

                            local desiredKitingDistSq = (4 * Config.MOVE_STEP)^2
                            if shortestDistanceSq < desiredKitingDistSq then
                                perform_kiting_move(enemy, targetPlayer, world)
                            else
                                -- Not too close. If we can't hit from here, find a better spot.
                                local patternFunc = AttackPatterns[intendedAttack.name]
                                if patternFunc and not WorldQueries.isTargetInPattern(enemy, patternFunc, players, world) then
                                    Navigation.repositionForAttack(enemy, targetPlayer, world, patternFunc)
                                end
                            end
                        end
                    else
                        -- No target, wander randomly.
                        local directions = {"up", "down", "left", "right", "stay"}
                        local chosenDirection = directions[math.random(1, #directions)]
                        local newTargetX, newTargetY = enemy.x, enemy.y
                        if chosenDirection == "up" then newTargetY = enemy.y - enemy.moveStep
                        elseif chosenDirection == "down" then newTargetY = enemy.y + enemy.moveStep
                        elseif chosenDirection == "left" then newTargetX = enemy.x - enemy.moveStep
                        elseif chosenDirection == "right" then newTargetX = enemy.x + enemy.moveStep end
                        local potentialTargetX = math.max(0, math.min(newTargetX, windowWidth - enemy.size))
                        local potentialTargetY = math.max(0, math.min(newTargetY, windowHeight - enemy.size))
                        if not WorldQueries.isTileOccupied(potentialTargetX, potentialTargetY, enemy.size, enemy, world) then
                            enemy.targetX, enemy.targetY = potentialTargetX, potentialTargetY
                        end

                        -- Update direction when moving randomly
                        if enemy.targetX ~= enemy.x then enemy.lastDirection = (enemy.targetX > enemy.x) and "right" or "left"
                        elseif enemy.targetY ~= enemy.y then enemy.lastDirection = (enemy.targetY > enemy.y) and "down" or "up" end
                    end
                end

                -- Reset the timer after any action is taken.
                ai.move_timer = ai.move_delay
            end
        end
    end
end

return AISystems