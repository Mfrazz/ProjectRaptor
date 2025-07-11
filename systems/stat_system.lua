-- stat_system.lua
-- Calculates the final, combat-ready stats for all entities based on their
-- base stats, equipment, and status effects.

local StatSystem = {}

function StatSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        -- Only process entities that have stats
        if entity.baseAttackStat then
            -- Start with base stats
            entity.finalAttackStat = entity.baseAttackStat
            entity.finalDefenseStat = entity.baseDefenseStat

            -- In the future, you would add logic here to apply bonuses from:
            -- 1. Items in entity.inventory
            -- 2. Temporary buffs from statusEffects
        end
    end
end

return StatSystem