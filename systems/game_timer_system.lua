-- game_timer_system.lua
-- This system is responsible for updating the main game timer.

local GameTimerSystem = {}

function GameTimerSystem.update(dt, world)
    if not world.isGameTimerFrozen then
        world.gameTimer = world.gameTimer + dt
    end
end

return GameTimerSystem