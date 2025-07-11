-- camera.lua
-- Manages the game's viewport for scrolling maps.

local Camera = {
    x = 0,
    y = 0,
    zoom = 1,
    target = nil, -- The entity the camera should follow
    lerp_rate = 5 -- How smoothly the camera follows the target
}

function Camera:follow(entity)
    self.target = entity
end

function Camera:update(dt)
    if self.target then
        local windowWidth, windowHeight = love.graphics.getDimensions()
        -- Center the camera on the target
        local targetX = self.target.x + self.target.size / 2 - windowWidth / 2
        local targetY = self.target.y + self.target.size / 2 - windowHeight / 2

        -- Smoothly interpolate the camera's position towards the target
        self.x = self.x + (targetX - self.x) * self.lerp_rate * dt
        self.y = self.y + (targetY - self.y) * self.lerp_rate * dt
    end
end

function Camera:apply()
    love.graphics.push()
    love.graphics.scale(self.zoom)
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:revert()
    love.graphics.pop()
end

return Camera