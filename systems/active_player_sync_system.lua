-- active_player_sync_system.lua
-- After a party swap, this system finds the previously active player in the new
-- party list and updates the activePlayerIndex to match.

local ActivePlayerSyncSystem = {}

function ActivePlayerSyncSystem.update(world)
    if world.playerToKeepActive then
        for i, player in ipairs(world.players) do
            if player == world.playerToKeepActive then
                world.activePlayerIndex = i
                break -- Found the player, no need to continue
            end
        end
        -- Clear the temporary variable once the sync is complete
        world.playerToKeepActive = nil
    end
end

return ActivePlayerSyncSystem