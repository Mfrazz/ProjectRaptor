-- ai_systems.lua
-- Contains all AI logic for game entities.

local AISystems = {}

-- This function handles all decision-making for AI-controlled party members.
function AISystems.update_player_ai(dt, players, enemies, isAutopilotActive, activePlayerIndex)
    local windowWidth, windowHeight = love.graphics.getDimensions()

    for i, p in ipairs(players) do
        -- AI only runs for non-active players (or all players on autopilot) who are able to act.
        if (isAutopilotActive or i ~= activePlayerIndex) and p.hp > 0 and not p.statusEffects.stunned and not p.statusEffects.careening and not p.continuousAttack then
            local isMoving = (p.x ~= p.targetX) or (p.y ~= p.targetY)

            -- Force AI to face the correct target when idle.
            if not isMoving then
                local lastAttackData = p.ai_last_attack_key and CharacterBlueprints[p.playerType].attacks[p.ai_last_attack_key]
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
            if p.ai_last_attack_key and not isMoving then
                local attackData = CharacterBlueprints[p.playerType].attacks[p.ai_last_attack_key]
                if attackData and attackData.cost and p.actionBarCurrent >= p.actionBarMax then
                    local canAttack = false
                    local patternFunc = Systems.attacks.patterns[attackData.name]

                    if patternFunc then
                        local targetList = (attackData.type == "support") and players or enemies
                        canAttack = Systems.isTargetInPattern(p, patternFunc, targetList)
                    else
                        canAttack = true -- Assume non-pattern attacks can always be used.
                    end

                    if canAttack then
                        local wasContinuousBefore = p.continuousAttack
                        Systems.executeAttack(p, p.ai_last_attack_key)
                        if not (wasContinuousBefore and not p.continuousAttack) then
                            p.actionBarCurrent = 0
                            p.actionBarMax = attackData.cost
                        end
                    end
                end
            end

            -- 2. AI Movement Logic
            if not isMoving then
                if #p.ai_path > 0 then
                    local nextStep = table.remove(p.ai_path, 1)
                    p.targetX, p.targetY = nextStep.x, nextStep.y
                    if p.targetX ~= p.x then p.lastDirection = (p.targetX > p.x) and "right" or "left"
                    elseif p.targetY ~= p.y then p.lastDirection = (p.targetY > p.y) and "down" or "up" end
                else
                    p.aiMoveTimer = p.aiMoveTimer - dt
                    if p.aiMoveTimer <= 0 then
                        local closestEnemy, shortestDistSq = nil, math.huge
                        for _, enemy in ipairs(enemies) do
                            if enemy.hp > 0 then
                                local distSq = (enemy.x - p.x)^2 + (enemy.y - p.y)^2
                                if distSq < shortestDistSq then
                                    shortestDistSq, closestEnemy = distSq, enemy
                                end
                            end
                        end

                        if p.ai_last_attack_key then
                            local lastAttackData = CharacterBlueprints[p.playerType].attacks[p.ai_last_attack_key]
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
                                    p.ai_path = Systems.findPath(p, targetAlly)
                                    if #p.ai_path == 0 then
                                        local patternFunc = lastAttackData and Systems.attacks.patterns[lastAttackData.name]
                                        if patternFunc and not Systems.isTargetInPattern(p, patternFunc, {targetAlly}) then
                                            Systems.repositionForAttack(p, targetAlly)
                                        end
                                    end
                                end
                            elseif closestEnemy then
                                if p.attack_style == "melee" then
                                    p.ai_path = Systems.findPath(p, closestEnemy)
                                    if #p.ai_path == 0 then
                                        local patternFunc = lastAttackData and Systems.attacks.patterns[lastAttackData.name]
                                        if patternFunc and not Systems.isTargetInPattern(p, patternFunc, {closestEnemy}) then
                                            Systems.repositionForAttack(p, closestEnemy)
                                        end
                                    end
                                elseif p.attack_style == "ranged" then
                                    local desiredKitingDistSq = (3 * Config.MOVE_STEP)^2
                                    local maxEngagementDistSq = (8 * Config.MOVE_STEP)^2
                                    if shortestDistSq < desiredKitingDistSq then
                                        local dx, dy = closestEnemy.x - p.x, closestEnemy.y - p.y
                                        local preferredMove, fallbackMove
                                        if math.abs(dx) > math.abs(dy) then
                                            preferredMove = { x = (dx > 0) and -p.moveStep or p.moveStep, y = 0 }
                                            fallbackMove = { x = 0, y = (dy > 0) and -p.moveStep or p.moveStep }
                                        else
                                            preferredMove = { x = 0, y = (dy > 0) and -p.moveStep or p.moveStep }
                                            fallbackMove = { x = (dx > 0) and -p.moveStep or p.moveStep, y = 0 }
                                        end
                                        local potentialTargetX = math.max(0, math.min(p.x + preferredMove.x, windowWidth - p.size))
                                        local potentialTargetY = math.max(0, math.min(p.y + preferredMove.y, windowHeight - p.size))
                                        if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, p.size, p) then
                                            p.targetX, p.targetY = potentialTargetX, potentialTargetY
                                        else
                                            potentialTargetX = math.max(0, math.min(p.x + fallbackMove.x, windowWidth - p.size))
                                            potentialTargetY = math.max(0, math.min(p.y + fallbackMove.y, windowHeight - p.size))
                                            if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, p.size, p) then
                                                p.targetX, p.targetY = potentialTargetX, potentialTargetY
                                            end
                                        end
                                    elseif shortestDistSq > maxEngagementDistSq then
                                        p.ai_path = Systems.findPath(p, closestEnemy)
                                    else
                                        local patternFunc = lastAttackData and Systems.attacks.patterns[lastAttackData.name]
                                        if patternFunc and not Systems.isTargetInPattern(p, patternFunc, {closestEnemy}) then
                                            local dx, dy = closestEnemy.x - p.x, closestEnemy.y - p.y
                                            local sidestepMove
                                            if math.abs(dx) > math.abs(dy) then
                                                sidestepMove = { x = 0, y = (dy >= 0) and p.moveStep or -p.moveStep }
                                            else
                                                sidestepMove = { x = (dx >= 0) and p.moveStep or -p.moveStep, y = 0 }
                                            end
                                            local nextX, nextY = p.x + sidestepMove.x, p.y + sidestepMove.y
                                            if not Systems.isTileOccupied(nextX, nextY, p.size, p) then
                                                p.targetX, p.targetY = nextX, nextY
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        p.aiMoveTimer = 0.2
                    end
                end
            end
        end
    end
end

-- This function handles all enemy movement and attack logic.
function AISystems.update_enemy_ai(dt, players, enemies)
    local windowWidth, windowHeight = love.graphics.getDimensions()

    for _, enemy in ipairs(enemies) do
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

        enemy.moveTimer = enemy.moveTimer - dt
        local isEnemyMoving = (enemy.x ~= enemy.targetX) or (enemy.y ~= enemy.targetY)

        if enemy.moveTimer <= 0 and not isEnemyMoving and not enemy.statusEffects.stunned and not enemy.statusEffects.paralyzed and not enemy.statusEffects.careening then
            local newTargetX, newTargetY = enemy.x, enemy.y
            local movedAttempted = false
            if enemy.ai_type == "melee_chaser" and targetPlayer then
                local dx, dy = targetPlayer.x - enemy.x, targetPlayer.y - enemy.y
                local preferredMoveX, preferredMoveY = enemy.x, enemy.y
                local altMoveX, altMoveY = enemy.x, enemy.y
                if math.abs(dx) > math.abs(dy) then
                    preferredMoveX = (dx > 0) and enemy.x + enemy.moveStep or enemy.x - enemy.moveStep
                    altMoveY = (dy > 0) and enemy.y + enemy.moveStep or enemy.y - enemy.moveStep
                else
                    preferredMoveY = (dy > 0) and enemy.y + enemy.moveStep or enemy.y - enemy.moveStep
                    altMoveX = (dx > 0) and enemy.x + enemy.moveStep or enemy.x - enemy.moveStep
                end
                local potentialTargetX = math.max(0, math.min(preferredMoveX, windowWidth - enemy.size))
                local potentialTargetY = math.max(0, math.min(preferredMoveY, windowHeight - enemy.size))
                if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, enemy.size, enemy) and (potentialTargetX ~= enemy.x or potentialTargetY ~= enemy.y) then
                    newTargetX, newTargetY, movedAttempted = potentialTargetX, potentialTargetY, true
                else
                    potentialTargetX = math.max(0, math.min(altMoveX, windowWidth - enemy.size))
                    potentialTargetY = math.max(0, math.min(altMoveY, windowHeight - enemy.size))
                    if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, enemy.size, enemy) and (potentialTargetX ~= enemy.x or potentialTargetY ~= enemy.y) then
                        newTargetX, newTargetY, movedAttempted = potentialTargetX, potentialTargetY, true
                    end
                end
            elseif enemy.ai_type == "ranged_kiter" and targetPlayer then
                local dx, dy = targetPlayer.x - enemy.x, targetPlayer.y - enemy.y
                local preferredMoveX, preferredMoveY = enemy.x, enemy.y
                if math.abs(dx) > math.abs(dy) then
                    preferredMoveX = (dx > 0) and enemy.x - enemy.moveStep or enemy.x + enemy.moveStep
                else
                    preferredMoveY = (dy > 0) and enemy.y - enemy.moveStep or enemy.y + enemy.moveStep
                end
                local potentialTargetX = math.max(0, math.min(preferredMoveX, windowWidth - enemy.size))
                local potentialTargetY = math.max(0, math.min(preferredMoveY, windowHeight - enemy.size))
                if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, enemy.size, enemy) and (potentialTargetX ~= enemy.x or potentialTargetY ~= enemy.y) then
                    newTargetX, newTargetY, movedAttempted = potentialTargetX, potentialTargetY, true
                end
            end

            if not movedAttempted then
                local directions = {"up", "down", "left", "right", "stay"}
                local chosenDirection = directions[math.random(1, #directions)]
                if chosenDirection == "up" then newTargetY = enemy.y - enemy.moveStep
                elseif chosenDirection == "down" then newTargetY = enemy.y + enemy.moveStep
                elseif chosenDirection == "left" then newTargetX = enemy.x - enemy.moveStep
                elseif chosenDirection == "right" then newTargetX = enemy.x + enemy.moveStep end
                local potentialTargetX = math.max(0, math.min(newTargetX, windowWidth - enemy.size))
                local potentialTargetY = math.max(0, math.min(newTargetY, windowHeight - enemy.size))
                if not Systems.isTileOccupied(potentialTargetX, potentialTargetY, enemy.size, enemy) then
                    enemy.targetX, enemy.targetY = potentialTargetX, potentialTargetY
                end
                movedAttempted = true
            end

            if movedAttempted then
                enemy.targetX, enemy.targetY = newTargetX, newTargetY
            end
            enemy.moveTimer = enemy.moveDelay
        end

        if not enemy.statusEffects.stunned and not enemy.statusEffects.paralyzed and not enemy.statusEffects.careening then
            local enemyMoveAmount, epsilon = enemy.speed * dt, 1
            if enemy.x < enemy.targetX then
                enemy.x = math.min(enemy.targetX, enemy.x + enemyMoveAmount)
            elseif enemy.x > enemy.targetX then
                enemy.x = math.max(enemy.targetX, enemy.x - enemyMoveAmount)
            end
            if enemy.y < enemy.targetY then
                enemy.y = math.min(enemy.targetY, enemy.y + enemyMoveAmount)
            elseif enemy.y > enemy.targetY then
                enemy.y = math.max(enemy.targetY, enemy.y - enemyMoveAmount)
            end
        end

        if not isEnemyMoving and enemy.actionBarCurrent >= enemy.actionBarMax and not enemy.statusEffects.stunned and not enemy.statusEffects.careening then
            local availableAttacks = EnemyBlueprints[enemy.enemyType].attacks
            if availableAttacks then
                local possibleAttacks = {}
                for _, attackData in ipairs(availableAttacks) do
                    local canUse = false
                    local patternFunc = Systems.enemyAttacks.patterns[attackData.name]
                    if patternFunc then
                        canUse = Systems.isTargetInPattern(enemy, patternFunc, players)
                    elseif attackData.name == "archer_shot" and targetPlayer then
                        local isAligned = (enemy.lastDirection == "up" and targetPlayer.x == enemy.x and targetPlayer.y < enemy.y) or
                                          (enemy.lastDirection == "down" and targetPlayer.x == enemy.x and targetPlayer.y > enemy.y) or
                                          (enemy.lastDirection == "left" and targetPlayer.y == enemy.y and targetPlayer.x < enemy.x) or
                                          (enemy.lastDirection == "right" and targetPlayer.y == enemy.y and targetPlayer.x > enemy.x)
                        canUse = isAligned
                    else
                        canUse = true
                    end
                    if canUse then table.insert(possibleAttacks, attackData) end
                end
                if #possibleAttacks > 0 then
                    local chosenAttack = possibleAttacks[math.random(#possibleAttacks)]
                    if Systems.enemyAttacks[chosenAttack.name] then
                        Systems.enemyAttacks[chosenAttack.name](enemy, chosenAttack)
                    end
                end
            end
        end
    end
end

-- This function handles queued attacks for the active player after they stop moving.
function AISystems.update_queued_attacks(players, activePlayerIndex, lastAttackTimestamp)
    if activePlayerIndex > 0 and players[activePlayerIndex] then
        local currentPlayer = players[activePlayerIndex]
        local isCurrentPlayerMoving = (currentPlayer.x ~= currentPlayer.targetX) or (currentPlayer.y ~= currentPlayer.targetY)

        if not isCurrentPlayerMoving and currentPlayer.pendingAttackKey and not currentPlayer.statusEffects.careening then
            local keyUsed = currentPlayer.pendingAttackKey
            local attackData = CharacterBlueprints[currentPlayer.playerType].attacks[keyUsed]
            local attackCost = attackData and attackData.cost

            if attackCost and (currentPlayer.actionBarCurrent >= currentPlayer.actionBarMax or currentPlayer.continuousAttack) then
                currentPlayer.ai_last_attack_key = keyUsed
                local wasContinuousBefore = currentPlayer.continuousAttack
                Systems.executeAttack(currentPlayer, keyUsed)

                if not (wasContinuousBefore and not currentPlayer.continuousAttack) then
                    currentPlayer.actionBarCurrent = 0
                    currentPlayer.actionBarMax = attackCost
                end
                lastAttackTimestamp = love.timer.getTime()
            end
            currentPlayer.pendingAttackKey = nil
        end
    end
    return lastAttackTimestamp -- Return the potentially updated value
end

return AISystems