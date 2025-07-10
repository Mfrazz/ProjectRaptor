-- input_handler.lua
-- Contains all logic for processing player keyboard input.

local InputHandler = {}

--------------------------------------------------------------------------------
-- STATE-SPECIFIC HANDLERS
--------------------------------------------------------------------------------

local stateHandlers = {}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key)
    if love.timer.getTime() - lastAttackTimestamp < Config.ATTACK_COOLDOWN_GLOBAL then
        return -- Do nothing if on global cooldown
    end

    if key == "u" then
        isAutopilotActive = not isAutopilotActive
        if isAutopilotActive then
            activePlayerIndex = 0
        else
            if #players > 0 then
                activePlayerIndex = 1
                players[activePlayerIndex].flashTimer = Config.FLASH_DURATION
            else
                activePlayerIndex = 0
            end
        end
        return
    end

    if key == ";" and #players > 0 then
        isAutopilotActive = false
        Systems.cycleActivePlayer()
        return
    end

    if activePlayerIndex > 0 and players[activePlayerIndex] then
        local currentPlayer = players[activePlayerIndex]
        local isMoving = (currentPlayer.x ~= currentPlayer.targetX) or (currentPlayer.y ~= currentPlayer.targetY)
        local attackData = CharacterBlueprints[currentPlayer.playerType].attacks[key]
        local attackCost = attackData and attackData.cost

        if attackCost and (currentPlayer.actionBarCurrent >= currentPlayer.actionBarMax or currentPlayer.continuousAttack) and not currentPlayer.statusEffects.stunned and not currentPlayer.statusEffects.careening then
            if key == "j" or key == "k" or key == "l" then
                if isMoving then
                    currentPlayer.pendingAttackKey = key
                else
                    currentPlayer.ai_last_attack_key = key
                    local wasContinuousBefore = currentPlayer.continuousAttack
                    Systems.executeAttack(currentPlayer, key)
                    local isStoppingContinuous = wasContinuousBefore and not currentPlayer.continuousAttack
                    if not isStoppingContinuous then
                        currentPlayer.actionBarCurrent = 0
                        currentPlayer.actionBarMax = attackCost
                    end
                    lastAttackTimestamp = love.timer.getTime()
                end
            end
        end
    end
end

-- Handles all input for the party selection menu.
stateHandlers.party_select = function(key)
    if key == "w" then cursorPos.y = math.max(1, cursorPos.y - 1)
    elseif key == "s" then cursorPos.y = math.min(3, cursorPos.y + 1)
    elseif key == "a" then cursorPos.x = math.max(1, cursorPos.x - 1)
    elseif key == "d" then cursorPos.x = math.min(3, cursorPos.x + 1)
    elseif key == "j" then
        if not selectedSquare then
            if characterGrid[cursorPos.y] and characterGrid[cursorPos.y][cursorPos.x] then
                selectedSquare = {x = cursorPos.x, y = cursorPos.y}
            end
        else
            local secondSquareType = characterGrid[cursorPos.y] and characterGrid[cursorPos.y][cursorPos.x]
            if secondSquareType then
                local firstSquareType = characterGrid[selectedSquare.y][selectedSquare.x]
                characterGrid[selectedSquare.y][selectedSquare.x] = secondSquareType
                characterGrid[cursorPos.y][cursorPos.x] = firstSquareType
            end
            selectedSquare = nil
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN HANDLER FUNCTIONS
--------------------------------------------------------------------------------

-- This function handles discrete key presses and delegates to the correct state handler.
function InputHandler.handle_key_press(key, currentGameState)
    -- The Escape key is a global toggle that switches between states.
    if key == "escape" then
        if currentGameState == "gameplay" then
            return "party_select" -- Switch to the menu
        elseif currentGameState == "party_select" then
            -- This is where the logic for applying party changes when unpausing lives now.
            local oldPlayerTypes = {}
            for _, p in ipairs(players) do table.insert(oldPlayerTypes, p.playerType) end
            local newPlayerTypes = {}
            for i = 1, 3 do if characterGrid[1][i] then table.insert(newPlayerTypes, characterGrid[1][i]) end end

            local partyChanged = #oldPlayerTypes ~= #newPlayerTypes
            if not partyChanged then
                for i = 1, #oldPlayerTypes do if oldPlayerTypes[i] ~= newPlayerTypes[i] then partyChanged = true; break end end
            end

            if partyChanged then
                local oldPositions = {}
                for _, p in ipairs(players) do table.insert(oldPositions, {x = p.x, y = p.y, targetX = p.targetX, targetY = p.targetY}) end
                players = {}
                local livingPlayersInNewParty = {}
                for _, playerType in ipairs(newPlayerTypes) do
                    local playerObject = roster[playerType]
                    if playerObject.hp > 0 then table.insert(livingPlayersInNewParty, playerObject) end
                end
                for i, newPlayer in ipairs(livingPlayersInNewParty) do
                    if oldPositions[i] then
                        newPlayer.x, newPlayer.y, newPlayer.targetX, newPlayer.targetY = oldPositions[i].x, oldPositions[i].y, oldPositions[i].targetX, oldPositions[i].targetY
                    elseif oldPositions[1] then
                        newPlayer.x, newPlayer.y, newPlayer.targetX, newPlayer.targetY = oldPositions[1].x, oldPositions[1].y, oldPositions[1].targetX, oldPositions[1].targetY
                    else
                        local w, h = love.graphics.getDimensions()
                        newPlayer.x, newPlayer.y, newPlayer.targetX, newPlayer.targetY = w / 2, h / 2, w / 2, h / 2
                    end
                    table.insert(players, newPlayer)
                end
            end
            selectedSquare = nil -- Reset selection on unpause
            return "gameplay" -- Switch back to gameplay
        end
    end

    -- Find the correct handler for the current state and call it.
    local handler = stateHandlers[currentGameState]
    if handler then
        handler(key)
    end

    -- Return the current state, as no state change was triggered by this key.
    return currentGameState
end

-- This function handles continuous key-down checks for player movement.
-- It's the refactored version of the movement block from love.update.
function InputHandler.handle_movement_input()
    if activePlayerIndex > 0 and players[activePlayerIndex] then
        local currentPlayer = players[activePlayerIndex]
        local windowWidth, windowHeight = love.graphics.getDimensions()

        if (currentPlayer.x == currentPlayer.targetX and currentPlayer.y == currentPlayer.targetY) and not currentPlayer.statusEffects.careening then
            local newTargetX, newTargetY = currentPlayer.x, currentPlayer.y

            if love.keyboard.isDown("w") then
                newTargetY, currentPlayer.lastDirection = newTargetY - currentPlayer.moveStep, "up"
            elseif love.keyboard.isDown("s") then
                newTargetY, currentPlayer.lastDirection = newTargetY + currentPlayer.moveStep, "down"
            elseif love.keyboard.isDown("a") then
                newTargetX, currentPlayer.lastDirection = newTargetX - currentPlayer.moveStep, "left"
            elseif love.keyboard.isDown("d") then
                newTargetX, currentPlayer.lastDirection = newTargetX + currentPlayer.moveStep, "right"
            end

            newTargetX = math.max(0, math.min(newTargetX, windowWidth - currentPlayer.size))
            newTargetY = math.max(0, math.min(newTargetY, windowHeight - currentPlayer.size))

            if (newTargetX ~= currentPlayer.x or newTargetY ~= currentPlayer.y) and not Systems.isTileOccupied(newTargetX, newTargetY, currentPlayer.size, currentPlayer) then
                currentPlayer.targetX, currentPlayer.targetY = newTargetX, newTargetY
            end
        end
    end
end

return InputHandler