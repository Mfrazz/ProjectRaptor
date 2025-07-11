-- passive_system.lua
-- Manages team-wide passive abilities.

local Geometry = require("modules.geometry")
local EffectFactory = require("modules.effect_factory")
local CombatActions = require("modules.combat_actions")

local PassiveSystem = {}

-- This system updates the state of team-wide passives and applies their continuous effects.
function PassiveSystem.update(dt, world)
    -- 1. Update passive states
    world.passives.orangeActive = false
    world.passives.yellowCritBonus = 0
    world.passives.pinkActive = false
    world.passives.cyanActive = false
    world.passives.purpleCareenDouble = false

    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            local blueprint = CharacterBlueprints[p.playerType]
            if blueprint and blueprint.passive == "orange_comet_damage" then
                world.passives.orangeActive = true
            elseif blueprint and blueprint.passive == "yellow_crit_bonus" then
                world.passives.yellowCritBonus = 0.10
            elseif blueprint and blueprint.passive == "pink_regen" then
                world.passives.pinkActive = true
            elseif blueprint and blueprint.passive == "cyan_action_on_kill" then
                world.passives.cyanActive = true
            elseif blueprint and blueprint.passive == "purple_careen_double" then
                world.passives.purpleCareenDouble = true
            end
        end
    end

    -- 2. Apply continuous passive effects
    -- Pinksquare's Passive (HP Regeneration)
    if world.passives.pinkActive then
        for _, p in ipairs(world.players) do
            if p.hp > 0 and p.hp < p.maxHp then
                CombatActions.applyDirectHeal(p, 3 * dt)
            end
        end
    end

    -- Orangesquare's Passive (Comet Damage)
    if world.passives.orangeActive then
        for _, effect in ipairs(world.switchPlayerEffects) do
            if effect.targetPlayer and effect.targetPlayer.hp > 0 then
                local targetX = effect.targetPlayer.x + effect.targetPlayer.size / 2
                local targetY = effect.targetPlayer.y + effect.targetPlayer.size / 2

                local dx = targetX - effect.currentX
                local dy = targetY - effect.currentY
                local dist = math.sqrt(dx*dx + dy*dy)

                if dist > 0 then
                    -- Calculate where the comet WILL be this frame, without moving it.
                    local prevX, prevY = effect.currentX, effect.currentY
                    local moveAmount = effect.speed * dt
                    local nextX = prevX + (dx / dist) * moveAmount
                    local nextY = prevY + (dy / dist) * moveAmount

                    -- Check for collision along that path.
                    for _, enemy in ipairs(world.enemies) do
                        if enemy.hp > 0 and Geometry.isCircleCollidingWithLine(enemy.x+enemy.size/2, enemy.y+enemy.size/2, enemy.size/2, prevX, prevY, nextX, nextY, 2) then
                            CombatActions.applyDirectDamage(enemy, 10, false)
                        end
                    end
                end
            end
        end
    end
end

return PassiveSystem