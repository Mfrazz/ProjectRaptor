-- attack_patterns.lua
-- A centralized repository for shared attack pattern generators to reduce code duplication.

local AttackPatterns = {}

-- Creates a rectangular pattern from the entity to the edge of the screen.
-- Used by archers, Venusaur Square, etc.
function AttackPatterns.line_of_sight(entity)
    local sx, sy, size = entity.x, entity.y, entity.size
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
    local attackOriginX, attackOriginY, attackWidth, attackHeight

    if entity.lastDirection == "up" then
        attackOriginX, attackOriginY = sx, 0
        attackWidth, attackHeight = size, sy
    elseif entity.lastDirection == "down" then
        attackOriginX, attackOriginY = sx, sy + size
        attackWidth, attackHeight = size, windowHeight - (sy + size)
    elseif entity.lastDirection == "left" then
        attackOriginX, attackOriginY = 0, sy
        attackWidth, attackHeight = sx, size
    elseif entity.lastDirection == "right" then
        attackOriginX, attackOriginY = sx + size, sy
        attackWidth, attackHeight = windowWidth - (sx + size), size
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

-- Creates a pattern of spokes radiating from an entity.
-- Used by Magnezone Square's spin and Punter's spin.
function AttackPatterns.radiating_spokes(entity, distance, spoke_delay)
    local effects = {}
    local directions = {
        {dx = 1, dy = 0}, {dx = 1, dy = 1}, {dx = 0, dy = 1}, {dx = -1, dy = 1},
        {dx = -1, dy = 0}, {dx = -1, dy = -1}, {dx = 0, dy = -1}, {dx = 1, dy = -1}
    }
    local delay = 0
    for _, dir in ipairs(directions) do
        for i = 1, distance do
            local tileX = entity.x + (dir.dx * i * Config.MOVE_STEP)
            local tileY = entity.y + (dir.dy * i * Config.MOVE_STEP)
            table.insert(effects, {shape = {type = "rect", x = tileX, y = tileY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = delay})
        end
        delay = delay + spoke_delay
    end
    return effects
end

-- Creates a 3-stage expanding ripple pattern.
-- Used by Venusaur Square's K-attack and various ripple effects.
function AttackPatterns.ripple(centerX, centerY, rippleCenterSize)
    local step = Config.MOVE_STEP
    local size1 = rippleCenterSize * step
    local size2 = (rippleCenterSize + 2) * step
    local size3 = (rippleCenterSize + 4) * step
    return {
        {shape = {type = "rect", x = centerX - size1 / 2, y = centerY - size1 / 2, w = size1, h = size1}, delay = 0},
        {shape = {type = "rect", x = centerX - size2 / 2, y = centerY - size2 / 2, w = size2, h = size2}, delay = Config.FLASH_DURATION},
        {shape = {type = "rect", x = centerX - size3 / 2, y = centerY - size3 / 2, w = size3, h = size3}, delay = Config.FLASH_DURATION * 2},
    }
end

--------------------------------------------------------------------------------
-- PLAYER ATTACK PATTERNS
--------------------------------------------------------------------------------

function AttackPatterns.drapion_j(square)
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

function AttackPatterns.drapion_k(square)
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

function AttackPatterns.florges_j(square)
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

AttackPatterns.florges_k = AttackPatterns.drapion_j -- Alias

function AttackPatterns.florges_l(square)
    local effectSize = Config.MOVE_STEP * 11
    local effectOriginX, effectOriginY = square.x - (Config.MOVE_STEP * 5), square.y - (Config.MOVE_STEP * 5)
    return {{shape = {type = "rect", x = effectOriginX, y = effectOriginY, w = effectSize, h = effectSize}, delay = 0}}
end

function AttackPatterns.electivire_k(square, world)
    if #world.players < 2 then return {} end
    local beamThickness = Config.SQUARE_SIZE * 2
    local lines = {}
    for i = 1, #world.players do
        local p1 = world.players[i]
        local p2 = world.players[i % #world.players + 1]
        table.insert(lines, {x1 = p1.x + p1.size/2, y1 = p1.y + p1.size/2, x2 = p2.x + p2.size/2, y2 = p2.y + p2.size/2})
    end
    return {{shape = {type = "line_set", lines = lines, thickness = beamThickness}, delay = 0}}
end

function AttackPatterns.magnezone_j(square)
    return AttackPatterns.radiating_spokes(square, 4, 0.04)
end

function AttackPatterns.venusaur_k(square)
    local step = Config.MOVE_STEP
    local rangeOffset = step * 6
    local rippleCenterSize = 1
    local pcx, pcy = square.x + square.size / 2, square.y + square.size / 2
    local rippleCenterX, rippleCenterY

    if square.lastDirection == "up" then rippleCenterX, rippleCenterY = pcx, pcy - rangeOffset
    elseif square.lastDirection == "down" then rippleCenterX, rippleCenterY = pcx, pcy + rangeOffset
    elseif square.lastDirection == "left" then rippleCenterX, rippleCenterY = pcx - rangeOffset, pcy
    elseif square.lastDirection == "right" then rippleCenterX, rippleCenterY = pcx + rangeOffset, pcy
    end

    return AttackPatterns.ripple(rippleCenterX, rippleCenterY, rippleCenterSize)
end

AttackPatterns.venusaur_j = AttackPatterns.line_of_sight -- Alias for projectile attack

--------------------------------------------------------------------------------
-- ENEMY ATTACK PATTERNS
--------------------------------------------------------------------------------

function AttackPatterns.standard_melee(enemy)
    local attackOriginX, attackOriginY, attackWidth, attackHeight
    local step = Config.MOVE_STEP
    if enemy.lastDirection == "up" then attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - step, enemy.y - step, step * 3, step * 1
    elseif enemy.lastDirection == "down" then attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - step, enemy.y + step, step * 3, step * 1
    elseif enemy.lastDirection == "left" then attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x - step, enemy.y - step, step * 1, step * 3
    elseif enemy.lastDirection == "right" then attackOriginX, attackOriginY, attackWidth, attackHeight = enemy.x + step, enemy.y - step, step * 1, step * 3 end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

function AttackPatterns.archer_barrage(enemy)
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
    return {
        {shape = {type = "rect", x = enemy.x, y = 0, w = enemy.size, h = enemy.y}, delay = 0},
        {shape = {type = "rect", x = enemy.x, y = enemy.y + enemy.size, w = enemy.size, h = windowHeight - (enemy.y + enemy.size)}, delay = 0},
        {shape = {type = "rect", x = 0, y = enemy.y, w = enemy.x, h = enemy.size}, delay = 0},
        {shape = {type = "rect", x = enemy.x + enemy.size, y = enemy.y, w = windowWidth - (enemy.x + enemy.size), h = enemy.size}, delay = 0}
    }
end

AttackPatterns.archer_shot = AttackPatterns.line_of_sight -- Alias for projectile attack

function AttackPatterns.punter_spin(entity)
    return AttackPatterns.radiating_spokes(entity, 1, 0.02)
end

return AttackPatterns