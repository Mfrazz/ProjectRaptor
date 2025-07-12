-- attack_handler.lua
-- This module is responsible for dispatching player attacks.

local PlayerAttacks = require("data.player_attacks")

local AttackHandler = {}

function AttackHandler.execute(square, attackKey, world)
    local blueprint = CharacterBlueprints[square.playerType]
    if not blueprint then return end

    local attackData = blueprint.attacks[attackKey]
    if attackData and attackData.name and PlayerAttacks[attackData.name] then
        local result = PlayerAttacks[attackData.name](square, attackData.power, world)
        -- If the attack function returns a boolean, use it. Otherwise, assume it fired successfully.
        if type(result) == "boolean" then
            return result
        else
            return true
        end
    end
    return false -- Attack not found
end

return AttackHandler