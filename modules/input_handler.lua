-- input_handler.lua
-- Contains all logic for processing player keyboard input.

local WorldQueries = require("modules.world_queries")

local InputHandler = {}

--------------------------------------------------------------------------------
-- STATE-SPECIFIC HANDLERS
--------------------------------------------------------------------------------

local stateHandlers = {}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key, world)
    if love.timer.getTime() - world.lastAttackTimestamp < Config.ATTACK_COOLDOWN_GLOBAL then
        return -- Do nothing if on global cooldown
    end

    if key == "u" then
        world.isAutopilotActive = not world.isAutopilotActive
        if world.isAutopilotActive then
            world.activePlayerIndex = 0
        else
            if #world.players > 0 then
                world.activePlayerIndex = 1
                world.players[world.activePlayerIndex].components.flash = { timer = Config.FLASH_DURATION }
            else
                world.activePlayerIndex = 0
            end
        end
        return
    end

    if key == ";" and #world.players > 0 then
        world.isAutopilotActive = false

        local oldPlayer = world.players[world.activePlayerIndex]
        local oldIndex = world.activePlayerIndex

        world.activePlayerIndex = world.activePlayerIndex + 1
        if world.activePlayerIndex > #world.players then
            world.activePlayerIndex = 1
        end

        local newPlayer = world.players[world.activePlayerIndex]
        if newPlayer then
            newPlayer.components.flash = { timer = Config.FLASH_DURATION }

            -- Only create the comet effect if the player actually changed
            if oldIndex ~= world.activePlayerIndex and oldPlayer then
                table.insert(world.switchPlayerEffects, {
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
        return -- End the handler here
    end

    if world.activePlayerIndex > 0 and world.players[world.activePlayerIndex] then
        local currentPlayer = world.players[world.activePlayerIndex]
        local isMoving = (currentPlayer.x ~= currentPlayer.targetX) or (currentPlayer.y ~= currentPlayer.targetY)
        local attackData = CharacterBlueprints[currentPlayer.playerType].attacks[key]

        -- Check if the key corresponds to a valid attack and the player isn't stunned/careening.
        -- Also, only allow one move to be queued at a time.
        if attackData and not currentPlayer.pendingAttackKey and not currentPlayer.statusEffects.stunned and not currentPlayer.statusEffects.careening then
            -- Queue the attack. The PlayerAttackSystem will execute it when ready.
            currentPlayer.pendingAttackKey = key
        end
    end
end

-- Handles all input for the party selection menu.
stateHandlers.party_select = function(key, world)
    if key == "w" then world.cursorPos.y = math.max(1, world.cursorPos.y - 1)
    elseif key == "s" then world.cursorPos.y = math.min(3, world.cursorPos.y + 1)
    elseif key == "a" then world.cursorPos.x = math.max(1, world.cursorPos.x - 1)
    elseif key == "d" then world.cursorPos.x = math.min(3, world.cursorPos.x + 1)
    elseif key == "j" then
        if not world.selectedSquare then
            if world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x] then
                world.selectedSquare = {x = world.cursorPos.x, y = world.cursorPos.y}
            end
        else
            local secondSquareType = world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x]
            if secondSquareType then
                local firstSquareType = world.characterGrid[world.selectedSquare.y][world.selectedSquare.x]
                world.characterGrid[world.selectedSquare.y][world.selectedSquare.x] = secondSquareType
                world.characterGrid[world.cursorPos.y][world.cursorPos.x] = firstSquareType
            end
            world.selectedSquare = nil
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN HANDLER FUNCTIONS
--------------------------------------------------------------------------------

-- This function handles discrete key presses and delegates to the correct state handler.
function InputHandler.handle_key_press(key, currentGameState, world)
    -- Global keybinds that should work in any state
    if key == "f11" then
        local isFullscreen, fstype = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen, fstype)
    end

    -- The Escape key is a global toggle that switches between states.
    if key == "escape" then
        if currentGameState == "gameplay" then
            return "party_select" -- Switch to the menu
        elseif currentGameState == "party_select" then
            -- This is where the logic for applying party changes when unpausing lives now.
            local oldPlayerTypes = {}
            for _, p in ipairs(world.players) do table.insert(oldPlayerTypes, p.playerType) end
            local newPlayerTypes = {}
            for i = 1, 3 do if world.characterGrid[1][i] then table.insert(newPlayerTypes, world.characterGrid[1][i]) end end

            local partyChanged = #oldPlayerTypes ~= #newPlayerTypes
            if not partyChanged then
                for i = 1, #oldPlayerTypes do if oldPlayerTypes[i] ~= newPlayerTypes[i] then partyChanged = true; break end end
            end

            if partyChanged then
                -- Store the player object that should remain active after the swap
                if world.activePlayerIndex > 0 and world.players[world.activePlayerIndex] then
                    world.playerToKeepActive = world.players[world.activePlayerIndex]
                end

                -- Store the positions of the current party members to assign to the new party
                local oldPositions = {}
                for _, p in ipairs(world.players) do
                    table.insert(oldPositions, {x = p.x, y = p.y, targetX = p.targetX, targetY = p.targetY})
                end

                -- Mark all current players for deletion
                for _, p in ipairs(world.players) do
                    p.isMarkedForDeletion = true
                end

                -- Queue the new party members for addition
                for i, playerType in ipairs(newPlayerTypes) do
                    local playerObject = world.roster[playerType]
                    -- We only add them if they are alive. The roster preserves their state (HP, etc.)
                    if playerObject.hp > 0 then
                        -- Assign the position of the player being replaced. This prevents new members from spawning off-screen.
                        if oldPositions[i] then
                            playerObject.x, playerObject.y, playerObject.targetX, playerObject.targetY = oldPositions[i].x, oldPositions[i].y, oldPositions[i].targetX, oldPositions[i].targetY
                        end

                        world:queue_add_entity(playerObject)
                    end
                end
            end
            world.selectedSquare = nil -- Reset selection on unpause
            return "gameplay" -- Switch back to gameplay
        end
    end

    -- Find the correct handler for the current state and call it.
    local handler = stateHandlers[currentGameState]
    if handler then
        handler(key, world)
    end

    -- Return the current state, as no state change was triggered by this key.
    return currentGameState
end

-- This function handles continuous key-down checks for player movement.
-- It's the refactored version of the movement block from love.update.
function InputHandler.handle_movement_input(world)
    if world.activePlayerIndex > 0 and world.players[world.activePlayerIndex] then
        local currentPlayer = world.players[world.activePlayerIndex]
        local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

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

            if (newTargetX ~= currentPlayer.x or newTargetY ~= currentPlayer.y) and not WorldQueries.isTileOccupied(newTargetX, newTargetY, currentPlayer.size, currentPlayer, world) then
                currentPlayer.targetX, currentPlayer.targetY = newTargetX, newTargetY
            end
        end
    end
end

return InputHandler