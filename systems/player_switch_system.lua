-- player_switch_system.lua
-- Manages the "comet" visual effect when switching between active players.

local PlayerSwitchSystem = {}

function PlayerSwitchSystem.update(dt, world)
    for i = #world.switchPlayerEffects, 1, -1 do
        local effect = world.switchPlayerEffects[i]

        -- Update the lifetime of trail particles and remove old ones
        for j = #effect.trail, 1, -1 do
            local p = effect.trail[j]
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then table.remove(effect.trail, j) end
        end

        -- If the target player is gone (e.g., died), remove the effect immediately.
        if not effect.targetPlayer or effect.targetPlayer.hp <= 0 then
            table.remove(world.switchPlayerEffects, i)
        else
            -- Update the target coordinates every frame to follow the player
            local targetX = effect.targetPlayer.x + effect.targetPlayer.size / 2
            local targetY = effect.targetPlayer.y + effect.targetPlayer.size / 2

            -- Move the comet head towards its target
            local dx = targetX - effect.currentX
            local dy = targetY - effect.currentY
            local dist = math.sqrt(dx*dx + dy*dy)

            local moveAmount = effect.speed * dt
            if dist > moveAmount then
                effect.currentX = effect.currentX + (dx / dist) * moveAmount
                effect.currentY = effect.currentY + (dy / dist) * moveAmount

                effect.trailTimer = effect.trailTimer + dt
                if effect.trailTimer >= effect.trailInterval then
                    effect.trailTimer = 0
                    table.insert(effect.trail, {x = effect.currentX, y = effect.currentY, lifetime = 0.25, initialLifetime = 0.25})
                end
            else
                table.remove(world.switchPlayerEffects, i)
            end
        end
    end
end

return PlayerSwitchSystem