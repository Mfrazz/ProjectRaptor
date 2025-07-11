-- action_bar_system.lua
-- This system is responsible for updating the action bars of all entities.

local ActionBarSystem = {}

local is_initialized = false

local function initialize(world)
    local EventBus = require("modules.event_bus")
    -- Listen for the "enemy_died" event to handle Cyan Square's passive.
    EventBus:register("enemy_died", function(data)
        if world.passives.cyanActive then
            for _, p in ipairs(world.players) do
                if p.hp > 0 then p.actionBarCurrent = p.actionBarMax end
            end
        end
    end)
end

function ActionBarSystem.update(dt, world)
    for _, s in ipairs(world.all_entities) do
        if s.actionBarMax and s.hp > 0 and s.actionBarCurrent < s.actionBarMax and not s.statusEffects.stunned and not s.continuousAttack then
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
    end

    if not is_initialized then
        initialize(world)
        is_initialized = true
    end
end

return ActionBarSystem