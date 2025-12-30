local triangle = {}

local vector2 = require("./vector2")

---@class Triangle
---@field v1 Vector2
---@field v2 Vector2
---@field v3 Vector2

---Computes area of the triangle
---@param t Triangle
---@return number
function triangle.area(t)
	local p1 = t.v1
	local p2 = t.v2
	local p3 = t.v3
	return (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y))
end

---Creates a new triangle given its vertex
---It will make sure that the vertices are in CCW
---@param p1 Vector2
---@param p2 Vector2
---@param p3 Vector2
---@return Triangle?
---@return string?
function triangle.new(p1, p2, p3)
	-- Calculate signed area (multiplied by 2 for simplicity)
	local signedArea = (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y))

	-- 1. Check if they are collinear (using a small epsilon for precision)
	if math.abs(signedArea) < 1e-9 then
		return nil, "Points are collinear; no triangle formed."
	end

	-- 2. Ensure consistent order (Counter-Clockwise)
	if signedArea < 0 then
		-- Negative area means Clockwise; swap two vertices to make it CCW
		-- 1, 3, 2
		return { v1 = p1, v2 = p3, v3 = p2 }
	else
		-- Positive area is already CCW
		-- 1, 2, 3
		return { v1 = p1, v2 = p2, v3 = p3 }
	end
end

---Returns a new triangle from its base and height params
---@param baseStart Vector2
---@param base number
---@param height number
function triangle.fromBaseAndHeight(baseStart, base, height)
	local v1 = baseStart
	local v2 = vector2.new(v1.x + base, v1.y)
	local v3 = vector2.new(v1.x + (base / 2), v1.y - height)
	return triangle.new(v1, v2, v3)
end

---Returns the centroid of the triangle
---@param t Triangle
---@return Vector2
function triangle.centroid(t)
	local cx = (t.v1.x + t.v2.x + t.v3.x) / 3
	local cy = (t.v1.y + t.v2.y + t.v3.y) / 3
	return vector2.new(cx, cy)
end

---Rotate the triangle based on a point
---@param t Triangle Triangle to rotate
---@param angle number Angle in radians
---@param point Vector2? Point at which to rotate on. Defaults to the centroid of the triangle.
---@return Triangle Rotated triangle
function triangle.rotate(t, angle, point)
	if point == nil then
		point = triangle.centroid(t)
	end
	local newT, _ = triangle.new(
		vector2.add(point, vector2.rotate(vector2.sub(t.v1, point), angle)),
		vector2.add(point, vector2.rotate(vector2.sub(t.v2, point), angle)),
		vector2.add(point, vector2.rotate(vector2.sub(t.v3, point), angle))
	)
	assert(newT ~= nil)
	return newT
end

return triangle
