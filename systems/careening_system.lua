-- careening_system.lua
-- This system is responsible for updating all entities with the 'careening' status effect.

local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")

local CareeningSystem = {}

function CareeningSystem.update(dt, world)
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

    for _, s in ipairs(world.all_entities) do
        if s.statusEffects and s.statusEffects.careening and s.hp > 0 then
            local effect = s.statusEffects.careening
            if not s.careenMoveTimer then s.careenMoveTimer = 0 end
            s.careenMoveTimer = s.careenMoveTimer + dt

            if s.careenMoveTimer >= 0.05 then -- Move one tile every 0.05s
                s.careenMoveTimer = 0

                if effect.force > 0 then
                    local nextX, nextY = s.x, s.y
                    if effect.direction == "up" then nextY = s.y - Config.MOVE_STEP
                    elseif effect.direction == "down" then nextY = s.y + Config.MOVE_STEP
                    elseif effect.direction == "left" then nextX = s.x - Config.MOVE_STEP
                    elseif effect.direction == "right" then nextX = s.x + Config.MOVE_STEP
                    end

                    -- Collision check
                    local hitWall = nextX < 0 or nextX >= windowWidth or nextY < 0 or nextY >= windowHeight
                    local hitTeammate = WorldQueries.isTileOccupiedBySameTeam(nextX, nextY, s.size, s, world)

                    if hitWall or hitTeammate then
                        EffectFactory.createRippleEffect(effect.attacker, s.x + s.size/2, s.y + s.size/2, 10, 3, "all")
                        s.statusEffects.careening = nil
                    else
                        s.x, s.targetX, s.y, s.targetY = nextX, nextX, nextY, nextY
                        effect.force = effect.force - 1
                        if effect.force <= 0 then s.statusEffects.careening = nil end
                    end
                else
                    s.statusEffects.careening = nil -- Force is 0, stop careening
                end
            end
        end
    end
end

return CareeningSystem