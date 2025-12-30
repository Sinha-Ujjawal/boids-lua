local vector2 = {}

---@class Vector2
---@field x number
---@field y number

---Returns a new 2d vector
---@param x number
---@param y number
---@return Vector2
function vector2.new(x, y)
	return { x = x, y = y }
end

---Returns a new random 2d vector within a range
---@param xlow number lowest possible x value
---@param xhigh number highest possible x value
---@param ylow number lowest possible y value
---@param yhigh number highest possible y value
---@return Vector2 vec random vector sampled from [xlow .. xhigh] and [ylow .. yhigh]
function vector2.random(xlow, xhigh, ylow, yhigh)
	local x = xlow + math.random() * (xhigh - xlow)
	local y = ylow + math.random() * (yhigh - ylow)
	return { x = x, y = y }
end

---Return clone of 2d vector
---@param vec Vector2
---@return Vector2
function vector2.clone(vec)
	return { x = vec.x, y = vec.y }
end

---Return -vec
---@param vec Vector2
---@return Vector2
function vector2.negate(vec)
	return { x = -vec.x, y = -vec.y }
end

---Return magnitude of the Vector2
---@param vec Vector2
---@return number
function vector2.mag(vec)
	return math.sqrt(vector2.dot(vec, vec))
end

---Return vec1 + vec2 + ...
---@param vec1 Vector2
---@param vec2 Vector2
---@param ...  Vector2
---@return Vector2
function vector2.add(vec1, vec2, ...)
	local aggX = vec1.x
	local aggY = vec1.y
	local args = { vec2, ... }
	local count = #args
	for i = 1, count do
		local vec = args[i]
		if vec then
			aggX = aggX + vec.x
			aggY = aggY + vec.y
		end
	end
	return vector2.new(aggX, aggY)
end

---Return vec1 - vec2 - ...
---@param vec1 Vector2
---@param vec2 Vector2
---@param ...  Vector2
---@return Vector2
function vector2.sub(vec1, vec2, ...)
	local aggX = vec1.x
	local aggY = vec1.y
	local args = { vec2, ... }
	local count = #args
	for i = 1, count do
		local vec = args[i]
		if vec then
			aggX = aggX - vec.x
			aggY = aggY - vec.y
		end
	end
	return vector2.new(aggX, aggY)
end

---Return vec1 * vec2 * ...
---Note that this is just component wise product similar to add or subtract
---@param vec1 Vector2
---@param vec2 Vector2
---@param ...  Vector2
---@return Vector2
function vector2.product(vec1, vec2, ...)
	local aggX = vec1.x
	local aggY = vec1.y
	local args = { vec2, ... }
	local count = #args
	for i = 1, count do
		local vec = args[i]
		if vec then
			aggX = aggX * vec.x
			aggY = aggY * vec.y
		end
	end
	return vector2.new(aggX, aggY)
end

---Return vec1 % vec2 % ...
---Note that this is just component wise modulus similar to add or subtract
---@param vec1 Vector2
---@param vec2 Vector2
---@param ...  Vector2
---@return Vector2
function vector2.mod(vec1, vec2, ...)
	local aggX = vec1.x
	local aggY = vec1.y
	local args = { vec2, ... }
	local count = #args
	for i = 1, count do
		local vec = args[i]
		if vec then
			aggX = aggX % vec.x
			aggY = aggY % vec.y
		end
	end
	return vector2.new(aggX, aggY)
end

---Return vec1 `dot` vec2
---@param vec1 Vector2
---@param vec2 Vector2
---@return number
function vector2.dot(vec1, vec2)
	return (vec1.x * vec2.x) + (vec1.y * vec2.y)
end

---Return vec * scaler
---@param vec Vector2
---@param scale number
---@return Vector2
function vector2.scaleBoth(vec, scale)
	return { x = vec.x * scale, y = vec.y * scale }
end

---Return vec * scale
---@param vec Vector2
---@param scale Vector2
---@return Vector2
function vector2.scale(vec, scale)
	return vector2.product(vec, scale)
end

---Return scaler projection of vec1 in direction of vec2
---(vec1 `dot` vec2) / mag(vec2)
---@param vec1 Vector2
---@param vec2 Vector2
---@return Vector2
function vector2.scalerProjection(vec1, vec2)
	local mag = vector2.dot(vec1, vec2) / vector2.mag(vec2)
	return vector2.scaleBoth(vec2, mag)
end

---Return the rotated vector by a given angle
---@param vec Vector2
---@param theta number angle in radians
---@return Vector2
function vector2.rotate(vec, theta)
	local cosTheta = math.cos(theta)
	local sinTheta = math.sin(theta)
	return { x = vec.x * cosTheta - vec.y * sinTheta, y = vec.x * sinTheta + vec.y * cosTheta }
end

---Returns the angle between two vectors in radians
---@param vec1 Vector2
---@param vec2 Vector2
---@return number signed angle in radians
function vector2.angle(vec1, vec2)
	local x1, y1 = vec1.x, vec1.y
	local x2, y2 = vec2.x, vec2.y
	return math.atan2(x1 * y2 - y1 * x2, x1 * x2 + y1 * y2)
end

---Calculates eucledian distance between two vectors
---@param vec1 Vector2
---@param vec2 Vector2
---@return number
function vector2.eucledianDistance(vec1, vec2)
	local x1, y1 = vec1.x, vec1.y
	local x2, y2 = vec2.x, vec2.y
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

---Normalize a vector to have magnitude equal 1. If the mag is 0, then don't change the vector
---@param vec Vector2
---@return Vector2
function vector2.normalize(vec)
	local mag = vector2.mag(vec)
	if mag ~= 0 then
		return vector2.scaleBoth(vec, 1 / mag)
	else
		return vec
	end
end

---Return a vector in the same direction as the original vector, but with magnitude `mag`.
---Don't do anything to zero vector.
---@param vec Vector2
---@param mag number
---@return Vector2
function vector2.setMag(vec, mag)
	local oldMag = vector2.mag(vec)
	if oldMag ~= 0 then
		return vector2.scaleBoth(vec, mag / oldMag)
	else
		return vec
	end
end

---Limits the magnitude of the vector to a particular limit
---@param vec Vector2
---@param limit number
function vector2.limit(vec, limit)
	local mag = vector2.mag(vec)
	if mag > limit then
		return vector2.scaleBoth(vec, limit / mag)
	else
		return vec
	end
end

---Average a table of vectors. If mapFn is not given, then we assume that items is Vector2[]
---@generic T
---@overload fun(items: Vector2[]): Vector2
---@param items T[]
---@param mapFn fun(item: T): Vector2?
---@return Vector2
function vector2.avg(items, mapFn)
	if #items == 0 then
		return vector2.new(0, 0)
	end
	local count = 0
	local sumX = 0
	local sumY = 0
	if mapFn == nil then
		count = #items
		for _, item in ipairs(items) do
			local vec = item
			sumX = sumX + vec.x
			sumY = sumY + vec.y
		end
	else
		for _, item in ipairs(items) do
			local vec = mapFn(item)
			if vec ~= nil then
				count = count + 1
				sumX = sumX + vec.x
				sumY = sumY + vec.y
			end
		end
	end
	if count > 0 then
		sumX = sumX / count
		sumY = sumY / count
	end
	return vector2.new(sumX, sumY)
end

return vector2
