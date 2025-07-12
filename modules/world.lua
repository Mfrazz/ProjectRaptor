-- world.lua
-- The World object is the single source of truth for all entity data and collections.

local EntityFactory = require("data.entities")

local World = {}
World.__index = World

function World.new()
    local self = setmetatable({}, World)
    self.all_entities = {}
    self.players = {}
    self.enemies = {}
    self.projectiles = {}
    self.attackEffects = {}
    self.particleEffects = {}
    self.damagePopups = {}
    self.switchPlayerEffects = {}
    self.grappleLineEffects = {}
    self.new_entities = {}
    self.flag = nil -- Holds the single Sceptile flag object
    self.afterimageEffects = {}
    self.activePlayerIndex = 1
    self.isAutopilotActive = false
    self.gameTimer = 0
    self.isGameTimerFrozen = false
    self.lastAttackTimestamp = 0
    self.playerTeamStatus = {} -- For team-wide status effects like Magnezone Square's L-ability

    -- Game State and UI
    self.gameState = "gameplay"
    self.roster = {}
    self.characterGrid = {}
    self.cursorPos = {x = 1, y = 1}
    self.selectedSquare = nil
    self.playerToKeepActive = nil -- Used to re-select the correct player after a party swap.

    -- A table to hold the state of team-wide passives, calculated once per frame.
    self.passives = {
        electivireActive = false,
        venusaurCritBonus = 0,
        florgesActive = false,
        drapionActive = false,
        tangrowthCareenDouble = false
    }

    -- Define the full roster in a fixed order based on the asset load sequence.
    -- This order determines their position in the party select grid.
    local characterOrder = {
        "drapionsquare", "sceptilesquare", "pidgeotsquare",
        "venusaursquare", "florgessquare", "magnezonesquare",
        "tangrowthsquare", "electiviresquare"
    }

    -- Create all playable characters and store them in the roster.
    -- The roster holds the state of all characters (like HP), even when they are not in the active party.
    -- We create them at a default (0,0) position. Their actual starting positions
    -- will be set when they are added to the active party or swapped in.
    for _, playerType in ipairs(characterOrder) do
        local playerEntity = EntityFactory.createSquare(0, 0, "player", playerType)
        self.roster[playerType] = playerEntity
    end

    -- Define the starting positions for the player party (bottom-middle of the screen).
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
    local playerSpawnYOffset = 5 * Config.MOVE_STEP
    local spawnPositions = {
        {x = windowWidth / 2 - (2 * Config.MOVE_STEP), y = windowHeight / 2 + playerSpawnYOffset}, -- Left
        {x = windowWidth / 2, y = windowHeight / 2 + playerSpawnYOffset},                         -- Center
        {x = windowWidth / 2 + (2 * Config.MOVE_STEP), y = windowHeight / 2 + playerSpawnYOffset}  -- Right
    }

    -- Populate the initial active party with the first 3 characters from the fixed order and place them.
    for i = 1, 3 do
        local playerType = characterOrder[i]
        if playerType then
            local playerEntity = self.roster[playerType]
            local spawnPos = spawnPositions[i]
            playerEntity.x = spawnPos.x
            playerEntity.y = spawnPos.y
            playerEntity.targetX = playerEntity.x
            playerEntity.targetY = playerEntity.y
            self:_add_entity(playerEntity)
        end
    end

    -- Populate the 3x3 character selection grid based on the fixed order.
    local gridX, gridY = 1, 1
    for _, playerType in ipairs(characterOrder) do
        -- Ensure the row exists before trying to add to it.
        if not self.characterGrid[gridY] then self.characterGrid[gridY] = {} end

        self.characterGrid[gridY][gridX] = playerType
        gridX = gridX + 1
        if gridX > 3 then
            gridX = 1
            gridY = gridY + 1
        end
    end

    return self
end

-- Queues a new entity to be added at the end of the frame.
function World:queue_add_entity(entity)
    if not entity then return end
    table.insert(self.new_entities, entity)
end

-- Adds an entity to all relevant lists.
function World:_add_entity(entity)
    if not entity then return end
    -- When an entity is added, it should not be marked for deletion.
    -- This cleans up state from previous removals (e.g. a dead character from the roster being re-added)
    -- and prevents duplication bugs during party swaps.
    entity.isMarkedForDeletion = nil
    table.insert(self.all_entities, entity)
    if entity.type == "player" then
        table.insert(self.players, entity)
    elseif entity.type == "enemy" then
        table.insert(self.enemies, entity)
    elseif entity.type == "projectile" then
        table.insert(self.projectiles, entity)
    end
end

-- Removes an entity from its specific list.
function World:_remove_from_specific_list(entity)
    local list = (entity.type == "player" and self.players) or
                 (entity.type == "enemy" and self.enemies) or
                 (entity.type == "projectile" and self.projectiles)
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == entity then
            table.remove(list, i)
            return
        end
    end
end

-- Processes all additions and deletions at the end of the frame.
function World:process_additions_and_deletions()
    -- Process deletions first
    for i = #self.all_entities, 1, -1 do
        local entity = self.all_entities[i]
        if entity.isMarkedForDeletion then
            self:_remove_from_specific_list(entity)
            table.remove(self.all_entities, i)
        end
    end

    -- Process additions
    for _, entity in ipairs(self.new_entities) do
        self:_add_entity(entity)
    end
    self.new_entities = {} -- Clear the queue
end

return World