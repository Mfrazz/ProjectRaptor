-- systems.lua
-- Contains all the core game logic functions (systems) that operate on game state.
-- It relies on the global tables: Config, CharacterBlueprints, EnemyBlueprints, players, enemies, attackEffects, beamProjectiles.

local Systems = {}
Systems.attacks = {} -- Sub-table to hold player attack implementations
Systems.attackPatterns = {} -- Sub-table to hold hitbox generator functions
Systems.enemyAttacks = {} -- Sub-table to hold enemy attack implementations

--------------------------------------------------------------------------------
-- LOGIC HELPER SYSTEMS
--------------------------------------------------------------------------------

function Systems.applyStatusEffect(target, effectData)
    if target and target.statusEffects and effectData and effectData.type then
        -- This will overwrite any existing effect of the same type.
        -- This is generally desired for things like stun, but might need more
        -- complex logic later for stacking effects.
        target.statusEffects[effectData.type] = effectData
    end
end

function Systems.isTileOccupied(checkX, checkY, checkSize, excludeSquare)
    for _, s in ipairs(players) do
        if s ~= excludeSquare and s.hp > 0 then
            local sCenterX, sCenterY = s.x + s.size / 2, s.y + s.size / 2
            if sCenterX >= checkX and sCenterX < checkX + checkSize and sCenterY >= checkY and sCenterY < checkY + checkSize then
                return true
            end
        end
    end
    for _, s in ipairs(enemies) do
        if s ~= excludeSquare and s.hp > 0 then
            local sCenterX, sCenterY = s.x + s.size / 2, s.y + s.size / 2
            if sCenterX >= checkX and sCenterX < checkX + checkSize and sCenterY >= checkY and sCenterY < checkY + checkSize then
                return true
            end
        end
    end
    return false
end

function Systems.isTileOccupiedBySameTeam(checkX, checkY, checkSize, originalSquare)
    local teamToCheck = (originalSquare.type == "player") and players or enemies
    for _, s in ipairs(teamToCheck) do
        if s ~= originalSquare and s.hp > 0 then
            local sCenterX, sCenterY = s.x + s.size / 2, s.y + s.size / 2
            if sCenterX >= checkX and sCenterX < checkX + checkSize and sCenterY >= checkY and sCenterY < checkY + checkSize then
                return true
            end
        end
    end
    return false
end

function Systems.isTargetInPattern(attacker, patternFunc, targets)
    if not patternFunc or not targets then return false end

    local effects = patternFunc(attacker)
    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        -- Currently, all patterns generate rectangular shapes.
        -- This can be expanded if other shapes are introduced.
        if s.type == "rect" then
            for _, target in ipairs(targets) do
                if target.hp > 0 then
                    local targetCenterX = target.x + target.size / 2
                    local targetCenterY = target.y + target.size / 2
                    if targetCenterX >= s.x and targetCenterX < s.x + s.w and
                       targetCenterY >= s.y and targetCenterY < s.y + s.h then
                        return true -- Found a target within one of the pattern's shapes
                    end
                end
            end
        end
    end
    return false -- No targets were found within the entire pattern
end

function Systems.calculateFinalDamage(attacker, target, power, critChanceOverride)
    -- 1. Calculate crit multiplier
    local critMultiplier = 1
    local isCrit = false
    local effectiveCritChance = Config.BASE_CRIT_CHANCE
    if attacker.type == "player" then
        for _, p in ipairs(players) do
            if p.playerType == "yellowsquare" and p.hp > 0 then
                effectiveCritChance = effectiveCritChance + 0.10
                break
            end
        end
    end
    if critChanceOverride then
        effectiveCritChance = effectiveCritChance + critChanceOverride
    end
    if effectiveCritChance > 1 then effectiveCritChance = 1 end
    if math.random() <= effectiveCritChance then
        critMultiplier = 2
        isCrit = true
    end

    -- 2. Calculate damage based on the formula: Power * (Attack / Defense) * Critical
    local targetDefense = math.max(1, target.defenseStat) -- Prevent division by zero
    local damage = power * (attacker.attackStat / targetDefense) * critMultiplier
    return damage, isCrit
end

function Systems.applyDamageToTarget(targetSquare, hitTileX, hitTileY, hitTileSize, damageAmount, isCrit)
    if targetSquare and targetSquare.hp > 0 then
        local targetCenterX, targetCenterY = targetSquare.x + targetSquare.size / 2, targetSquare.y + targetSquare.size / 2
        if targetCenterX >= hitTileX and targetCenterX < hitTileX + hitTileSize and targetCenterY >= hitTileY and targetCenterY < hitTileY + hitTileSize then
            local roundedDamage = math.floor(damageAmount)
            if roundedDamage > 0 then -- Only apply damage if there is any
                targetSquare.hp = targetSquare.hp - roundedDamage
                Systems.createDamagePopup(targetSquare, roundedDamage, isCrit)
                targetSquare.shakeTimer = 0.2
                targetSquare.shakeIntensity = 2
                if targetSquare.hp < 0 then targetSquare.hp = 0 end
            end
            return true -- A "hit" occurred, even if for 0 damage
        end
    end
    return false
end

function Systems.applyHealToTarget(targetSquare, healTileX, healTileY, healTileSize, healAmount)
    if targetSquare and targetSquare.hp > 0 then
        local targetCenterX, targetCenterY = targetSquare.x + targetSquare.size / 2, targetSquare.y + targetSquare.size / 2
        if targetCenterX >= healTileX and targetCenterX < healTileX + healTileSize and targetCenterY >= healTileY and targetCenterY < healTileY + healTileSize then
            targetSquare.hp = math.floor(targetSquare.hp + healAmount)
            if targetSquare.hp > targetSquare.maxHp then targetSquare.hp = targetSquare.maxHp end
            return true
        end
    end
    return false
end

function Systems.addAttackEffect(effectX, effectY, effectWidth, effectHeight, effectColor, delay, attacker, power, isHeal, targetType, critChanceOverride, statusEffect)
    table.insert(attackEffects, {
        x = effectX, y = effectY, width = effectWidth, height = effectHeight,
        color = effectColor,
        initialDelay = delay,
        currentFlashTimer = Config.FLASH_DURATION,
        flashDuration = Config.FLASH_DURATION,
        attacker = attacker,
        power = power,
        amount = isHeal and power or nil, -- Keep amount for healing logic for now
        critChanceOverride = critChanceOverride,
        isHeal = isHeal,
        effectApplied = false,
        targetType = targetType,
        statusEffect = statusEffect -- e.g., {type="stunned", duration=1}
    })
end

function Systems.createDamagePopup(target, damage, isCrit, colorOverride)
    local popup = {
        text = tostring(damage),
        x = target.x + target.size, -- To the right of the square
        y = target.y,
        vy = -50, -- Moves upwards
        lifetime = 0.7,
        initialLifetime = 0.7,
        color = colorOverride or {1, 0.2, 0.2, 1}, -- Default to bright red
        scale = 1
    }
    if isCrit then
        popup.text = popup.text .. "!"
        popup.color = {1, 1, 0.2, 1} -- Bright yellow
        popup.scale = 1.2 -- Slightly bigger
    end
    table.insert(damagePopups, popup)
end

function Systems.createShatterEffect(x, y, size, color)
    local numParticles = 30
    for i = 1, numParticles do
        table.insert(particleEffects, {
            x = x + size / 2,
            y = y + size / 2,
            size = math.random(1, 3),
            -- Random velocity in any direction
            vx = math.random(-100, 100),
            vy = math.random(-100, 100),
            lifetime = math.random() * 0.5 + 0.2, -- 0.2 to 0.7 seconds
            initialLifetime = 0.5,
            color = color or {0.7, 0.7, 0.7, 1} -- Default to grey
        })
    end
end

function Systems.createRippleEffect(attacker, centerX, centerY, power, rippleCenterSize, targetType)
    local step = Config.MOVE_STEP
    local flashDuration = Config.FLASH_DURATION

    -- First hit
    local size1 = rippleCenterSize * step
    local x1 = centerX - size1 / 2
    local y1 = centerY - size1 / 2
    Systems.addAttackEffect(x1, y1, size1, size1, {1, 0, 0, 1}, 0, attacker, power, false, targetType)

    -- Second hit
    local size2 = (rippleCenterSize + 2) * step
    local x2 = centerX - size2 / 2
    local y2 = centerY - size2 / 2
    Systems.addAttackEffect(x2, y2, size2, size2, {1, 0, 0, 1}, flashDuration, attacker, power, false, targetType)

    -- Third hit
    local size3 = (rippleCenterSize + 4) * step
    local x3 = centerX - size3 / 2
    local y3 = centerY - size3 / 2
    Systems.addAttackEffect(x3, y3, size3, size3, {1, 0, 0, 1}, flashDuration * 2, attacker, power, false, targetType)
end

function Systems.createDash(square, direction, distance, speedMultiplier)
    local finalX, finalY = square.x, square.y
    local step = Config.MOVE_STEP
    local windowWidth, windowHeight = love.graphics.getDimensions()

    for i = 1, distance do
        local nextX, nextY = finalX, finalY
        if direction == "up" then nextY = finalY - step
        elseif direction == "down" then nextY = finalY + step
        elseif direction == "left" then nextX = finalX - step
        elseif direction == "right" then nextX = finalX + step
        end

        -- Check for obstacles (other units or screen bounds)
        local isOutOfBounds = nextX < 0 or nextX >= windowWidth or nextY < 0 or nextY >= windowHeight
        if isOutOfBounds or Systems.isTileOccupied(nextX, nextY, square.size, square) then
            break -- Stop before hitting an obstacle
        end
        finalX, finalY = nextX, nextY
    end
    square.targetX = finalX
    square.targetY = finalY
    square.speedMultiplier = speedMultiplier or 1
end

function Systems.findPath(startSquare, targetSquare)
    local path = {}
    if not startSquare or not targetSquare then return path end

    local step = Config.MOVE_STEP
    local maxTiles = 4 --how far can ai controlled player squares "see" when looking for enemies to attack?
    local maxDist = maxTiles * step

    local dx = targetSquare.x - startSquare.x
    local dy = targetSquare.y - startSquare.y

    -- Only generate a path if the target is within the 5x5 grid.
    if math.abs(dx) > maxDist or math.abs(dy) > maxDist then
        return path -- Return empty path if out of range.
    end

    local currentX, currentY = startSquare.x, startSquare.y

    -- Generate horizontal moves
    local xDir = (dx > 0) and 1 or -1
    -- The '- 1' ensures the path stops one tile before the target,
    -- preventing the AI from trying to step on the enemy's square.
    for i = 1, (math.abs(dx) / step) - 1 do
        local nextX = currentX + xDir * step
        if not Systems.isTileOccupied(nextX, currentY, startSquare.size, startSquare) then
            table.insert(path, {x = nextX, y = currentY})
            currentX = nextX
        else
            return {} -- Path is blocked, give up for now.
        end
    end

    -- Generate vertical moves
    local yDir = (dy > 0) and 1 or -1
    for i = 1, (math.abs(dy) / step) - 1 do
        local nextY = currentY + yDir * step
        if not Systems.isTileOccupied(currentX, nextY, startSquare.size, startSquare) then
            table.insert(path, {x = currentX, y = nextY})
            currentY = nextY
        else
            return {} -- Path is blocked, give up for now.
        end
    end

    return path
end

function Systems.repositionForAttack(square, target)
    if not square or not target then return end

    local step = Config.MOVE_STEP
    local dx = target.x - square.x
    local dy = target.y - square.y

    local preferredMove, fallbackMove

    -- Determine preferred and fallback moves based on distance.
    -- This makes the AI try to close the largest gap first.
    if math.abs(dx) > math.abs(dy) then
        preferredMove = { x = (dx > 0) and step or -step, y = 0 }
        fallbackMove = { x = 0, y = (dy > 0) and step or -step }
    else
        preferredMove = { x = 0, y = (dy > 0) and step or -step }
        fallbackMove = { x = (dx > 0) and step or -step, y = 0 }
    end

    -- Try preferred move
    local nextX, nextY = square.x + preferredMove.x, square.y + preferredMove.y
    if not Systems.isTileOccupied(nextX, nextY, square.size, square) then
        square.targetX, square.targetY = nextX, nextY
        return
    end

    -- Try fallback move if preferred was blocked
    nextX, nextY = square.x + fallbackMove.x, square.y + fallbackMove.y
    if not Systems.isTileOccupied(nextX, nextY, square.size, square) then
        square.targetX, square.targetY = nextX, nextY
    end
end

function Systems.isCircleCollidingWithLine(cx, cy, cr, x1, y1, x2, y2, lineThickness)
    -- Check if the circle's center is close to the line segment
    local dx, dy = x2 - x1, y2 - y1
    local lenSq = dx*dx + dy*dy
    if lenSq == 0 then -- The "line" is a point
        return math.sqrt((cx-x1)^2 + (cy-y1)^2) < cr + lineThickness
    end

    -- Project the circle's center onto the line
    local t = ((cx - x1) * dx + (cy - y1) * dy) / lenSq
    t = math.max(0, math.min(1, t)) -- Clamp to the segment

    -- Find the closest point on the segment to the circle's center
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy

    -- Check the distance from the closest point to the circle's center
    local distSq = (cx - closestX)^2 + (cy - closestY)^2
    return distSq < (cr + lineThickness)^2
end

--------------------------------------------------------------------------------
-- ENEMY ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

Systems.enemyAttacks.standard_melee = function(enemy)
    -- This is the original 3x1 melee attack logic, now modular.
    local attackOriginX, attackOriginY, attackWidth, attackHeight

    if enemy.lastDirection == "up" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - enemy.moveStep, enemy.y - enemy.moveStep, enemy.moveStep * 3, enemy.moveStep * 1
    elseif enemy.lastDirection == "down" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - enemy.moveStep, enemy.y + enemy.moveStep, enemy.moveStep * 3, enemy.moveStep * 1
    elseif enemy.lastDirection == "left" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - enemy.moveStep, enemy.y - enemy.moveStep, enemy.moveStep * 1, enemy.moveStep * 3
    elseif enemy.lastDirection == "right" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x + enemy.moveStep, enemy.y - enemy.moveStep, enemy.moveStep * 1, enemy.moveStep * 3
    end

    -- Check if any player is within the calculated attack area to trigger the attack
    for _, player in ipairs(players) do
        if player.hp > 0 then
            local pCenterX, pCenterY = player.x + player.size / 2, player.y + player.size / 2
            if pCenterX >= attackOriginX and pCenterX < attackOriginX + attackWidth and pCenterY >= attackOriginY and pCenterY < attackOriginY + attackHeight then
                Systems.addAttackEffect(attackOriginX, attackOriginY, attackWidth, attackHeight, {1, 0, 0, 1}, 0, enemy, enemy.attackPower, false, "player")
                enemy.actionBarCurrent = 0
                enemy.attackTimer = enemy.attackDelay
                return -- Attack executed, exit the function
            end
        end
    end
end

Systems.enemyAttacks.archer_shot = function(enemy)
    -- Fires a projectile if a player is aligned in the direction the archer is facing.
    local targetPlayer = nil
    local shortestDistanceSq = math.huge
    if #players > 0 then
        for _, player in ipairs(players) do
            if player.hp > 0 then
                local dx = player.x - enemy.x
                local dy = player.y - enemy.y
                local distSq = dx*dx + dy*dy
                if distSq < shortestDistanceSq then
                    shortestDistanceSq = distSq
                    targetPlayer = player
                end
            end
        end
    end

    if not targetPlayer then return end

    local isAligned = false
    if enemy.lastDirection == "up" and targetPlayer.x == enemy.x and targetPlayer.y < enemy.y then isAligned = true
    elseif enemy.lastDirection == "down" and targetPlayer.x == enemy.x and targetPlayer.y > enemy.y then isAligned = true
    elseif enemy.lastDirection == "left" and targetPlayer.y == enemy.y and targetPlayer.x < enemy.x then isAligned = true
    elseif enemy.lastDirection == "right" and targetPlayer.y == enemy.y and targetPlayer.x > enemy.x then isAligned = true
    end

    if isAligned then
        table.insert(beamProjectiles, {
            x = enemy.x, y = enemy.y, size = Config.SQUARE_SIZE, moveStep = Config.MOVE_STEP, direction = enemy.lastDirection,
            attacker = enemy, power = enemy.attackPower,
            moveDelay = 0.05, currentTimer = 0.05,
            isEnemyProjectile = true -- Flag to identify enemy projectiles
        })
        enemy.actionBarCurrent = 0
        enemy.attackTimer = enemy.attackDelay
    end
end

--------------------------------------------------------------------------------
-- CORE SYSTEMS
--------------------------------------------------------------------------------

function Systems.executeAttack(square, attackKey)
    local blueprint = CharacterBlueprints[square.playerType]
    if not blueprint then return end

    local attackData = blueprint.attacks[attackKey]
    if attackData and attackData.name and Systems.attacks[attackData.name] then
        -- Pass the specific power for this attack to the function
        Systems.attacks[attackData.name](square, attackData.power)
    end
end

function Systems.cycleActivePlayer()
    if #players == 0 then return end -- No players to cycle

    local oldPlayer = players[activePlayerIndex]
    local oldIndex = activePlayerIndex

    activePlayerIndex = activePlayerIndex + 1
    if activePlayerIndex > #players then
        activePlayerIndex = 1
    end

    local newPlayer = players[activePlayerIndex]
    if newPlayer then
        newPlayer.flashTimer = Config.FLASH_DURATION

        -- Only create the comet effect if the player actually changed
        if oldIndex ~= activePlayerIndex and oldPlayer then
            table.insert(switchPlayerEffects, {
                currentX = oldPlayer.x + oldPlayer.size / 2,
                currentY = oldPlayer.y + oldPlayer.size / 2,
                targetPlayer = newPlayer, -- Store a reference to the target player
                speed = 2500, -- Very fast
                trail = {},
                trailTimer = 0,
                trailInterval = 0.005
            })
        end
    end
end

--------------------------------------------------------------------------------
-- DRAWING SYSTEMS
--------------------------------------------------------------------------------

function Systems.drawHealthBar(square)
    local barWidth, barHeight, barYOffset = square.size, 3, square.size + 2
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, barWidth, barHeight)
    local currentHealthWidth = (square.hp / square.maxHp) * barWidth
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, currentHealthWidth, barHeight)
end

function Systems.drawActionBar(square)
    local barWidth, barHeight, barYOffset = square.size, 3, square.size + 2 + 3 + 2
    love.graphics.setColor(0.3, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, barWidth, barHeight)
    local currentFillWidth = (square.actionBarCurrent / square.speedStat) * barWidth
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, currentFillWidth, barHeight)
end

return Systems