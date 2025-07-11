-- active_player_validation_system.lua
-- Ensures the active player index is always valid after entities are removed.

local ActivePlayerValidationSystem = {}

function ActivePlayerValidationSystem.update(world)
    -- This system doesn't need 'dt'
    if #world.players == 0 then
        world.activePlayerIndex = 0 -- No players left
    elseif world.activePlayerIndex > #world.players then
        world.activePlayerIndex = 1 -- The active player was removed, so reset to the first player.
    end
end

return ActivePlayerValidationSystem