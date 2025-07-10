-- renderer.lua
-- Contains all drawing logic for the game.

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

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

-- This single function draws the entire game state.
-- It receives a `gameState` table containing everything it needs to render.
function Renderer.draw_frame(gameState)
    -- Draw afterimage effects
    for _, a in ipairs(gameState.afterimageEffects) do
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
    for i, p in ipairs(gameState.players) do
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

        drawHealthBar(p) -- Draw health bar for player
        drawActionBar(p) -- Draw action bar for player

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
        if not gameState.isAutopilotActive and i == gameState.activePlayerIndex then
            love.graphics.setColor(1, 1, 1, 1) -- White border (R, G, B, Alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", p.x, p.y, p.size, p.size)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        love.graphics.pop()
    end

    -- Draw all enemies
    for _, e in ipairs(gameState.enemies) do
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

        drawHealthBar(e) -- Draw health bar for enemy
        drawActionBar(e) -- Draw action bar for enemy
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
    for i = #gameState.attackEffects, 1, -1 do -- Iterate backwards to safely remove elements
        local effect = gameState.attackEffects[i]
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
    for _, beam in ipairs(gameState.beamProjectiles) do
        love.graphics.setColor(1, 0, 0, 1) -- Red color for the beam
        love.graphics.rectangle("fill", beam.x, beam.y, beam.size, beam.size)
    end

    -- Draw particle effects
    for _, p in ipairs(gameState.particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Draw damage popups
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(gameState.damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end

    -- Draw player switch "comet" effect
    for _, effect in ipairs(gameState.switchPlayerEffects) do
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
    love.graphics.print("Time: " .. string.format("%.0f", gameState.gameTimer), 10, 10) -- Display game timer (whole number)
    love.graphics.print("Active Player: " .. (gameState.activePlayerIndex > 0 and gameState.players[gameState.activePlayerIndex].playerType or "N/A"), 10, 30)
    love.graphics.print("Press WASD to move the active square", 10, 50)
    love.graphics.print("Press ; to switch active square", 10, 70)
    love.graphics.print("Press U to toggle Autopilot", 10, 90)
    love.graphics.print("Press J (Primary), K (Secondary), or L (Tertiary) Attack", 10, 110)

    -- Print X/Y values and HP for all players
    local yOffset = 130
    for i, p in ipairs(gameState.players) do
        love.graphics.print(string.format("P%d (%s): HP=%d/%d Atk=%d Def=%d AB=%.1f/%.1f", i, p.playerType, p.hp, p.maxHp, p.attackStat, p.defenseStat, p.actionBarCurrent, p.actionBarMax), 10, yOffset)
        yOffset = yOffset + 20
    end
    -- Print X/Y values and HP for all enemies
    for i, e in ipairs(gameState.enemies) do
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
    if gameState.isAutopilotActive then
        love.graphics.setColor(0, 1, 1, 1) -- Cyan
        love.graphics.printf("AUTOPILOT ENGAGED", 0, love.graphics.getHeight() - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1, 1) -- Reset to white
    end

    -- Display PAUSED message and party select screen if game is paused
    if gameState.isPaused then
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
                local playerType = gameState.characterGrid[y][x]
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
                    if gameState.selectedSquare and gameState.selectedSquare.x == x and gameState.selectedSquare.y == y then
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
        love.graphics.rectangle("line", gridStartX + (gameState.cursorPos.x - 1) * gridSize, gridStartY + (gameState.cursorPos.y - 1) * gridSize, gridSize * 0.9, gridSize * 0.9)
        love.graphics.setLineWidth(1)
    end
end

return Renderer