-- geometry.lua
-- Contains pure functions for geometric calculations and collision checks.

local Geometry = {}

function Geometry.isCircleCollidingWithLine(cx, cy, cr, x1, y1, x2, y2, lineThickness)
    -- Check if the circle's center is close to the line segment
    local dx, dy = x2 - x1, y2 - y1
    local lenSq = dx*dx + dy*dy
    if lenSq == 0 then -- The "line" is a point
        return math.sqrt((cx-x1)^2 + (cy-y1)^2) < cr + lineThickness
    end

    -- Project the circle's center onto the line
    local t = ((cx - x1) * dx + (cy - y1) * dy) / lenSq
    t = math.max(0, math.min(1, t)) -- Clamp to the segment

    -- Find the closest point on the segment to the circle's center
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy

    -- Check the distance from the closest point to the circle's center
    local distSq = (cx - closestX)^2 + (cy - closestY)^2
    return distSq < (cr + lineThickness)^2
end

return Geometry