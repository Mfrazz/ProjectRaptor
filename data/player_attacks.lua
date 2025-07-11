-- player_attacks.lua
-- Contains all player attack implementations.

local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local Navigation = require("modules.navigation")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")

local PlayerAttacks = {}

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
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, square, power, isHeal, targetType, nil, statusEffect, specialProperties)
    end
end

PlayerAttacks.cyan_j = function(square, power, world)
    local effects = AttackPatterns.cyan_j(square)
    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, {1, 0, 0, 1}, effectData.delay, square, power, false, "enemy", nil, {type = "careening", force = 10})
    end
end

PlayerAttacks.cyan_k = function(square, power, world)
    local status = {type = "poison", duration = math.huge}
    executePatternAttack(square, power, AttackPatterns.cyan_k, false, "enemy", status)
end

PlayerAttacks.cyan_l = function(square, power, world)
    local closestEnemy, shortestDistanceSq = nil, math.huge
    for _, enemy in ipairs(world.enemies) do
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
        local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
        teleportX = math.max(0, math.min(teleportX, windowWidth - Config.SQUARE_SIZE))
        teleportY = math.max(0, math.min(teleportY, windowHeight - Config.SQUARE_SIZE))
        if not WorldQueries.isTileOccupied(teleportX, teleportY, Config.SQUARE_SIZE, square, world) then
            square.x, square.y, square.targetX, square.targetY = teleportX, teleportY, teleportX, teleportY
            square.lastDirection = closestEnemy.lastDirection
            local attackX, attackY = square.x, square.y
            if square.lastDirection == "up" then attackY = square.y - Config.MOVE_STEP
            elseif square.lastDirection == "down" then attackY = square.y + Config.MOVE_STEP
            elseif square.lastDirection == "left" then attackX = square.x - Config.MOVE_STEP
            elseif square.lastDirection == "right" then attackX = square.x + Config.MOVE_STEP
            end
            EffectFactory.addAttackEffect(attackX, attackY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {1, 0, 0, 1}, 0, square, power, false, "enemy", 0.2, {type = "stunned", duration = 1})
        end
    end
end

PlayerAttacks.pink_j = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.pink_j, false, "enemy")
end

PlayerAttacks.pink_k = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.pink_k, true, "player", nil, {cleansesPoison = true})
end

PlayerAttacks.pink_l = function(square, power, world)
    local effectSize = Config.MOVE_STEP * 11
    local effectOriginX, effectOriginY = square.x - (Config.MOVE_STEP * 5), square.y - (Config.MOVE_STEP * 5)
    EffectFactory.addAttackEffect(effectOriginX, effectOriginY, effectSize, effectSize, {0, 0, 1, 1}, 0, square, 0, false, "player")
    for _, p in ipairs(world.players) do
        if p ~= square and p.hp > 0 then
            local pCenterX, pCenterY = p.x + p.size / 2, p.y + p.size / 2
            if pCenterX >= effectOriginX and pCenterX < effectOriginX + effectSize and pCenterY >= effectOriginY and pCenterY < effectOriginY + effectSize then
                p.actionBarCurrent = p.actionBarMax
            end
        end
    end
end

PlayerAttacks.yellow_j = function(square, power, world)
    local newProjectile = EntityFactory.createProjectile(square.x, square.y, square.lastDirection, square, power, false, nil)
    world:queue_add_entity(newProjectile)
end

PlayerAttacks.yellow_k = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.yellow_k, false, "enemy")
end

PlayerAttacks.yellow_l = function(square, power, world)
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            -- Create a 0-power attack effect on each enemy that carries the "paralyzed" status.
            EffectFactory.addAttackEffect(
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

PlayerAttacks.striped_j = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.striped_j, false, "enemy")
end

PlayerAttacks.striped_k = function(square, power, world)
    -- Pulls all enemies to be 1 tile away from the square.
    local occupiedDestinations = {}
    local adjacentTiles = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    -- Add a visual effect for the pull
    local effectSize = Config.MOVE_STEP * 7
    EffectFactory.addAttackEffect(square.x - effectSize/2 + square.size/2, square.y - effectSize/2 + square.size/2, effectSize, effectSize, {1, 1, 1, 0.5}, 0, square, 0, false, "enemy")

    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local foundSpot = false
            for _, tile in ipairs(adjacentTiles) do
                local destX = square.x + tile.dx * Config.MOVE_STEP
                local destY = square.y + tile.dy * Config.MOVE_STEP
                local destKey = destX .. "," .. destY

                if not occupiedDestinations[destKey] and not WorldQueries.isTileOccupied(destX, destY, enemy.size, enemy, world) then
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

PlayerAttacks.striped_l = function(square, power, world)
    -- For the next 3 seconds, all enemy attacks heal players.
    world.playerTeamStatus.isHealingFromAttacks = true
    world.playerTeamStatus.timer = 3

    -- Add a visual shield effect on all players
    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            p.shieldEffectTimer = 3
        end
    end
end

PlayerAttacks.orange_j = function(square, power, world)
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

PlayerAttacks.orange_k = function(square, power, world)
    -- This attack connects all living players with a damaging beam.
    if #world.players < 2 then return end -- Need at least 2 players to form a line

    local beamThickness = Config.SQUARE_SIZE * 2 -- 2 tiles thick

    -- Create a list of lines to draw between players
    local lines = {}
    for i = 1, #world.players do
        local p1 = world.players[i]
        local p2 = world.players[i % #world.players + 1] -- Wrap around to form a closed loop
        table.insert(lines, {
            x1 = p1.x + p1.size/2, y1 = p1.y + p1.size/2,
            x2 = p2.x + p2.size/2, y2 = p2.y + p2.size/2
        })
    end

    -- Create a special attack effect to represent the beams
    EffectFactory.addAttackEffect(0, 0, 0, 0, {1, 0, 0, 1}, 0, square, power, false, "enemy", nil, {type = "triangle_beam", lines = lines, thickness = beamThickness})
end

PlayerAttacks.orange_l = function(square, power, world)
    -- A simple non-damaging dash forward at 2x speed.
    Navigation.createDash(square, square.lastDirection, 4, 2, world)
end

PlayerAttacks.purple_j = function(square, power, world)
    local target = nil

    -- Priority 1: Find any careening enemy
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 and enemy.statusEffects.careening then
            target = enemy
            break
        end
    end

    -- Priority 2: If no careening enemy, find the nearest enemy
    if not target then
        local shortestDistSq = math.huge
        for _, enemy in ipairs(world.enemies) do
            if enemy.hp > 0 then
                local distSq = (square.x - enemy.x)^2 + (square.y - enemy.y)^2
                if distSq < shortestDistSq then
                    shortestDistSq, target = distSq, enemy
                end
            end
        end
    end

    if target then
        -- Check if the target was careening, then stop the careen.
        -- This must be done before the collision effect is created to ensure the damage bonus is calculated correctly.
        local wasCareening = target.statusEffects.careening ~= nil
        if wasCareening then
            target.statusEffects.careening = nil
        end

        -- Calculate the midpoint
        local midX = (square.x + target.x) / 2
        local midY = (square.y + target.y) / 2

        -- Set both entities to move towards the midpoint
        square.targetX, square.targetY = midX, midY
        target.targetX, target.targetY = midX, midY

        -- Increase movement speed for the duration of the pull.
        square.speedMultiplier = 2
        target.speedMultiplier = 2

        -- Add a component to the attacker to trigger the collision effect upon arrival.
        square.components.grapple_collision_effect = {
            power = wasCareening and power * 2 or power, -- Double damage if target was careening
            rippleSize = 2,
            statusEffect = {type = "careening", force = 1, attacker = square}
        }

        -- Add a visual effect for the grapple line
        table.insert(world.grappleLineEffects, {attacker = square, target = target, lifetime = math.huge})
    end
end

PlayerAttacks.purple_k = function(square, power, world)
    -- Apply a one-hit shield to all living allies.
    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            p.components.shielded = true
        end
    end
end

PlayerAttacks.purple_l = function(square, power, world)
    -- Part 1: Find the 3 closest enemies.
    local potentialTargets = {}
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local distSq = (square.x - enemy.x)^2 + (square.y - enemy.y)^2
            table.insert(potentialTargets, {enemy = enemy, distSq = distSq})
        end
    end

    -- Sort targets by distance (closest first)
    table.sort(potentialTargets, function(a, b) return a.distSq < b.distSq end)

    -- Get the top 3 targets
    local targets = {}
    for i = 1, math.min(3, #potentialTargets) do
        table.insert(targets, potentialTargets[i].enemy)
    end

    -- Part 2: Pull the selected enemies towards the square.
    local occupiedDestinations = {}
    local adjacentTiles = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    for _, enemy in ipairs(targets) do
        -- Add a temporary visual line for the grapple.
        table.insert(world.grappleLineEffects, {attacker = square, target = enemy, lifetime = 0.5})

        -- If the grappled enemy is careening, stop it.
        if enemy.statusEffects.careening then
            enemy.statusEffects.careening = nil
        end

        local foundSpot = false
        for _, tile in ipairs(adjacentTiles) do
            local destX = square.x + tile.dx * Config.MOVE_STEP
            local destY = square.y + tile.dy * Config.MOVE_STEP
            local destKey = destX .. "," .. destY

            if not occupiedDestinations[destKey] and not WorldQueries.isTileOccupied(destX, destY, enemy.size, enemy, world) then
                enemy.targetX, enemy.targetY = destX, destY
                enemy.speedMultiplier = 2 -- Increase speed for the pull
                occupiedDestinations[destKey] = true
                foundSpot = true
                break
            end
        end
    end

    -- Part 3: If any enemies were actually targeted, add a component to trigger the ripple effect when they arrive.
    if #targets > 0 then
        square.components.mass_grapple_pending = {
            power = power,
            targets = targets,
            statusEffect = {type = "careening", force = 1, attacker = square}
        }
    end
end

return PlayerAttacks