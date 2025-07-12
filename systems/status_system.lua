-- status_system.lua
-- This system is responsible for updating all status effects on entities.

local EffectFactory = require("modules.effect_factory")

local StatusSystem = {}

function StatusSystem.update(dt, world)
    for _, s in ipairs(world.all_entities) do
        if s.statusEffects then
            for effectType, effectData in pairs(s.statusEffects) do
                if effectData.duration then
                    effectData.duration = effectData.duration - dt
                    if effectData.duration <= 0 then
                        if effectType == "poison" then
                            s.poisonTickTimer = nil -- Clean up timer when poison expires
                        end
                        s.statusEffects[effectType] = nil -- Remove expired effect
                    end
                end
            end

            -- Handle poison damage over time
            if s.statusEffects.poison then
                if not s.poisonTickTimer then s.poisonTickTimer = 0 end
                s.poisonTickTimer = s.poisonTickTimer + dt
                if s.poisonTickTimer >= 1 then
                    s.poisonTickTimer = s.poisonTickTimer - 1
                    if s.hp > 0 then
                        local damage = Config.POISON_DAMAGE_PER_SECOND
                        s.hp = s.hp - damage
                        if s.hp < 0 then s.hp = 0 end
                        EffectFactory.createDamagePopup(s, damage, false, {0.5, 0, 0.5, 1}) -- Purple poison damage popup
                    end
                end
            end
        end
    end
end

return StatusSystem