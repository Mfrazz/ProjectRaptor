-- main.lua
-- Orchestrator for the Grid Combat game.
-- Loads all modules and runs the main game loop.

-- Load data, modules, and systems
local World = require("modules.world")
EnemyBlueprints = require("data.enemy_blueprints")
Config = require("config")
CharacterBlueprints = require("data.character_blueprints")
EntityFactory = require("data.entities")
local AISystems = require("systems.ai_systems")
local StatusSystem = require("systems.status_system")
local CareeningSystem = require("systems.careening_system")
local StatSystem = require("systems.stat_system")
local ActionBarSystem = require("systems.action_bar_system")
local EffectTimerSystem = require("systems.effect_timer_system")
local ProjectileSystem = require("systems.projectile_system")
local MovementSystem = require("systems.movement_system")
local PlayerAttackSystem = require("systems.player_attack_system")
local PlayerSwitchSystem = require("systems.player_switch_system")
local PassiveSystem = require("systems.passive_system")
local TeamStatusSystem = require("systems.team_status_system")
local AttackResolutionSystem = require("systems.attack_resolution_system")
local ContinuousAttackSystem = require("systems.continuous_attack_system")
local GrappleSystem = require("systems.grapple_system")
local DeathSystem = require("systems.death_system")
local GameTimerSystem = require("systems.game_timer_system")
local WinConditionSystem = require("systems.win_condition_system")
local ActivePlayerValidationSystem = require("systems/active_player_validation_system")
local Renderer = require("modules.renderer")
local CombatActions = require("modules.combat_actions")
local ActivePlayerSyncSystem = require("systems/active_player_sync_system")
local InputHandler = require("modules.input_handler")

world = World.new() -- The single instance of our game world

local canvas
local scale = 1

-- A data-driven list of systems to run in the main update loop.
-- This makes adding, removing, or reordering systems trivial.
-- The order is important: Intent -> Action -> Resolution
local update_systems = {
    -- State and timer updates
    GameTimerSystem,
    StatSystem,
    StatusSystem,
    CareeningSystem,
    ActionBarSystem,
    EffectTimerSystem,
    PassiveSystem,
    ContinuousAttackSystem,
    PlayerSwitchSystem,
    TeamStatusSystem,
    -- Core gameplay actions
    PlayerAttackSystem,
    AISystems,
    MovementSystem,
    ProjectileSystem,
    GrappleSystem,
    AttackResolutionSystem,
    DeathSystem,
}

-- love.load() is called once when the game starts.
-- It's used to initialize game variables and load assets.
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Ensures crisp scaling
    canvas = love.graphics.newCanvas(Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Initialize factories and modules that need a reference to the world
    local EffectFactory = require("modules.effect_factory")
    CombatActions.init(world)
    EffectFactory.init(world)

    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

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
        world.roster[type] = EntityFactory.createSquare(spawnX, spawnY, "player", type)
        i = i + 1
    end

    -- 2. Set up the character grid layout and the initial active party
    local allTypes = {}
    for type, _ in pairs(CharacterBlueprints) do table.insert(allTypes, type) end
    for y = 1, 3 do -- Always create a 3x3 grid
        world.characterGrid[y] = {}
        for x = 1, 3 do
            -- This will place characters and leave remaining slots as nil,
            -- which prevents crashes when the UI tries to access an empty row.
            world.characterGrid[y][x] = table.remove(allTypes, 1)
        end
    end
    -- Build the initial `players` table from the top row of the grid
    for i = 1, 3 do
        local playerType = world.characterGrid[1][i]
        if playerType then
            world:queue_add_entity(world.roster[playerType])
        end
    end

    -- Create enemy squares (light grey)
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 + 100, windowHeight / 2 + 40, "enemy", "brawler"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 - 100, windowHeight / 2 - 80, "enemy", "brawler"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2, windowHeight / 2 + 100, "enemy", "archer"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 - 100, windowHeight / 2 + 100, "enemy", "punter"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 + 100, windowHeight / 2 - 80, "enemy", "archer"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2, windowHeight / 2 - 80, "enemy", "punter"))

    -- Set the background color
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1) -- Dark grey

end

-- love.update(dt) is called every frame.
-- dt is the time elapsed since the last frame (delta time).
-- It's used for game logic, such as updating player positions and attacks.
function love.update(dt)
    -- Only update game logic if not paused
    if world.gameState == "gameplay" then
        -- Handle continuous input first to set player intentions
        InputHandler.handle_movement_input(world)

        -- Main system update loop
        for _, system in ipairs(update_systems) do
            system.update(dt, world)
        end

        -- Process all entity additions and deletions that were queued by the systems.
        world:process_additions_and_deletions()

        -- Run systems that must happen *after* entity deletion
        ActivePlayerValidationSystem.update(world)
        ActivePlayerSyncSystem.update(world)
        WinConditionSystem.update(world)

    end -- End of if world.gameState == "gameplay"
end

-- love.keypressed(key) is used for discrete actions, like switching players or attacking.
function love.keypressed(key)
    -- Pass the current state to the handler and get the new state back.
    world.gameState = InputHandler.handle_key_press(key, world.gameState, world)
end

function love.resize(w, h)
    -- Calculate the new scale factor to fit the virtual resolution inside the new window size, preserving aspect ratio.
    local scaleX = w / Config.VIRTUAL_WIDTH
    local scaleY = h / Config.VIRTUAL_HEIGHT
    -- By flooring the scale factor, we ensure we only scale by whole numbers (1x, 2x, 3x, etc.),
    -- which preserves a perfect pixel grid and eliminates distortion.
    -- We use math.max(1, ...) to prevent the scale from becoming 0 on very small windows.
    scale = math.max(1, math.floor(math.min(scaleX, scaleY)))
end


function love.draw()
    -- 1. Draw the entire game world to the off-screen canvas at its native resolution.
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    Renderer.draw_frame(world)
    love.graphics.setCanvas()

    -- 2. Draw the canvas to the screen, scaled and centered to fit the window.
    -- This creates letterboxing/pillarboxing as needed.
    local w, h = love.graphics.getDimensions()
    local canvasX = (w - Config.VIRTUAL_WIDTH * scale) / 2
    local canvasY = (h - Config.VIRTUAL_HEIGHT * scale) / 2

    love.graphics.draw(canvas, canvasX, canvasY, 0, scale, scale)
end

-- love.quit() is called when the game closes.
-- You can use it to save game state or clean up resources.
function love.quit()
    -- No specific cleanup needed for this simple game.
end
        
