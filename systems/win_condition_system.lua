-- win_condition_system.lua
-- This system checks for win/loss conditions, like all enemies being defeated.

local WinConditionSystem = {}

function WinConditionSystem.update(world)
    -- This system doesn't use dt.
    world.isGameTimerFrozen = (#world.enemies == 0)
end

return WinConditionSystem