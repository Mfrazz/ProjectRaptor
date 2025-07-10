-- main.lua
-- Orchestrator for the Grid Combat game.
-- Loads all modules and runs the main game loop.

-- Load modules and set up global tables
EnemyBlueprints = require("enemy_blueprints")
Config = require("config")
CharacterBlueprints = require("character_blueprints")
local createSquare = require("entities")
Systems = require("systems")
Systems.attacks = require("player_attacks")
local AISystems = require("ai_systems")

-- Global game state tables (accessible by systems.lua)
players = {}
enemies = {}
attackEffects = {}
beamProjectiles = {}
particleEffects = {}
damagePopups = {}
switchPlayerEffects = {}
afterimageEffects = {}

-- Global game state variables
activePlayerIndex = 1
gameTimer = 0
isGameTimerFrozen = false
isPaused = false
lastAttackTimestamp = 0
isAutopilotActive = false
playerTeamStatus = {} -- For team-wide status effects like Striped Square's L-ability

-- Character Select State
roster = {} -- Holds all possible player characters' states
characterGrid = {} -- 2D table representing the 3x3 character select grid
cursorPos = {x = 1, y = 1} -- Cursor position on the grid (1-based index)
selectedSquare = nil -- Stores {x, y} of the first square selected for a swap in the pause menu

-- love.load() is called once when the game starts.
-- It's used to initialize game variables and load assets.
function love.load()
    love.window.setTitle("Grid Combat (Advanced)")
    local windowWidth, windowHeight = love.graphics.getDimensions()

    local playerSpawnYOffset = 60 + (10 * Config.MOVE_STEP)
    local spawnPositions = {
        {x = windowWidth / 2 - Config.SQUARE_SIZE / 2, y = windowHeight / 2 - Config.SQUARE_SIZE / 2 + playerSpawnYOffset},
        {x = windowWidth / 2 - Config.SQUARE_SIZE / 2 + 60, y = windowHeight / 2 - Config.SQUARE_SIZE / 2 + playerSpawnYOffset},
        {x = windowWidth / 2 - Config.SQUARE_SIZE / 2 - 60, y = windowHeight / 2 - Config.SQUARE_SIZE / 2 + playerSpawnYOffset}
    }

    -- 1. Populate the roster with all possible characters
    local i = 1
    for type, _ in pairs(CharacterBlueprints) do
        -- Assign initial positions only to the first 3 characters for now
        local spawnX = (spawnPositions[i] and spawnPositions[i].x) or -100 -- Off-screen
        local spawnY = (spawnPositions[i] and spawnPositions[i].y) or -100
        roster[type] = createSquare(spawnX, spawnY, "player", type)
        i = i + 1
    end

    -- 2. Set up the character grid layout and the initial active party
    local allTypes = {}
    for type, _ in pairs(CharacterBlueprints) do table.insert(allTypes, type) end
    for y = 1, 3 do -- Always create a 3x3 grid
        characterGrid[y] = {}
        for x = 1, 3 do
            -- This will place characters and leave remaining slots as nil,
            -- which prevents crashes when the UI tries to access an empty row.
            characterGrid[y][x] = table.remove(allTypes, 1)
        end
    end
    -- Build the initial `players` table from the top row of the grid
    for i = 1, 3 do
        local playerType = characterGrid[1][i]
        if playerType then
            table.insert(players, roster[playerType])
        end
    end

    if players[activePlayerIndex] then
        players[activePlayerIndex].flashTimer = Config.FLASH_DURATION
    end

    -- Create enemy squares (light grey)
    enemies[1] = createSquare(windowWidth / 2 + 100, windowHeight / 2 + 40, "enemy", "brawler")
    enemies[2] = createSquare(windowWidth / 2 - 100, windowHeight / 2 - 80, "enemy", "brawler")
    enemies[3] = createSquare(windowWidth / 2, windowHeight / 2 + 100, "enemy", "archer")
    enemies[4] = createSquare(windowWidth / 2 - 100, windowHeight / 2 + 100, "enemy", "punter")
    enemies[5] = createSquare(windowWidth / 2 + 100, windowHeight / 2 - 80, "enemy", "archer")
    enemies[6] = createSquare(windowWidth / 2, windowHeight / 2 - 80, "enemy", "punter")

    -- Set the background color
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1) -- Dark grey

end


-- love.update(dt) is called every frame.
-- dt is the time elapsed since the last frame (delta time).
-- It's used for game logic, such as updating player positions and attacks.
function love.update(dt)
    -- Only update game logic if not paused
    if not isPaused then
        local windowWidth, windowHeight = love.graphics.getDimensions()

        -- Update Game Timer (only if not frozen by enemy death)
        if not isGameTimerFrozen then
            gameTimer = gameTimer + dt
        end

        -- Update Action Bars for all squares
        local allActiveSquares = {}
        for _, p in ipairs(players) do table.insert(allActiveSquares, p) end
        for _, e in ipairs(enemies) do table.insert(allActiveSquares, e) end

        -- Update Status Effects for all squares
        for _, s in ipairs(allActiveSquares) do
            if s.statusEffects then
                for effectType, effectData in pairs(s.statusEffects) do
                    if effectData.duration then
                        effectData.duration = effectData.duration - dt
                        if effectData.duration <= 0 then
                            if effectType == "poison" then
                                s.poisonTickTimer = nil -- Clean up timer when poison expires
                            end
                            s.statusEffects[effectType] = nil -- Remove expired effect
                        end
                    end
                end

                -- Handle poison damage over time
                if s.statusEffects.poison then
                    if not s.poisonTickTimer then s.poisonTickTimer = 0 end
                    s.poisonTickTimer = s.poisonTickTimer + dt
                    if s.poisonTickTimer >= 1 then
                        s.poisonTickTimer = s.poisonTickTimer - 1
                        if s.hp > 0 then
                            s.hp = s.hp - 4
                            if s.hp < 0 then s.hp = 0 end
                            Systems.createDamagePopup(s, 4, false, {0.5, 0, 0.5, 1}) -- Purple poison damage popup
                        end
                    end
                end
            end
        end

        -- Update Continuous Attacks
        for _, p in ipairs(players) do
            if p.continuousAttack then
                if p.continuousAttack.name == "random_ripple" then
                    p.continuousAttack.timer = p.continuousAttack.timer + dt
                    if p.continuousAttack.timer >= 1 then
                        p.continuousAttack.timer = p.continuousAttack.timer - 1
                        -- create random ripple effect
                        local randX = math.random(0, windowWidth)
                        local randY = math.random(0, windowHeight)
                        Systems.createRippleEffect(p, randX, randY, p.continuousAttack.power, 2, "enemy")
                    end
                end
            end
        end

        -- Handle Careening Movement (must happen after status updates, before normal movement)
        for _, s in ipairs(allActiveSquares) do
            if s.statusEffects.careening and s.hp > 0 then
                local effect = s.statusEffects.careening
                if not s.careenMoveTimer then s.careenMoveTimer = 0 end
                s.careenMoveTimer = s.careenMoveTimer + dt

                if s.careenMoveTimer >= 0.05 then -- Move one tile every 0.05s
                    s.careenMoveTimer = 0

                    if effect.force > 0 then
                        local nextX, nextY = s.x, s.y
                        if effect.direction == "up" then nextY = s.y - Config.MOVE_STEP
                        elseif effect.direction == "down" then nextY = s.y + Config.MOVE_STEP
                        elseif effect.direction == "left" then nextX = s.x - Config.MOVE_STEP
                        elseif effect.direction == "right" then nextX = s.x + Config.MOVE_STEP
                        end

                        -- Collision check
                        local hitWall = nextX < 0 or nextX >= windowWidth or nextY < 0 or nextY >= windowHeight
                        local hitTeammate = Systems.isTileOccupiedBySameTeam(nextX, nextY, s.size, s)

                        if hitWall or hitTeammate then
                            -- Stop careening, create ripple
                            Systems.createRippleEffect(effect.attacker, s.x + s.size/2, s.y + s.size/2, 0, 3, "all")
                            s.statusEffects.careening = nil
                        else
                            -- Move to next tile
                            s.x, s.targetX = nextX, nextX
                            s.y, s.targetY = nextY, nextY
                            effect.force = effect.force - 1
                            if effect.force <= 0 then s.statusEffects.careening = nil end
                        end
                    else
                        s.statusEffects.careening = nil -- Force is 0, stop careening
                    end
                end
            end
        end

        for _, s in ipairs(allActiveSquares) do
            if s.hp > 0 and s.actionBarCurrent < s.actionBarMax and not s.statusEffects.stunned and not s.continuousAttack then
                -- If paralyzed, action bar fills at half rate. Stunned prevents fill entirely.
                local effectiveDt = dt
                if s.statusEffects.paralyzed then
                    effectiveDt = dt / 2
                end
                s.actionBarCurrent = s.actionBarCurrent + effectiveDt
                if s.actionBarCurrent > s.actionBarMax then
                    s.actionBarCurrent = s.actionBarMax -- Cap at full
                end
            end
            if s.type == "player" and s.flashTimer > 0 then
                s.flashTimer = s.flashTimer - dt
                if s.flashTimer < 0 then s.flashTimer = 0 end
            end
            -- Update shake timer
            if s.shakeTimer and s.shakeTimer > 0 then
                s.shakeTimer = s.shakeTimer - dt
                if s.shakeTimer < 0 then
                    s.shakeTimer = 0
                    s.shakeIntensity = 0
                end
            end
        end

        -- Update damage popups
        for i = #damagePopups, 1, -1 do
            local p = damagePopups[i]
            p.y = p.y + p.vy * dt
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then
                table.remove(damagePopups, i)
            end
        end

        -- Update particle effects
        for i = #particleEffects, 1, -1 do
            local p = particleEffects[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then
                table.remove(particleEffects, i)
            end
        end

        -- Update afterimage effects
        for i = #afterimageEffects, 1, -1 do
            local a = afterimageEffects[i]
            a.lifetime = a.lifetime - dt
            if a.lifetime <= 0 then
                table.remove(afterimageEffects, i)
            end
        end

        -- Calculate team-wide passives once per frame
        local orangePassiveActive = false
        for _, p in ipairs(players) do
            if p.playerType == "orangesquare" and p.hp > 0 then
                orangePassiveActive = true
                break
            end
        end

        -- Update switch player effects (comet trail)
        for i = #switchPlayerEffects, 1, -1 do
            local effect = switchPlayerEffects[i]

            -- Update the lifetime of trail particles and remove old ones
            for j = #effect.trail, 1, -1 do
                local p = effect.trail[j]
                p.lifetime = p.lifetime - dt
                if p.lifetime <= 0 then table.remove(effect.trail, j) end
            end

            -- If the target player is gone (e.g., died), remove the effect immediately.
            if not effect.targetPlayer or effect.targetPlayer.hp <= 0 then
                table.remove(switchPlayerEffects, i)
            else
                -- Update the target coordinates every frame to follow the player
                local targetX = effect.targetPlayer.x + effect.targetPlayer.size / 2
                local targetY = effect.targetPlayer.y + effect.targetPlayer.size / 2

                -- Move the comet head towards its target
                local dx = targetX - effect.currentX
                local dy = targetY - effect.currentY
                local dist = math.sqrt(dx*dx + dy*dy)

                -- Check for Orange Square's passive before moving the comet
                if orangePassiveActive and dist > 0 then
                    local prevX, prevY = effect.currentX, effect.currentY
                    local moveAmount = effect.speed * dt
                    -- Calculate where the comet *will be* at the end of this frame
                    local nextX = prevX + (dx / dist) * moveAmount
                    local nextY = prevY + (dy / dist) * moveAmount

                    for _, enemy in ipairs(enemies) do
                        if enemy.hp > 0 and Systems.isCircleCollidingWithLine(enemy.x+enemy.size/2, enemy.y+enemy.size/2, enemy.size/2, prevX, prevY, nextX, nextY, 2) then
                            enemy.hp = enemy.hp - 10
                            Systems.createDamagePopup(enemy, 10, false)
                            if enemy.hp < 0 then enemy.hp = 0 end
                        end
                    end
                end

                local moveAmount = effect.speed * dt
                if dist > moveAmount then
                    -- If we are not going to reach the target this frame, move normally.
                    effect.currentX = effect.currentX + (dx / dist) * moveAmount
                    effect.currentY = effect.currentY + (dy / dist) * moveAmount

                    -- Add a new particle to the trail
                    effect.trailTimer = effect.trailTimer + dt
                    if effect.trailTimer >= effect.trailInterval then
                        effect.trailTimer = 0
                        table.insert(effect.trail, {x = effect.currentX, y = effect.currentY, lifetime = 0.25, initialLifetime = 0.25})
                    end
                else
                    -- If we will reach or overshoot the target this frame, remove the effect instantly.
                    table.remove(switchPlayerEffects, i)
                end
            end
        end

        -- Update team-wide status effects
        if playerTeamStatus.timer and playerTeamStatus.timer > 0 then
            playerTeamStatus.timer = playerTeamStatus.timer - dt
            if playerTeamStatus.timer <= 0 then
                playerTeamStatus.isHealingFromAttacks = false
            end
        end

        -- Apply Pinksquare's Passive (HP Regeneration)
        local pinkPassiveActive = false
        for _, p in ipairs(players) do
            if p.playerType == "pinksquare" and p.hp > 0 then
                pinkPassiveActive = true
                break
            end
        end
        
        if pinkPassiveActive then
            for _, p in ipairs(players) do
                if p.hp > 0 then
                    -- Regenerate 3 HP as a whole number increment once per second
                    -- Using a separate timer for discrete regeneration
                    if not p.regenTimer then p.regenTimer = 0 end
                    p.regenTimer = p.regenTimer + dt
                    if p.regenTimer >= 1 then
                        p.hp = math.floor(p.hp + 3) -- Add 3 HP as a whole number
                        if p.hp > p.maxHp then p.hp = p.maxHp end -- Cap at max HP
                        p.regenTimer = p.regenTimer - 1 -- Subtract 1 second from timer
                    end
                end
            end
        end

        -- Update Player Movement Logic
        -- First, handle input for the active player to set a new target
        if activePlayerIndex > 0 and players[activePlayerIndex] then
            local currentPlayer = players[activePlayerIndex]
            local isCurrentPlayerMoving = (currentPlayer.x ~= currentPlayer.targetX) or (currentPlayer.y ~= currentPlayer.targetY)

            -- If not currently moving, check for new input to set a new target
            if not isCurrentPlayerMoving and not currentPlayer.statusEffects.careening then
                local newTargetX = currentPlayer.x
                local newTargetY = currentPlayer.y

                -- Determine potential new target based on input and update lastDirection
                if love.keyboard.isDown("w") then
                    newTargetY = newTargetY - currentPlayer.moveStep
                    currentPlayer.lastDirection = "up"
                elseif love.keyboard.isDown("s") then
                    newTargetY = newTargetY + currentPlayer.moveStep
                    currentPlayer.lastDirection = "down"
                elseif love.keyboard.isDown("a") then
                    newTargetX = newTargetX - currentPlayer.moveStep
                    currentPlayer.lastDirection = "left"
                elseif love.keyboard.isDown("d") then
                    newTargetX = newTargetX + currentPlayer.moveStep
                    currentPlayer.lastDirection = "right"
                end

                -- Clamp the new target position to screen bounds
                newTargetX = math.max(0, math.min(newTargetX, windowWidth - currentPlayer.size))
                newTargetY = math.max(0, math.min(newTargetY, windowHeight - currentPlayer.size))

                -- If a new valid target was determined AND the tile is not occupied, set it
                if (newTargetX ~= currentPlayer.x or newTargetY ~= currentPlayer.y) and
                   not Systems.isTileOccupied(newTargetX, newTargetY, currentPlayer.size, currentPlayer) then
                    currentPlayer.targetX = newTargetX
                    currentPlayer.targetY = newTargetY
                end
            end
        end

        -- Second, update the position of ALL players based on their target
        for _, p in ipairs(players) do
            local oldX, oldY = p.x, p.y
            local wasMoving = (oldX ~= p.targetX) or (oldY ~= p.targetY)

            if wasMoving then
                local moveAmount = (p.speed * (p.speedMultiplier or 1)) * dt
                local epsilon = 3

                if p.x < p.targetX then
                    p.x = p.x + moveAmount
                    if p.x >= p.targetX - epsilon then p.x = p.targetX end
                elseif p.x > p.targetX then
                    p.x = p.x - moveAmount
                    if p.x <= p.targetX + epsilon then p.x = p.targetX end
                end

                if p.y < p.targetY then
                    p.y = p.y + moveAmount
                    if p.y >= p.targetY - epsilon then p.y = p.targetY end
                elseif p.y > p.targetY then
                    p.y = p.y - moveAmount
                    if p.y <= p.targetY + epsilon then p.y = p.y end
                end

                -- Create afterimage based on movement
                p.afterimageTimer = p.afterimageTimer + dt
                if p.afterimageTimer >= 0.05 then
                    p.afterimageTimer = 0
                    table.insert(afterimageEffects, {x = oldX, y = oldY, size = p.size, color = p.color, playerType = p.playerType, lifetime = 0.2, initialLifetime = 0.2})
                end
            end

            local isStillMoving = (p.x ~= p.targetX) or (p.y ~= p.targetY)

            -- If the player was moving but has now stopped, reset their speed multiplier.
            if wasMoving and not isStillMoving then
                p.speedMultiplier = 1
            end
        end

        -- Update and manage attack effects (flashes and damage/healing application)
        for i = #attackEffects, 1, -1 do
            local effect = attackEffects[i]

            if effect.initialDelay > 0 then
                effect.initialDelay = effect.initialDelay - dt
            else
                -- Effect is now active (delay has passed)
                if not effect.effectApplied then
                    -- Determine target collection
                    local targetCollection = {}
                    if effect.targetType == "player" then
                        targetCollection = players
                    elseif effect.targetType == "enemy" then
                        targetCollection = enemies
                    elseif effect.targetType == "all" then
                        for _, p in ipairs(players) do table.insert(targetCollection, p) end
                        for _, e in ipairs(enemies) do table.insert(targetCollection, e) end
                    end

                    -- Apply damage or heal for this effect (only once)
                    local startCol = effect.x
                    local endCol = effect.x + effect.width - 1
                    local startRow = effect.y
                    local endRow = effect.y + effect.height - 1

                    for col = startCol, endCol, Config.MOVE_STEP do
                        for row = startRow, endRow, Config.MOVE_STEP do
                            for _, target in ipairs(targetCollection) do
                                -- Handle special attack effect types
                                if effect.statusEffect and effect.statusEffect.type == "triangle_beam" then
                                    for _, line in ipairs(effect.statusEffect.lines) do
                                        if Systems.isCircleCollidingWithLine(target.x+target.size/2, target.y+target.size/2, target.size/2, line.x1, line.y1, line.x2, line.y2, effect.statusEffect.thickness/2) then
                                            local finalDamage, isCrit = Systems.calculateFinalDamage(effect.attacker, target, effect.power, effect.critChanceOverride)
                                            Systems.applyDamageToTarget(target, target.x, target.y, target.size, finalDamage, isCrit)
                                            -- Break to prevent hitting the same target with multiple beams in one frame
                                            goto next_target
                                        end
                                    end
                                    goto next_target -- Skip normal hitbox check for this target
                                end

                                -- Standard rectangular hitbox check
                                if playerTeamStatus.isHealingFromAttacks and effect.targetType == "player" and not effect.isHeal then
                                local damageToHeal, _ = Systems.calculateFinalDamage(effect.attacker, target, effect.power, effect.critChanceOverride)
                                Systems.applyHealToTarget(target, col, row, target.size, damageToHeal)
                                elseif effect.isHeal then
                                    if Systems.applyHealToTarget(target, col, row, target.size, effect.power) then
                                        -- If the heal was successful, check for special properties like cleansing.
                                        if effect.specialProperties and effect.specialProperties.cleansesPoison then
                                            -- Cleanse poison if the property is set
                                            target.statusEffects.poison = nil
                                        end
                                    end
                                else
                                -- Standard Damage
                                local finalDamage, isCrit = Systems.calculateFinalDamage(effect.attacker, target, effect.power, effect.critChanceOverride)
                                    -- Check for Striped Square's passive damage reduction
                                    if effect.targetType == "player" then
                                        for _, p in ipairs(players) do
                                            if p.playerType == "stripedsquare" and p.hp > 0 then
                                                finalDamage = finalDamage * 0.75
                                                break
                                            end
                                        end
                                    end
                                    if Systems.applyDamageToTarget(target, col, row, target.size, finalDamage, isCrit) then
                                        -- If a hit was registered (even for 0 damage), apply status effect.
                                        if effect.statusEffect then
                                            -- Build the full status data object to apply
                                            local statusData = {
                                                type = effect.statusEffect.type,
                                                duration = effect.statusEffect.duration,
                                                force = effect.statusEffect.force,
                                                attacker = effect.attacker
                                            }

                                            if statusData.type == "careening" then
                                                -- Calculate knockback direction based on hit
                                                local dx = target.x - effect.attacker.x
                                                local dy = target.y - effect.attacker.y
                                                if math.abs(dx) > math.abs(dy) then
                                                    statusData.direction = (dx > 0) and "right" or "left"
                                                else
                                                    statusData.direction = (dy > 0) and "down" or "up"
                                                end
                                            end

                                            Systems.applyStatusEffect(target, statusData)
                                        end
                                    end
                                end
                                ::next_target::
                            end
                        end
                    end
                    effect.effectApplied = true -- Mark effect as applied
                end

                -- Update flash timer
                effect.currentFlashTimer = effect.currentFlashTimer - dt
                if effect.currentFlashTimer <= 0 then
                    table.remove(attackEffects, i) -- Remove effect if its flash timer is up
                end
            end
        end


        -- Update Yellowsquare's beam projectiles
        for i = #beamProjectiles, 1, -1 do
            local beam = beamProjectiles[i]
            if beam then
                local beamMoved = false

                -- Advance beam position
                beam.currentTimer = beam.currentTimer - dt
                if beam.currentTimer <= 0 then
                    if beam.direction == "up" then
                        beam.y = beam.y - beam.moveStep
                    elseif beam.direction == "down" then
                        beam.y = beam.y + beam.moveStep
                    elseif beam.direction == "left" then
                        beam.x = beam.x - beam.moveStep
                    elseif beam.direction == "right" then
                        beam.x = beam.x + beam.moveStep
                    end
                    beam.currentTimer = beam.moveDelay -- Reset timer for next step
                    beamMoved = true
                end

                -- Check for collision with enemies if beam moved
                if beamMoved then
                    local beamHit = false
                    if beam.isEnemyProjectile then
                        -- Check against players
                        for _, player in ipairs(players) do
                            local damage, isCrit = Systems.calculateFinalDamage(beam.attacker, player, beam.power)
                            if Systems.applyDamageToTarget(player, beam.x, beam.y, beam.size, damage, isCrit) then
                                beamHit = true
                                Systems.addAttackEffect(beam.x, beam.y, beam.size, beam.size, {1, 0, 0, 1}, 0, beam.attacker, 0, false, "player")
                                if beam.statusEffect then
                                    Systems.applyStatusEffect(player, beam.statusEffect)
                                end
                                break
                            end
                        end
                    else
                        -- Check against enemies (original logic for player projectiles)
                        for _, enemy in ipairs(enemies) do
                            local damage, isCrit = Systems.calculateFinalDamage(beam.attacker, enemy, beam.power)
                            if Systems.applyDamageToTarget(enemy, beam.x, beam.y, beam.size, damage, isCrit) then
                                beamHit = true
                                -- Add a red flash effect at the hit location
                                Systems.addAttackEffect(beam.x, beam.y, beam.size, beam.size,
                                                {1, 0, 0, 1}, -- Red flash
                                                0, -- initialDelay
                                                beam.attacker, 0,
                                                false, -- isHeal
                                                "enemy" -- targetType (for visual only here)
                                                )
                                break -- Only hit one enemy per beam
                            end
                        end
                    end
                    
                    -- Remove beam if it hit an enemy or went off-screen
                    local windowWidth, windowHeight = love.graphics.getDimensions()
                    local beamOffScreen = beam.x < 0 or beam.x >= windowWidth or beam.y < 0 or beam.y >= windowHeight
                    if beamHit or beamOffScreen then
                        table.remove(beamProjectiles, i)
                    end
                end
            end
        end

-- Update AI Systems
        AISystems.update_player_ai(dt, players, enemies, isAutopilotActive, activePlayerIndex)
        AISystems.update_enemy_ai(dt, players, enemies)
        lastAttackTimestamp = AISystems.update_queued_attacks(players, activePlayerIndex, lastAttackTimestamp)

        -- Check for dead players/enemies and remove them
        for i = #players, 1, -1 do
            if players[i].hp <= 0 then
                players[i].continuousAttack = nil -- Stop continuous attack on death
                Systems.createShatterEffect(players[i].x, players[i].y, players[i].size, players[i].color)
                local wasActive = (i == activePlayerIndex)
                table.remove(players, i)

                if wasActive then
                    -- The active player was removed. If any players are left, point to the
                    -- new player at the same index (or wrap around if it was the last one).
                    if #players > 0 and activePlayerIndex > #players then
                        activePlayerIndex = 1
                    end
                elseif i < activePlayerIndex then
                    -- A non-active player was removed from before the active one, so shift the index.
                    activePlayerIndex = activePlayerIndex - 1
                end
            end
        end

        -- If all players are dead, set activePlayerIndex to 0 to prevent errors
        if #players == 0 then
            activePlayerIndex = 0
        end

        -- Check if all enemies are dead to freeze the timer
        if #enemies == 0 then
            isGameTimerFrozen = true
        else
            isGameTimerFrozen = false
        end

        for i = #enemies, 1, -1 do
            if enemies[i].hp <= 0 then
                Systems.createShatterEffect(enemies[i].x, enemies[i].y, enemies[i].size, enemies[i].color)
                -- Cyan passive: Action Bar Fill on Enemy Death
                local cyanPassiveActive = false
                for _, p in ipairs(players) do
                    if p.playerType == "cyansquare" and p.hp > 0 then
                        cyanPassiveActive = true
                        break
                    end
                end
                if cyanPassiveActive then
                    -- Iterate through all living players and fill their action bars
                    for _, p in ipairs(players) do
                        if p.hp > 0 then
                            p.actionBarCurrent = p.actionBarMax
                        end
                    end
                end
                table.remove(enemies, i)
            end
        end
    end -- End of if not isPaused
end

-- love.keypressed(key) is used for discrete actions, like switching players or attacking.
function love.keypressed(key)
    -- Toggle pause state with Escape key
    if key == "escape" then
        isPaused = not isPaused
        if not isPaused then
            -- Logic to apply changes when unpausing
            local oldPlayerTypes = {}
            for _, p in ipairs(players) do table.insert(oldPlayerTypes, p.playerType) end

            local newPlayerTypes = {}
            for i = 1, 3 do
                if characterGrid[1][i] then table.insert(newPlayerTypes, characterGrid[1][i]) end
            end

            -- Check if the party has changed
            local partyChanged = false
            if #oldPlayerTypes ~= #newPlayerTypes then
                partyChanged = true
            else
                for i = 1, #oldPlayerTypes do
                    if oldPlayerTypes[i] ~= newPlayerTypes[i] then
                        partyChanged = true
                        break
                    end
                end
            end

            if partyChanged then
                local oldPositions = {}
                for _, p in ipairs(players) do table.insert(oldPositions, {x = p.x, y = p.y, targetX = p.targetX, targetY = p.targetY}) end

                -- Rebuild the party, but only with living members
                players = {}
                local livingPlayersInNewParty = {}

                -- First, filter for living characters from the desired new party
                for _, playerType in ipairs(newPlayerTypes) do
                    local playerObject = roster[playerType]
                    if playerObject.hp > 0 then
                        table.insert(livingPlayersInNewParty, playerObject)
                    end
                end

                -- Now, assign positions and build the final players table
                for i, newPlayer in ipairs(livingPlayersInNewParty) do
                    if oldPositions[i] then
                        -- If there was a player in this slot before, use their position.
                        newPlayer.x, newPlayer.y, newPlayer.targetX, newPlayer.targetY = oldPositions[i].x, oldPositions[i].y, oldPositions[i].targetX, oldPositions[i].targetY
                    elseif oldPositions[1] then
                        -- Otherwise, if it's a new character, place them at the first player's position.
                        newPlayer.x, newPlayer.y, newPlayer.targetX, newPlayer.targetY = oldPositions[1].x, oldPositions[1].y, oldPositions[1].targetX, oldPositions[1].targetY
                    else
                        -- As a last resort, if the party was empty, place them in the middle of the screen.
                        local windowWidth, windowHeight = love.graphics.getDimensions()
                        newPlayer.x, newPlayer.y = windowWidth / 2, windowHeight / 2
                        newPlayer.targetX, newPlayer.targetY = newPlayer.x, newPlayer.y
                    end
                    table.insert(players, newPlayer)
                end
            end
        end
        selectedSquare = nil -- Reset selection on pause/unpause
        return
    end

    -- Only allow other key presses if not paused
    if not isPaused then
        -- Prevent attacks if global cooldown is active
        if love.timer.getTime() - lastAttackTimestamp < Config.ATTACK_COOLDOWN_GLOBAL then
            return
        end

        -- Toggle Autopilot
        if key == "u" then
            isAutopilotActive = not isAutopilotActive
            if isAutopilotActive then
                activePlayerIndex = 0 -- No player is controlled
            else
                -- If turning off autopilot, give control to the first player if they exist
                if #players > 0 then
                    activePlayerIndex = 1
                    players[activePlayerIndex].flashTimer = Config.FLASH_DURATION
                else
                    activePlayerIndex = 0
                end
            end
            return -- Consume key press
        end

        -- Switch active player (now on ';')
        if key == ";" and #players > 0 then
            isAutopilotActive = false -- Always turn off autopilot when cycling
            Systems.cycleActivePlayer()
            return -- Consume the key press
        end

        -- Queue or execute attack for active player
        if activePlayerIndex > 0 and players[activePlayerIndex] then
            local currentPlayer = players[activePlayerIndex]
            local isMoving = (currentPlayer.x ~= currentPlayer.targetX) or (currentPlayer.y ~= currentPlayer.targetY)

            local attackData = CharacterBlueprints[currentPlayer.playerType].attacks[key]
            local attackCost = attackData and attackData.cost

            -- Check if action bar is sufficient for the attack
            if attackCost and (currentPlayer.actionBarCurrent >= currentPlayer.actionBarMax or currentPlayer.continuousAttack) and not currentPlayer.statusEffects.stunned and not currentPlayer.statusEffects.careening then
                if key == "j" or key == "k" or key == "l" then
                    if isMoving then
                        -- If moving, queue the attack to execute after movement
                        currentPlayer.pendingAttackKey = key
                    else
                        -- If not moving, execute immediately
                        currentPlayer.ai_last_attack_key = key -- Remember the attack for the AI to repeat
                        local wasContinuousBefore = currentPlayer.continuousAttack
                        Systems.executeAttack(currentPlayer, key)

                        local isStoppingContinuous = wasContinuousBefore and not currentPlayer.continuousAttack
                        if not isStoppingContinuous then -- Don't reset bar if we just stopped a continuous attack
                            currentPlayer.actionBarCurrent = 0
                            currentPlayer.actionBarMax = attackCost
                        end
                        lastAttackTimestamp = love.timer.getTime() -- Record attack time
                    end
                    -- No automatic cycle to next player after attack.
                end
            end
        end
else -- Game is paused, handle character select input
        if key == "w" then cursorPos.y = math.max(1, cursorPos.y - 1)
        elseif key == "s" then cursorPos.y = math.min(3, cursorPos.y + 1)
        elseif key == "a" then cursorPos.x = math.max(1, cursorPos.x - 1)
        elseif key == "d" then cursorPos.x = math.min(3, cursorPos.x + 1)
        elseif key == "j" then
            if not selectedSquare then
                -- Select the first square
                if characterGrid[cursorPos.y] and characterGrid[cursorPos.y][cursorPos.x] then
                    selectedSquare = {x = cursorPos.x, y = cursorPos.y}
                end
            else
                -- Select the second square and perform the swap
                local secondSquareType = characterGrid[cursorPos.y] and characterGrid[cursorPos.y][cursorPos.x]
                if secondSquareType then
                    local firstSquareType = characterGrid[selectedSquare.y][selectedSquare.x]
                    characterGrid[selectedSquare.y][selectedSquare.x] = secondSquareType
                    characterGrid[cursorPos.y][cursorPos.x] = firstSquareType
                end
                selectedSquare = nil -- Reset selection after swap
            end
        end
    end
end



-- love.draw() is called every frame after love.update().
-- It's used to render graphics on the screen.
function love.draw()
    -- Draw afterimage effects
    for _, a in ipairs(afterimageEffects) do
        local alpha = (a.lifetime / a.initialLifetime) * 0.5 -- Max 50% transparent
        love.graphics.setColor(a.color[1], a.color[2], a.color[3], alpha)

        if a.playerType == "stripedsquare" then
            love.graphics.push()
            love.graphics.setScissor(a.x, a.y, a.size, a.size)
            -- Draw base color (black)
            love.graphics.rectangle("fill", a.x, a.y, a.size, a.size)
            -- Draw stripes
            love.graphics.setColor(1, 1, 1, alpha) -- White stripes
            love.graphics.setLineWidth(2)
            for i = -a.size, a.size, 4 do
                love.graphics.line(a.x + i, a.y, a.x + i + a.size, a.y + a.size)
            end
            love.graphics.setLineWidth(1)
            love.graphics.setScissor()
            love.graphics.pop()
        else
            love.graphics.rectangle("fill", a.x, a.y, a.size, a.size)
        end
    end

    -- Draw all players
    for i, p in ipairs(players) do
        love.graphics.push()
        if p.shakeTimer > 0 then
            local offsetX = math.random(-p.shakeIntensity, p.shakeIntensity)
            local offsetY = math.random(-p.shakeIntensity, p.shakeIntensity)
            love.graphics.translate(offsetX, offsetY)
        end

        love.graphics.setColor(p.color) -- Set the square's color
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)

        -- Draw status effect overlays for players
        if p.statusEffects.stunned then
            love.graphics.setColor(0.5, 0, 0.5, 0.5) -- Semi-transparent purple
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        elseif p.statusEffects.paralyzed then
            love.graphics.setColor(1, 1, 0, 0.4) -- Semi-transparent yellow
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        elseif p.statusEffects.poison then
            -- Pulsating pink tint for poison
            local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2 -- Fast pulse (0 to 1)
            local alpha = 0.2 + pulse * 0.3 -- Alpha from 0.2 to 0.5
            love.graphics.setColor(1, 0.4, 0.7, alpha) -- Pink
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        end

        -- Special drawing logic for stripedsquare
        if p.playerType == "stripedsquare" then
            -- Use a scissor to ensure stripes don't draw outside the square
            love.graphics.setScissor(p.x, p.y, p.size, p.size)
            love.graphics.setColor(1, 1, 1, 1) -- White stripes
            love.graphics.setLineWidth(2)
            for i = -p.size, p.size, 4 do
                love.graphics.line(p.x + i, p.y, p.x + i + p.size, p.y + p.size)
            end
            love.graphics.setLineWidth(1)
            -- Disable the scissor so other things can be drawn normally
            love.graphics.setScissor()
        end

        -- Draw shield effect for Striped L-Ability
        if p.shieldEffectTimer and p.shieldEffectTimer > 0 then
            p.shieldEffectTimer = p.shieldEffectTimer - love.timer.getDelta()
            love.graphics.setColor(0, 1, 0, 0.4) -- Semi-transparent green
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        end

        Systems.drawHealthBar(p) -- Draw health bar for player
        Systems.drawActionBar(p) -- Draw action bar for player

        -- Draw flash effect if active and flashing
        if p.flashTimer > 0 then
            local alpha = p.flashTimer / Config.FLASH_DURATION -- Fade out effect
            love.graphics.setColor(1, 1, 1, alpha) -- White flash

            -- Calculate 3x3 grid behind the square for the flash
            local flashX = p.x - p.moveStep
            local flashY = p.y - p.moveStep
            local flashWidth = p.size * 3
            local flashHeight = p.size * 3

            love.graphics.rectangle("fill", flashX, flashY, flashWidth, flashHeight)
        end

        -- If this is the active player, draw a white border around it
        if not isAutopilotActive and i == activePlayerIndex then
            love.graphics.setColor(1, 1, 1, 1) -- White border (R, G, B, Alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", p.x, p.y, p.size, p.size)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        love.graphics.pop()
    end

    -- Draw all enemies
    for _, e in ipairs(enemies) do
        love.graphics.push()
        if e.shakeTimer > 0 then
            local offsetX = math.random(-e.shakeIntensity, e.shakeIntensity)
            local offsetY = math.random(-e.shakeIntensity, e.shakeIntensity)
            love.graphics.translate(offsetX, offsetY)
        end

        love.graphics.setColor(e.color) -- Set the enemy's color (light grey)
        love.graphics.rectangle("fill", e.x, e.y, e.size, e.size)

        if e.enemyType == "archer" then
            love.graphics.setColor(0, 0, 0, 1) -- Black letter
            love.graphics.printf("A", e.x, e.y + e.size / 4, e.size, "center")
        elseif e.enemyType == "brawler" then
            love.graphics.setColor(0, 0, 0, 1) -- Black letter
            love.graphics.printf("B", e.x, e.y + e.size / 4, e.size, "center")
        elseif e.enemyType == "punter" then
            love.graphics.setColor(0, 0, 0, 1) -- Black letter
            love.graphics.printf("P", e.x, e.y + e.size / 4, e.size, "center")
        end

        Systems.drawHealthBar(e) -- Draw health bar for enemy
        Systems.drawActionBar(e) -- Draw action bar for enemy
        -- Draw status effect overlays for enemies
        if e.statusEffects.stunned then
            love.graphics.setColor(0.5, 0, 0.5, 0.5) -- Semi-transparent purple
            love.graphics.rectangle("fill", e.x, e.y, e.size, e.size)
        elseif e.statusEffects.paralyzed then
            love.graphics.setColor(1, 1, 0, 0.4) -- Semi-transparent yellow
            love.graphics.rectangle("fill", e.x, e.y, e.size, e.size)
        elseif e.statusEffects.poison then
            -- Pulsating pink tint for poison
            local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2 -- Fast pulse (0 to 1)
            local alpha = 0.2 + pulse * 0.3 -- Alpha from 0.2 to 0.5
            love.graphics.setColor(1, 0.4, 0.7, alpha) -- Pink
            love.graphics.rectangle("fill", e.x, e.y, e.size, e.size)
        end

        love.graphics.pop()
    end

    -- Draw active attack effects (flashing tiles)
    for i = #attackEffects, 1, -1 do -- Iterate backwards to safely remove elements
        local effect = attackEffects[i]
        -- Only draw if the initial delay has passed
        if effect.initialDelay <= 0 then
            -- Calculate alpha for flashing effect (e.g., fade out)
            local alpha = effect.currentFlashTimer / effect.flashDuration
            love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha) -- Use effect's color
            love.graphics.rectangle("fill", effect.x, effect.y, effect.width, effect.height)
        end

        -- Special drawing for triangle beam
        if effect.statusEffect and effect.statusEffect.type == "triangle_beam" then
            local alpha = effect.currentFlashTimer / effect.flashDuration
            love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha)
            love.graphics.setLineWidth(effect.statusEffect.thickness)
            for _, line in ipairs(effect.statusEffect.lines) do
                love.graphics.line(line.x1, line.y1, line.x2, line.y2)
            end
            love.graphics.setLineWidth(1)
        end
    end

    -- Draw Yellowsquare's beam projectiles
    for _, beam in ipairs(beamProjectiles) do
        love.graphics.setColor(1, 0, 0, 1) -- Red color for the beam
        love.graphics.rectangle("fill", beam.x, beam.y, beam.size, beam.size)
    end

    -- Draw particle effects
    for _, p in ipairs(particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Draw damage popups
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end

    -- Draw player switch "comet" effect
    for _, effect in ipairs(switchPlayerEffects) do
        -- Draw trail
        for _, p in ipairs(effect.trail) do
            local alpha = p.lifetime / p.initialLifetime
            love.graphics.setColor(1, 1, 1, alpha * 0.8)
            love.graphics.circle("fill", p.x, p.y, 4)
        end

        -- Draw head
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", effect.currentX, effect.currentY, 6)
    end


    -- Display instructions and square coordinates
    love.graphics.setColor(1, 1, 1, 1) -- Set color back to white for text
    love.graphics.print("Time: " .. string.format("%.0f", gameTimer), 10, 10) -- Display game timer (whole number)
    love.graphics.print("Active Player: " .. (activePlayerIndex > 0 and players[activePlayerIndex].playerType or "N/A"), 10, 30)
    love.graphics.print("Press WASD to move the active square", 10, 50)
    love.graphics.print("Press ; to switch active square", 10, 70)
    love.graphics.print("Press U to toggle Autopilot", 10, 90)
    love.graphics.print("Press J (Primary), K (Secondary), or L (Tertiary) Attack", 10, 110)

    -- Print X/Y values and HP for all players
    local yOffset = 130
    for i, p in ipairs(players) do
        love.graphics.print(string.format("P%d (%s): HP=%d/%d Atk=%d Def=%d AB=%.1f/%.1f", i, p.playerType, p.hp, p.maxHp, p.attackStat, p.defenseStat, p.actionBarCurrent, p.actionBarMax), 10, yOffset)
        yOffset = yOffset + 20
    end
    -- Print X/Y values and HP for all enemies
    for i, e in ipairs(enemies) do
        local statusText = ""
        if e.statusEffects then
            for effect, data in pairs(e.statusEffects) do
                statusText = statusText .. " (" .. string.upper(effect) .. ")"
            end
        end
        love.graphics.print(string.format("%s %d: HP=%d/%d Atk=%d Def=%d AB=%.1f/%.1f%s", string.upper(e.enemyType), i, e.hp, e.maxHp, e.attackStat, e.defenseStat, e.actionBarCurrent, e.actionBarMax, statusText), 10, yOffset)
        yOffset = yOffset + 20
    end

    -- Display Autopilot status
    if isAutopilotActive then
        love.graphics.setColor(0, 1, 1, 1) -- Cyan
        love.graphics.printf("AUTOPILOT ENGAGED", 0, love.graphics.getHeight() - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1, 1) -- Reset to white
    end

    -- Display PAUSED message and party select screen if game is paused
    if isPaused then
        -- Draw a semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 1, 1, 1) -- White color
  love.graphics.printf("PARTY SELECT", 0, 40, love.graphics.getWidth(), "center")
        love.graphics.printf("Top row is your active party. Use WASD to move and J to swap.", 0, 60, love.graphics.getWidth(), "center")

        -- Draw the character grid
        local gridSize = 80
        local gridStartX = love.graphics.getWidth() / 2 - (gridSize * 1.5)
        local gridStartY = love.graphics.getHeight() / 2 - (gridSize * 1.5)

        for y = 1, 3 do
            for x = 1, 3 do
                local playerType = characterGrid[y][x]
                if playerType then
                    local squareDisplaySize = gridSize * 0.9
                    local squareX = gridStartX + (x - 1) * gridSize
                    local squareY = gridStartY + (y - 1) * gridSize
                    local blueprint = CharacterBlueprints[playerType]
                    love.graphics.setColor(blueprint.color)
                    love.graphics.rectangle("fill", squareX, squareY, squareDisplaySize, squareDisplaySize)

                    -- Draw stripes for stripedsquare on the select screen
                    if playerType == "stripedsquare" then
                        love.graphics.setScissor(squareX, squareY, squareDisplaySize, squareDisplaySize)
                        love.graphics.setColor(1, 1, 1, 1) -- White stripes
                        love.graphics.setLineWidth(4) -- Thicker lines for the UI
                        for i = -squareDisplaySize, squareDisplaySize, 10 do -- Wider spacing for the UI
                            love.graphics.line(squareX + i, squareY, squareX + i + squareDisplaySize, squareY + squareDisplaySize)
                        end
                        love.graphics.setLineWidth(1)
                        love.graphics.setScissor()
                    end

                    -- Draw selection highlight
                    if selectedSquare and selectedSquare.x == x and selectedSquare.y == y then
                        love.graphics.setColor(0, 1, 0, 1) -- Green highlight
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle("line", squareX, squareY, squareDisplaySize, squareDisplaySize)
                        love.graphics.setLineWidth(1)
                    end
                end
            end
        end

        -- Draw the cursor
        love.graphics.setColor(1, 1, 0, 1) -- Yellow cursor
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", gridStartX + (cursorPos.x - 1) * gridSize, gridStartY + (cursorPos.y - 1) * gridSize, gridSize * 0.9, gridSize * 0.9)
        love.graphics.setLineWidth(1)
    end
end

-- love.quit() is called when the game closes.
-- You can use it to save game state or clean up resources.
function love.quit()
    -- No specific cleanup needed for this simple game.
end
