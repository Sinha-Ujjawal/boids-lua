---Reference
---1. https://www.red3d.com/cwr/boids/

local boids = {}

local vector2 = require("./vector2")
local conf = require("./conf")
local loveUtils = require("./loveUtils")
local triangle = require("./triangle")

boids.SCREEN_WRAP = vector2.new(conf.WIDTH, conf.HEIGHT)
boids.MAX_FORCE = 0.025
boids.MAX_SPEED = 0.5
boids.MAX_STEER_SPEED = 4
boids.PERCEPTION = 100

---@class Boid
---@field position Vector2
---@field velocity Vector2
---@field acceleration Vector2

---Create a new Boid table
---@param position Vector2
---@param velocity Vector2
---@param acceleration Vector2
---@return Boid
function boids.new(position, velocity, acceleration)
	return { position = position, velocity = velocity, acceleration = acceleration }
end

---Creates a new boid as a copy of the other
---@param boid Boid boid to copy
---@return Boid
function boids.copy(boid)
	return boids.new(boid.position, boid.velocity, boid.acceleration)
end

---Initialize a new Boid
---@return Boid
function boids.initial()
	local position = vector2.random(0, conf.WIDTH - 1, 0, conf.HEIGHT - 1)
	local velocity = vector2.random(-0.5, 0.5, -0.5, 0.5)
	local acceleration = vector2.new(0, 0)
	return boids.new(position, velocity, acceleration)
end

---Checks if two boids have same position, velocity, and acceleration
---@param boid1 Boid
---@param boid2 Boid
---@return boolean
function boids.areSame(boid1, boid2)
	return vector2.equal(boid1.position, boid2.position)
		and vector2.equal(boid1.velocity, boid2.velocity)
		and vector2.equal(boid1.acceleration, boid2.acceleration)
end

---Updated the boids position and velocity
---@param boid Boid
function boids.update(boid)
	boid.position = vector2.mod(vector2.add(boid.position, boid.velocity), boids.SCREEN_WRAP)
	boid.velocity = vector2.add(boid.velocity, boid.acceleration)
	boid.velocity = vector2.limit(boid.velocity, boids.MAX_SPEED)
end

---Draw a boid using love2d
---@param boid Boid
function boids.draw(boid)
	local pos = boid.position
	loveUtils.drawWithColor(loveUtils.colorFromBytes(255, 255, 255), function()
		--love.graphics.circle("line", pos.x, pos.y, 1)
		local t = triangle.fromBaseAndHeight(vector2.new(pos.x - 3, pos.y), 6, 7)
		local angle = vector2.angle(vector2.new(0, -1), boid.velocity)
		t = triangle.rotate(t, angle)
		love.graphics.line(t.v1.x, t.v1.y, t.v2.x, t.v2.y)
		love.graphics.line(t.v2.x, t.v2.y, t.v3.x, t.v3.y)
		love.graphics.line(t.v3.x, t.v3.y, t.v1.x, t.v1.y)
	end)
end

---Steer towards the average heading of local flockmates
---@param boid Boid
---@param otherBoids Boid[]
---@return Vector2 Steering force required for alignment
function boids.align(boid, otherBoids)
	local avgVelocity = vector2.avg(otherBoids, function(other)
		if boids.areSame(boid, other) then -- exclude itself
			return nil
		end
		local d = vector2.eucledianDistance(boid.position, other.position)
		if d < boids.PERCEPTION then -- within perception
			return other.velocity
		else
			return nil
		end
	end)
	if avgVelocity.x == 0 and avgVelocity.y == 0 then
		return avgVelocity
	else
		local steerVelocity = vector2.setMag(avgVelocity, boids.MAX_STEER_SPEED)
		return vector2.limit(vector2.sub(steerVelocity, boid.velocity), boids.MAX_FORCE)
	end
end

---Steer to move toward the average position of local flockmates
---@param boid Boid
---@param otherBoids Boid[]
---@return Vector2 Steering force required for cohesion
function boids.cohesion(boid, otherBoids)
	local avgPosition = vector2.avg(otherBoids, function(other)
		if boids.areSame(boid, other) then -- exclude itself
			return nil
		end
		local d = vector2.eucledianDistance(boid.position, other.position)
		if d < boids.PERCEPTION then -- within perception
			return other.position
		else
			return nil
		end
	end)
	if avgPosition.x == 0 and avgPosition.y == 0 then
		return avgPosition
	else
		local steerDirection = vector2.sub(avgPosition, boid.position)
		local steerVelocity = vector2.setMag(steerDirection, boids.MAX_STEER_SPEED)
		return vector2.limit(vector2.sub(steerVelocity, boid.velocity), boids.MAX_FORCE)
	end
end

---Steer to avoid crowding local flockmates
---@param boid Boid
---@param otherBoids Boid[]
---@return Vector2 Steering force required for separation
function boids.separation(boid, otherBoids)
	local avgDiffs = vector2.avg(otherBoids, function(other)
		if boids.areSame(boid, other) then -- exclude itself
			return nil
		end
		local d = vector2.eucledianDistance(boid.position, other.position)
		if d < boids.PERCEPTION then -- within perception
			local diff = vector2.sub(boid.position, other.position)
			diff = vector2.scaleBoth(diff, 1 / d)
			return diff
		else
			return nil
		end
	end)
	if avgDiffs.x == 0 and avgDiffs.y == 0 then
		return avgDiffs
	else
		local steerVelocity = vector2.setMag(avgDiffs, boids.MAX_STEER_SPEED)
		return vector2.limit(vector2.sub(steerVelocity, boid.velocity), boids.MAX_FORCE)
	end
end

---Boids Flocking Algorithm to move the boid in the direction of
---its surroudings (otherBoids) within a perception
---@param boid Boid
---@param otherBoids Boid[]
function boids.flock(boid, otherBoids)
	local alignment = boids.align(boid, otherBoids)
	local cohesion = boids.cohesion(boid, otherBoids)
	local separation = boids.separation(boid, otherBoids)
	local netAcceleration = vector2.add(alignment, cohesion, separation)
	boid.acceleration = netAcceleration
end

return boids
