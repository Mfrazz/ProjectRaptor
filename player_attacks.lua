-- player_attacks.lua
-- Contains all player attack implementations.
-- This module relies on the global `Systems` table for helper functions,
-- and other global tables like `enemies`, `players`, `Config`, etc.

local PlayerAttacks = {}

PlayerAttacks.patterns = {}

--------------------------------------------------------------------------------
-- ATTACK PATTERN GENERATORS
--------------------------------------------------------------------------------


PlayerAttacks.patterns.cyan_j = function(square)
    local attackOriginX, attackOriginY, attackWidth, attackHeight
    if square.lastDirection == "up" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - Config.MOVE_STEP, square.y - (Config.MOVE_STEP * 2), Config.MOVE_STEP * 3, Config.MOVE_STEP * 2
    elseif square.lastDirection == "down" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - Config.MOVE_STEP, square.y + Config.MOVE_STEP, Config.MOVE_STEP * 3, Config.MOVE_STEP * 2
    elseif square.lastDirection == "left" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - (Config.MOVE_STEP * 2), square.y - Config.MOVE_STEP, Config.MOVE_STEP * 2, Config.MOVE_STEP * 3
    elseif square.lastDirection == "right" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x + Config.MOVE_STEP, square.y - Config.MOVE_STEP, Config.MOVE_STEP * 2, Config.MOVE_STEP * 3
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

PlayerAttacks.patterns.cyan_k = function(square)
    local sx, sy = square.x, square.y
    local step = Config.MOVE_STEP
    local direction = square.lastDirection
    local effects = {}

    local openPincerOffsets = {
        {dx = -2, dy = -1}, {dx = -3, dy = -2}, {dx = -2, dy = -3},
        {dx = 2, dy = -1}, {dx = 3, dy = -2}, {dx = 2, dy = -3},
    }
    local closedPincerOffsets = {
        {dx = -1, dy = -1}, {dx = -2, dy = -2}, {dx = -1, dy = -3},
        {dx = 1, dy = -1}, {dx = 2, dy = -2}, {dx = 1, dy = -3},
        {dx = 0, dy = -1}, {dx = 0, dy = -2}, {dx = 0, dy = -3},
    }

    local function addEffects(offsets, delay)
        for _, offset in ipairs(offsets) do
            local rdx, rdy = offset.dx, offset.dy
            if direction == "down" then rdx, rdy = -offset.dx, -offset.dy
            elseif direction == "right" then rdx, rdy = -offset.dy, offset.dx
            elseif direction == "left" then rdx, rdy = offset.dy, -offset.dx
            end
            local tileX, tileY = sx + rdx * step, sy + rdy * step
            table.insert(effects, {shape = {type = "rect", x = tileX, y = tileY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = delay})
        end
    end

    addEffects(openPincerOffsets, 0)
    addEffects(closedPincerOffsets, 0.08)
    return effects
end

PlayerAttacks.patterns.pink_j = function(square)
    local effects = {}
    for i = 1, 3 do
        local tileX, tileY = square.x, square.y
        if square.lastDirection == "up" then tileY = square.y - Config.MOVE_STEP * i
        elseif square.lastDirection == "down" then tileY = square.y + Config.MOVE_STEP * i
        elseif square.lastDirection == "left" then tileX = square.x - Config.MOVE_STEP * i
        elseif square.lastDirection == "right" then tileX = square.x + Config.MOVE_STEP * i
        end
        table.insert(effects, {shape = {type = "rect", x = tileX, y = tileY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0})
    end
    return effects
end

PlayerAttacks.patterns.pink_k = function(square)
    return PlayerAttacks.patterns.cyan_j(square)
end

PlayerAttacks.patterns.pink_l = function(square)
    local effectSize = Config.MOVE_STEP * 11
    local effectOriginX, effectOriginY = square.x - (Config.MOVE_STEP * 5), square.y - (Config.MOVE_STEP * 5)
    return {{shape = {type = "rect", x = effectOriginX, y = effectOriginY, w = effectSize, h = effectSize}, delay = 0}}
end

PlayerAttacks.patterns.yellow_j = function(square)
    local sx, sy, size = square.x, square.y, square.size
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local attackOriginX, attackOriginY, attackWidth, attackHeight

    if square.lastDirection == "up" then
        attackOriginX, attackOriginY = sx, 0
        attackWidth, attackHeight = size, sy
    elseif square.lastDirection == "down" then
        attackOriginX, attackOriginY = sx, sy + size
        attackWidth, attackHeight = size, windowHeight - (sy + size)
    elseif square.lastDirection == "left" then
        attackOriginX, attackOriginY = 0, sy
        attackWidth, attackHeight = sx, size
    elseif square.lastDirection == "right" then
        attackOriginX, attackOriginY = sx + size, sy
        attackWidth, attackHeight = windowWidth - (sx + size), size
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

PlayerAttacks.patterns.yellow_k = function(square)
    local step = Config.MOVE_STEP
    local rangeOffset = step * 8
    local rippleCenterSize = 4
    local pcx = square.x + square.size / 2
    local pcy = square.y + square.size / 2
    local rippleCenterX, rippleCenterY

    if square.lastDirection == "up" then rippleCenterX, rippleCenterY = pcx, pcy - rangeOffset
    elseif square.lastDirection == "down" then rippleCenterX, rippleCenterY = pcx, pcy + rangeOffset
    elseif square.lastDirection == "left" then rippleCenterX, rippleCenterY = pcx - rangeOffset, pcy
    elseif square.lastDirection == "right" then rippleCenterX, rippleCenterY = pcx + rangeOffset, pcy
    end

    local size1 = rippleCenterSize * step
    local size2 = (rippleCenterSize + 2) * step
    local size3 = (rippleCenterSize + 4) * step

    return {
        {shape = {type = "rect", x = rippleCenterX - size1 / 2, y = rippleCenterY - size1 / 2, w = size1, h = size1}, delay = 0},
        {shape = {type = "rect", x = rippleCenterX - size2 / 2, y = rippleCenterY - size2 / 2, w = size2, h = size2}, delay = Config.FLASH_DURATION},
        {shape = {type = "rect", x = rippleCenterX - size3 / 2, y = rippleCenterY - size3 / 2, w = size3, h = size3}, delay = Config.FLASH_DURATION * 2},
    }
end

PlayerAttacks.patterns.striped_j = function(square)
    local effects = {}
    local directions = {
        {dx = 1, dy = 0}, {dx = 1, dy = 1}, {dx = 0, dy = 1}, {dx = -1, dy = 1},
        {dx = -1, dy = 0}, {dx = -1, dy = -1}, {dx = 0, dy = -1}, {dx = 1, dy = -1}
    }
    local delay = 0
    for _, dir in ipairs(directions) do
        for i = 1, 4 do
            local tileX = square.x + (dir.dx * i * Config.MOVE_STEP)
            local tileY = square.y + (dir.dy * i * Config.MOVE_STEP)
            table.insert(effects, {shape = {type = "rect", x = tileX, y = tileY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = delay})
        end
        delay = delay + 0.04 -- A very short delay between each part of the spin
    end
    return effects
end

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper function to execute attacks based on a pattern generator.
-- This reduces code duplication by handling the common logic of iterating
-- through a pattern's effects and creating the corresponding attack visuals/logic.
local function executePatternAttack(square, power, patternFunc, isHeal, targetType, statusEffect, specialProperties)
    local effects = patternFunc(square)
    local color = isHeal and {0.5, 1, 0.5, 1} or {1, 0, 0, 1}
    targetType = targetType or (isHeal and "all" or "enemy")

    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        Systems.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, square, power, isHeal, targetType, nil, statusEffect, specialProperties)
    end
end

PlayerAttacks.cyan_j = function(square, power)
    local effects = PlayerAttacks.patterns.cyan_j(square)
    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        Systems.addAttackEffect(s.x, s.y, s.w, s.h, {1, 0, 0, 1}, effectData.delay, square, power, false, "enemy", nil, {type = "careening", force = 40})
    end
end

PlayerAttacks.cyan_k = function(square, power)
    local status = {type = "poison", duration = math.huge}
    executePatternAttack(square, power, PlayerAttacks.patterns.cyan_k, false, "enemy", status)
end

PlayerAttacks.cyan_l = function(square, power)
    local closestEnemy, shortestDistanceSq = nil, math.huge
    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 then
            local distSq = (enemy.x - square.x)^2 + (enemy.y - square.y)^2
            if distSq < shortestDistanceSq then
                shortestDistanceSq, closestEnemy = distSq, enemy
            end
        end
    end
    if closestEnemy then
        local teleportX, teleportY = closestEnemy.x, closestEnemy.y
        if closestEnemy.lastDirection == "up" then teleportY = closestEnemy.y + Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "down" then teleportY = closestEnemy.y - Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "left" then teleportX = closestEnemy.x + Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "right" then teleportX = closestEnemy.x - Config.MOVE_STEP
        end
        local windowWidth, windowHeight = love.graphics.getDimensions()
        teleportX = math.max(0, math.min(teleportX, windowWidth - Config.SQUARE_SIZE))
        teleportY = math.max(0, math.min(teleportY, windowHeight - Config.SQUARE_SIZE))
        if not Systems.isTileOccupied(teleportX, teleportY, Config.SQUARE_SIZE, square) then
            square.x, square.y, square.targetX, square.targetY = teleportX, teleportY, teleportX, teleportY
            square.lastDirection = closestEnemy.lastDirection
            local attackX, attackY = square.x, square.y
            if square.lastDirection == "up" then attackY = square.y - Config.MOVE_STEP
            elseif square.lastDirection == "down" then attackY = square.y + Config.MOVE_STEP
            elseif square.lastDirection == "left" then attackX = square.x - Config.MOVE_STEP
            elseif square.lastDirection == "right" then attackX = square.x + Config.MOVE_STEP
            end
            Systems.addAttackEffect(attackX, attackY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {1, 0, 0, 1}, 0, square, power, false, "enemy", 0.2, {type = "stunned", duration = 1})
        end
    end
end

PlayerAttacks.pink_j = function(square, power)
    executePatternAttack(square, power, PlayerAttacks.patterns.pink_j, false, "enemy")
end

PlayerAttacks.pink_k = function(square, power)
    executePatternAttack(square, power, PlayerAttacks.patterns.pink_k, true, "all", nil, {cleansesPoison = true})
end

PlayerAttacks.pink_l = function(square, power)
    local effectSize = Config.MOVE_STEP * 11
    local effectOriginX, effectOriginY = square.x - (Config.MOVE_STEP * 5), square.y - (Config.MOVE_STEP * 5)
    Systems.addAttackEffect(effectOriginX, effectOriginY, effectSize, effectSize, {0, 0, 1, 1}, 0, square, 0, false, "player")
    for _, p in ipairs(players) do
        if p ~= square and p.hp > 0 then
            local pCenterX, pCenterY = p.x + p.size / 2, p.y + p.size / 2
            if pCenterX >= effectOriginX and pCenterX < effectOriginX + effectSize and pCenterY >= effectOriginY and pCenterY < effectOriginY + effectSize then
                p.actionBarCurrent = p.actionBarMax
            end
        end
    end
end

PlayerAttacks.yellow_j = function(square, power)
    table.insert(beamProjectiles, {
        x = square.x, y = square.y, size = Config.SQUARE_SIZE, moveStep = Config.MOVE_STEP, direction = square.lastDirection,
        attacker = square, power = power,
        moveDelay = 0.05, currentTimer = 0.05
    })
end

PlayerAttacks.yellow_k = function(square, power)
    executePatternAttack(square, power, PlayerAttacks.patterns.yellow_k, false, "enemy")
end

PlayerAttacks.yellow_l = function(square, power)
    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 then
            -- Create a 0-power attack effect on each enemy that carries the "paralyzed" status.
            Systems.addAttackEffect(
                enemy.x, enemy.y, enemy.size, enemy.size,
                {1, 1, 0, 0.7}, -- Yellow visual effect
                0, -- delay
                square, -- attacker
                0, -- power
                false, -- isHeal
                "enemy", -- targetType
                nil, -- critChanceOverride
                {type = "paralyzed", duration = 10} -- statusEffect
            )
        end
    end
end

PlayerAttacks.striped_j = function(square, power)
    executePatternAttack(square, power, PlayerAttacks.patterns.striped_j, false, "enemy")
end

PlayerAttacks.striped_k = function(square, power)
    -- Pulls all enemies to be 1 tile away from the square.
    local occupiedDestinations = {}
    local adjacentTiles = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    -- Add a visual effect for the pull
    local effectSize = Config.MOVE_STEP * 7
    Systems.addAttackEffect(square.x - effectSize/2 + square.size/2, square.y - effectSize/2 + square.size/2, effectSize, effectSize, {1, 1, 1, 0.5}, 0, square, 0, false, "enemy")

    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 then
            local foundSpot = false
            for _, tile in ipairs(adjacentTiles) do
                local destX = square.x + tile.dx * Config.MOVE_STEP
                local destY = square.y + tile.dy * Config.MOVE_STEP
                local destKey = destX .. "," .. destY

                if not occupiedDestinations[destKey] and not Systems.isTileOccupied(destX, destY, enemy.size, enemy) then
                    -- Found an empty spot, assign it to the enemy
                    enemy.targetX = destX
                    enemy.targetY = destY
                    occupiedDestinations[destKey] = true -- Mark this spot as taken for this turn
                    foundSpot = true
                    break
                end
            end
        end
    end
end

PlayerAttacks.striped_l = function(square, power)
    -- For the next 3 seconds, all enemy attacks heal players.
    playerTeamStatus.isHealingFromAttacks = true
    playerTeamStatus.timer = 3

    -- Add a visual shield effect on all players
    for _, p in ipairs(players) do
        if p.hp > 0 then
            p.shieldEffectTimer = 3
        end
    end
end

PlayerAttacks.orange_j = function(square, power)
    -- This function toggles the continuous attack state.
    -- The actual attack logic is handled in main.lua's update loop.
    if square.continuousAttack then
        -- If already active, pressing the button again stops it.
        square.continuousAttack = nil
    else
        -- Otherwise, start the attack.
        square.continuousAttack = { name = "random_ripple", timer = 0, power = power }
    end
end

PlayerAttacks.orange_k = function(square, power)
    -- This attack connects all living players with a damaging beam.
    if #players < 2 then return end -- Need at least 2 players to form a line

    local beamThickness = Config.SQUARE_SIZE * 2 -- 2 tiles thick

    -- Create a list of lines to draw between players
    local lines = {}
    for i = 1, #players do
        local p1 = players[i]
        local p2 = players[i % #players + 1] -- Wrap around to form a closed loop
        table.insert(lines, {
            x1 = p1.x + p1.size/2, y1 = p1.y + p1.size/2,
            x2 = p2.x + p2.size/2, y2 = p2.y + p2.size/2
        })
    end

    -- Create a special attack effect to represent the beams
    Systems.addAttackEffect(0, 0, 0, 0, {1, 0, 0, 1}, 0, square, power, false, "enemy", nil, {type = "triangle_beam", lines = lines, thickness = beamThickness})
end

PlayerAttacks.orange_l = function(square, power)
    -- A simple non-damaging dash forward at 2x speed.
    Systems.createDash(square, square.lastDirection, 4, 2)
end

return PlayerAttacks