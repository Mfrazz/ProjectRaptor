-- movement_system.lua
-- Handles updating entity positions based on their target coordinates.
-- Also manages the creation of afterimage effects during movement.

local MovementSystem = {}

function MovementSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        -- Only process entities that can move and have a target
        if entity.speed and entity.targetX and ((entity.x ~= entity.targetX) or (entity.y ~= entity.targetY)) then
            local oldX, oldY = entity.x, entity.y
            local wasMoving = true

            local moveAmount = (entity.speed * (entity.speedMultiplier or 1)) * dt
            local epsilon = 3

            if entity.x < entity.targetX then
                entity.x = math.min(entity.targetX, entity.x + moveAmount)
            elseif entity.x > entity.targetX then
                entity.x = math.max(entity.targetX, entity.x - moveAmount)
            end

            if entity.y < entity.targetY then
                entity.y = math.min(entity.targetY, entity.y + moveAmount)
            elseif entity.y > entity.targetY then
                entity.y = math.max(entity.targetY, entity.y - moveAmount)
            end

            -- Create afterimage for players during movement
            if entity.type == "player" then
                if not entity.components.afterimage then
                    entity.components.afterimage = { timer = 0, interval = 0.05 }
                end
                local afterimage = entity.components.afterimage
                afterimage.timer = afterimage.timer + dt
                if afterimage.timer >= afterimage.interval then
                    afterimage.timer = afterimage.timer - afterimage.interval
                    table.insert(world.afterimageEffects, {x = oldX, y = oldY, size = entity.size, color = entity.color, playerType = entity.playerType, lifetime = 0.2, initialLifetime = 0.2})
                end
            end

            local isStillMoving = (entity.x ~= entity.targetX) or (entity.y ~= entity.targetY)
            if wasMoving and not isStillMoving then
                entity.speedMultiplier = 1 -- Reset speed multiplier once movement is complete
            end
        end
    end
end

return MovementSystem