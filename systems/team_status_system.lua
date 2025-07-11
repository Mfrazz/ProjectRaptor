-- team_status_system.lua
-- Manages team-wide status effects, like Striped Square's L-ability.

local TeamStatusSystem = {}

function TeamStatusSystem.update(dt, world)
    if world.playerTeamStatus.timer and world.playerTeamStatus.timer > 0 then
        world.playerTeamStatus.timer = world.playerTeamStatus.timer - dt
        if world.playerTeamStatus.timer <= 0 then
            world.playerTeamStatus.isHealingFromAttacks = false
        end
    end
end

return TeamStatusSystem