-- grapple_system.lua
-- Handles the collision and effect resolution for grappling hook attacks.

local EffectFactory = require("modules.effect_factory")
local CombatActions = require("modules.combat_actions")

local GrappleSystem = {}

function GrappleSystem.update(dt, world)
    -- Loop 1: Check for completed single-target grapples (tangrowth_j)
    for _, entity in ipairs(world.all_entities) do
        if entity.components.grapple_collision_effect then
            local isAtTarget = (entity.x == entity.targetX and entity.y == entity.targetY)

            if isAtTarget then
                local effectData = entity.components.grapple_collision_effect
                local centerX, centerY = entity.x + entity.size / 2, entity.y + entity.size / 2

                -- Create the ripple effect, passing the status effect data to it.
                -- The AttackResolutionSystem will handle applying the damage and status correctly.
                EffectFactory.createRippleEffect(entity, centerX, centerY, effectData.power, effectData.rippleSize, "enemy", effectData.statusEffect)

                -- Clean up
                entity.components.grapple_collision_effect = nil
                -- Find and remove the specific grapple line associated with this attacker.
                -- This prevents it from clearing lines from other effects (like tangrowth_l).
                for i = #world.grappleLineEffects, 1, -1 do
                    if world.grappleLineEffects[i].attacker == entity then
                        table.remove(world.grappleLineEffects, i)
                        break -- Assume only one single-target grapple can be active per entity.
                    end
                end
            end
        end

        -- Loop 2: Check for completed mass grapples (tangrowth_l)
        if entity.components.mass_grapple_pending then
            local effectData = entity.components.mass_grapple_pending
            local allTargetsArrived = true

            -- Check if all pulled enemies have reached their destination
            for _, target in ipairs(effectData.targets) do
                if target.x ~= target.targetX or target.y ~= target.targetY then
                    allTargetsArrived = false
                    break
                end
            end

            if allTargetsArrived then
                -- All enemies have arrived, trigger the ripple effect.
                local centerX, centerY = entity.x + entity.size / 2, entity.y + entity.size / 2
                EffectFactory.createRippleEffect(entity, centerX, centerY, effectData.power, 3, "enemy", effectData.statusEffect)

                -- Clean up the pending component
                entity.components.mass_grapple_pending = nil
            end
        end
    end
end

return GrappleSystem