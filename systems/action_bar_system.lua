-- action_bar_system.lua
-- This system is responsible for updating the action bars of all entities.

local ActionBarSystem = {}

function ActionBarSystem.update(dt, world)
    -- Check for Sceptile's flag first to determine the buff zone
    local flagZone = nil
    if world.flag then
        local zoneRadiusInTiles = math.floor(world.flag.zoneSize / 2)
        local zoneTopLeftX = world.flag.x - zoneRadiusInTiles * Config.MOVE_STEP
        local zoneTopLeftY = world.flag.y - zoneRadiusInTiles * Config.MOVE_STEP
        local zonePixelSize = world.flag.zoneSize * Config.MOVE_STEP
        flagZone = {
            x1 = zoneTopLeftX,
            y1 = zoneTopLeftY,
            x2 = zoneTopLeftX + zonePixelSize,
            y2 = zoneTopLeftY + zonePixelSize
        }
    end

    for _, s in ipairs(world.all_entities) do
        if s.actionBarMax and s.hp > 0 and not s.statusEffects.stunned and not s.statusEffects.airborne and not s.continuousAttack then
            if s.actionBarCurrent < s.actionBarMax then
                -- If paralyzed, action bar fills at half rate. Stunned prevents fill entirely.
                local effectiveDt = dt
                if s.statusEffects.paralyzed then
                    effectiveDt = dt / 2
                end

                -- Apply Sceptile's flag buff if the player is inside the zone
                if s.type == "player" and flagZone then
                    local pCenterX, pCenterY = s.x + s.size / 2, s.y + s.size / 2
                    if pCenterX >= flagZone.x1 and pCenterX < flagZone.x2 and pCenterY >= flagZone.y1 and pCenterY < flagZone.y2 then
                        effectiveDt = effectiveDt * 1.33
                    end
                end

                s.actionBarCurrent = s.actionBarCurrent + effectiveDt
                if s.actionBarCurrent >= s.actionBarMax then
                    s.actionBarCurrent = s.actionBarMax -- Cap at full
                    s.components.actionBarReady = true -- Set the flag for the visual effect
                end
            end
        end
    end
end

return ActionBarSystem