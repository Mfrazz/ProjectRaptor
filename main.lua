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
local Renderer = require("renderer")
local InputHandler = require("input_handler")

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
isGameTimerFrozen = false -- This is fine to keep separate
gameState = "gameplay" -- NEW: "gameplay", "party_select", "dialogue", etc.
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
    if gameState == "gameplay" then
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
                            Systems.createRippleEffect(effect.attacker, s.x + s.size/2, s.y + s.size/2, 10, 3, "all")
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

        InputHandler.handle_movement_input()

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
    end -- End of if gameState == "gameplay"
end

-- love.keypressed(key) is used for discrete actions, like switching players or attacking.
function love.keypressed(key)
    -- Pass the current state to the handler and get the new state back.
    gameState = InputHandler.handle_key_press(key, gameState)
end



function love.draw()
    -- 1. Package all game state data into a single table.
    local gameState = {
        players = players,
        enemies = enemies,
        attackEffects = attackEffects,
        beamProjectiles = beamProjectiles,
        particleEffects = particleEffects,
        damagePopups = damagePopups,
        switchPlayerEffects = switchPlayerEffects,
        afterimageEffects = afterimageEffects,
        activePlayerIndex = activePlayerIndex,
        gameTimer = gameTimer,
        isAutopilotActive = isAutopilotActive,
        isPaused = (gameState ~= "gameplay"), -- The renderer can derive this
        characterGrid = characterGrid,
        cursorPos = cursorPos,
        selectedSquare = selectedSquare
    }

    -- 2. Pass the entire game state to the renderer.
    Renderer.draw_frame(gameState)
end

-- love.quit() is called when the game closes.
-- You can use it to save game state or clean up resources.
function love.quit()
    -- No specific cleanup needed for this simple game.
end
