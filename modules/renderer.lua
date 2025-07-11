-- renderer.lua
-- Contains all drawing logic for the game.

local Camera = require("modules.camera")
local Renderer = {}

--------------------------------------------------------------------------------
-- LOCAL DRAWING HELPER FUNCTIONS
-- (Moved from systems.lua)
--------------------------------------------------------------------------------

local function drawHealthBar(square)
    local barWidth, barHeight, barYOffset = square.size, 3, square.size + 2
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, barWidth, barHeight)
    local currentHealthWidth = (square.hp / square.maxHp) * barWidth
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, currentHealthWidth, barHeight)
end

local function drawActionBar(square)
    local barWidth, barHeight, barYOffset = square.size, 3, square.size + 2 + 3 + 2
    love.graphics.setColor(0.3, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, barWidth, barHeight)
    local currentFillWidth = (square.actionBarCurrent / square.actionBarMax) * barWidth
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, currentFillWidth, barHeight)
end

local function draw_entity(entity, world, is_active_player)
    love.graphics.push()
    -- Check for the 'shake' component
    if entity.components.shake then
        local offsetX = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        local offsetY = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        love.graphics.translate(offsetX, offsetY)
    end

    love.graphics.setColor(entity.color) -- Set the square's color
    love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)

    -- Draw status effect overlays
    if entity.statusEffects.stunned then
        love.graphics.setColor(0.5, 0, 0.5, 0.5) -- Semi-transparent purple
        love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)
    elseif entity.statusEffects.paralyzed then
        love.graphics.setColor(1, 1, 0, 0.4) -- Semi-transparent yellow
        love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)
    elseif entity.statusEffects.poison then
        -- Pulsating pink tint for poison
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2 -- Fast pulse (0 to 1)
        local alpha = 0.2 + pulse * 0.3 -- Alpha from 0.2 to 0.5
        love.graphics.setColor(1, 0.4, 0.7, alpha) -- Pink
        love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)
    end

    -- Special drawing logic for specific entity types
    if entity.playerType == "stripedsquare" then
        -- Use a scissor to ensure stripes don't draw outside the square
        love.graphics.setScissor(entity.x, entity.y, entity.size, entity.size)
        love.graphics.setColor(1, 1, 1, 1) -- White stripes
        love.graphics.setLineWidth(2)
        for i = -entity.size, entity.size, 4 do
            love.graphics.line(entity.x + i, entity.y, entity.x + i + entity.size, entity.y + entity.size)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setScissor() -- Disable the scissor
    elseif entity.enemyType == "archer" then
        love.graphics.setColor(0, 0, 0, 1) -- Black letter
        love.graphics.printf("A", entity.x, entity.y + entity.size / 4, entity.size, "center")
    elseif entity.enemyType == "brawler" then
        love.graphics.setColor(0, 0, 0, 1) -- Black letter
        love.graphics.printf("B", entity.x, entity.y + entity.size / 4, entity.size, "center")
    elseif entity.enemyType == "punter" then
        love.graphics.setColor(0, 0, 0, 1) -- Black letter
        love.graphics.printf("P", entity.x, entity.y + entity.size / 4, entity.size, "center")
    end

    -- Draw shield effect for Striped L-Ability
    if entity.shieldEffectTimer and entity.shieldEffectTimer > 0 then
        love.graphics.setColor(0, 1, 0, 0.4) -- Semi-transparent green
        love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)
    end

    -- Draw shield effect for Purple K-Ability
    if entity.components.shielded then
        love.graphics.setColor(0.7, 0.7, 1, 0.8) -- Light blue
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", entity.x - 2, entity.y - 2, entity.size + 4, entity.size + 4)
        love.graphics.setLineWidth(1)
    end

    drawHealthBar(entity)
    drawActionBar(entity)

    -- Draw flash effect if active and flashing (only for players)
    if entity.type == "player" and entity.components.flash then
        local flash = entity.components.flash
        local alpha = flash.timer / Config.FLASH_DURATION -- Fade out effect
        love.graphics.setColor(1, 1, 1, alpha) -- White flash
        local flashX = entity.x - entity.moveStep
        local flashY = entity.y - entity.moveStep
        local flashWidth = entity.size * 3
        local flashHeight = entity.size * 3
        love.graphics.rectangle("fill", flashX, flashY, flashWidth, flashHeight)
    end

    -- If this is the active player, draw a white border around it
    if is_active_player then
        love.graphics.setColor(1, 1, 1, 1) -- White border (R, G, B, Alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", entity.x, entity.y, entity.size, entity.size)
        love.graphics.setLineWidth(1) -- Reset line width
    end

    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

-- This single function draws the entire game state.
-- It receives a `gameState` table containing everything it needs to render.
function Renderer.draw_frame(world)
    -- Apply the camera transform. All subsequent drawing will be in "world space".
    Camera:apply()

    -- Draw afterimage effects
    for _, a in ipairs(world.afterimageEffects) do
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
    for i, p in ipairs(world.players) do
        local is_active = not world.isAutopilotActive and i == world.activePlayerIndex
        draw_entity(p, world, is_active)
    end

    -- Draw all enemies
    for _, e in ipairs(world.enemies) do
        draw_entity(e, world, false) -- Enemies are never the active player
    end

    -- Draw active attack effects (flashing tiles)
    for _, effect in ipairs(world.attackEffects) do
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
    for _, beam in ipairs(world.projectiles) do
        love.graphics.setColor(1, 0, 0, 1) -- Red color for the beam
        love.graphics.rectangle("fill", beam.x, beam.y, beam.size, beam.size)
    end

    -- Draw particle effects
    for _, p in ipairs(world.particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Draw damage popups
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(world.damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end

    -- Draw player switch "comet" effect
    for _, effect in ipairs(world.switchPlayerEffects) do
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

    -- Draw grapple lines
    if #world.grappleLineEffects > 0 then
        love.graphics.setColor(0.6, 0.3, 0.1, 1) -- Brown color for the grapple line
        love.graphics.setLineWidth(2)
        for _, effect in ipairs(world.grappleLineEffects) do
            if effect.attacker and effect.target then
                local x1 = effect.attacker.x + effect.attacker.size / 2
                local y1 = effect.attacker.y + effect.attacker.size / 2
                local x2 = effect.target.x + effect.target.size / 2
                local y2 = effect.target.y + effect.target.size / 2
                love.graphics.line(x1, y1, x2, y2)
            end
        end
        love.graphics.setLineWidth(1) -- Reset line width
    end

    -- Revert the camera transform. All subsequent drawing will be in "screen space" (for UI).
    Camera:revert()


    -- Set the custom font for all UI text. If GameFont is nil, it uses the default.
    if GameFont then
        love.graphics.setFont(GameFont)
    end

    -- UI Drawing
    love.graphics.setColor(1, 1, 1, 1) -- Set color back to white for text

    -- Instructions (Top-Left)
    local instructions = {
        "WASD to move",
        "; to switch",
        "U for Autopilot",
        "J/K/L to Attack"
    }
    local yPos = 10
    for _, line in ipairs(instructions) do
        love.graphics.print(line, 10, yPos)
        yPos = yPos + 20
    end

    -- Player Stats (Below Instructions)
    local yOffset = yPos -- Start right after instructions
    for i, p in ipairs(world.players) do
        love.graphics.print(string.format("P%d (%s): HP=%d/%d Atk=%d Def=%d", i, p.playerType, p.hp, p.maxHp, p.finalAttackStat or 0, p.finalDefenseStat or 0), 10, yOffset)
        yOffset = yOffset + 20
    end

    -- Timer (Top-Right)
    local timerText = "Time: " .. string.format("%.0f", world.gameTimer)
    local timerTextWidth = love.graphics.getFont():getWidth(timerText)
    love.graphics.print(timerText, Config.VIRTUAL_WIDTH - timerTextWidth - 10, 10)

    -- Queued Attacks (Top-Right, below timer)
    do
        local queuedAttackY = 30 -- Start below the timer
        love.graphics.setColor(0, 1, 0, 1) -- Green text
        for _, p in ipairs(world.players) do
            if p.pendingAttackKey then
                local attackData = CharacterBlueprints[p.playerType].attacks[p.pendingAttackKey]
                if attackData then
                    local text = string.format("%s Queued: %s", p.playerType, attackData.name)
                    local textWidth = love.graphics.getFont():getWidth(text)
                    love.graphics.print(text, Config.VIRTUAL_WIDTH - textWidth - 10, queuedAttackY)
                    queuedAttackY = queuedAttackY + 20
                end
            end
        end
    end

    -- Reset color to white for the rest of the UI text
    love.graphics.setColor(1, 1, 1, 1)

    -- Display Autopilot status
    if world.isAutopilotActive then
        love.graphics.setColor(0, 1, 1, 1) -- Cyan
        love.graphics.printf("AUTOPILOT ENGAGED", 0, love.graphics.getHeight() - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1, 1) -- Reset to white
    end

    -- Display PAUSED message and party select screen if game is paused
    if world.gameState == "party_select" then
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
                local playerType = world.characterGrid[y][x]
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
                    if world.selectedSquare and world.selectedSquare.x == x and world.selectedSquare.y == y then
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
        love.graphics.rectangle("line", gridStartX + (world.cursorPos.x - 1) * gridSize, gridStartY + (world.cursorPos.y - 1) * gridSize, gridSize * 0.9, gridSize * 0.9)
        love.graphics.setLineWidth(1)

        -- Reset color to white after drawing the UI to prevent tinting the whole screen
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Renderer