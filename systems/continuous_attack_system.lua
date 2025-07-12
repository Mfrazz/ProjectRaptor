-- continuous_attack_system.lua
-- Handles logic for attacks that have an ongoing effect, like Electivire Square's J-ability.

local EffectFactory = require("modules.effect_factory")

local ContinuousAttackSystem = {}

function ContinuousAttackSystem.update(dt, world)
    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

    for _, p in ipairs(world.players) do
        if p.continuousAttack and p.continuousAttack.name == "random_ripple" then
            p.continuousAttack.timer = p.continuousAttack.timer + dt
            if p.continuousAttack.timer >= 1 then
                p.continuousAttack.timer = p.continuousAttack.timer - 1
                local randX = math.random(0, windowWidth)
                local randY = math.random(0, windowHeight)
                EffectFactory.createRippleEffect(p, randX, randY, p.continuousAttack.power, 2, "enemy")
            end
        end
    end
end

return ContinuousAttackSystem