-- player_attack_system.lua
-- This system is responsible for executing attacks queued by the human player.

local AttackHandler = require("modules.attack_handler")

local PlayerAttackSystem = {}

function PlayerAttackSystem.update(dt, world)
    -- This system now iterates over ALL players to check for human-queued attacks
    -- that are ready to be executed, regardless of who is the active player.
    for _, p in ipairs(world.players) do
        local isMoving = (p.x ~= p.targetX) or (p.y ~= p.targetY)

        -- Check for a human-queued attack that is ready to fire.
        if not isMoving and p.pendingAttackKey and not p.statusEffects.stunned and not p.statusEffects.careening then
            local keyUsed = p.pendingAttackKey
            local attackData = CharacterBlueprints[p.playerType].attacks[keyUsed]
            local attackCost = attackData and attackData.cost

            -- The core condition: is the action bar full?
            if attackCost and (p.actionBarCurrent >= p.actionBarMax or p.continuousAttack) then
                p.components.ai.last_attack_key = keyUsed
                
                local attackFired = AttackHandler.execute(p, keyUsed, world)

                if attackFired then
                    local wasContinuousBefore = p.continuousAttack
                    if not (wasContinuousBefore and not p.continuousAttack) then
                        p.actionBarCurrent = 0
                        p.actionBarMax = attackCost
                        p.components.actionBarReady = nil -- Consume the "ready" state
                    end
                    world.lastAttackTimestamp = love.timer.getTime()
                    p.pendingAttackKey = nil -- Clear the queued attack
                end
            end
        end
    end
end

return PlayerAttackSystem