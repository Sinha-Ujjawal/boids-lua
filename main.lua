local boids = require("./boids")
local bbox = require("./bbox")
local conf = require("./conf")
local quadTree = require("./quadTree")
local loveUtils = require("./loveUtils")

local lick = require("./libraries/LICK/lick")
lick.reset = true
lick.updateAllFiles = true
lick.clearPackages = true

---@class GameState
---@field flock QuadTree
---@field showFPS boolean

local function newQuadTree()
	return quadTree.new(bbox.new(0, 0, conf.WIDTH, conf.HEIGHT), 32, 8)
end

---@type GameState
local gameState = {
	flock = newQuadTree(),
	showFPS = false,
}

---This function is called exactly once at the beginning of the game.
---@param arg table
---@param unfilteredArg table
function love.load(arg, unfilteredArg)
	_ = arg -- UNUSED
	_ = unfilteredArg -- UNUSED
	math.randomseed(os.time()) -- Seed random number
	gameState.flock = newQuadTree()
	for _ = 1, 1000 do
		local b = boids.initial()
		quadTree.insert(gameState.flock, { point = b.position, data = b })
	end
end

---Callback function used to draw on the screen every frame.
function love.draw()
	quadTree.forEach(gameState.flock, function(p)
		---@type Boid
		local boid = p.data
		boids.draw(boid)
	end)
	if gameState.showFPS then
		local fps = tostring(love.timer.getFPS())
		loveUtils.drawWithColor(loveUtils.colorFromBytes(255, 0, 0), function()
			love.graphics.print("FPS: " .. fps, 10, 10)
		end)
	end
end

local BOIDS_PERCEPTION_HALVED = boids.PERCEPTION / 2

---Returns array of boids which are within the perception limit of the point
---@param flock QuadTree
---@param point Vector2
---@return Boid[]
local function boidsAroundMe(flock, point)
	local bb = bbox.new(
		point.x - BOIDS_PERCEPTION_HALVED,
		point.y - BOIDS_PERCEPTION_HALVED,
		boids.PERCEPTION,
		boids.PERCEPTION
	)
	---@type Boid[]
	local boidsToFlockWith = {}
	quadTree.forEachWithinBBox(flock, bb, function(p)
		---@type Boid
		local boid = p.data
		table.insert(boidsToFlockWith, boid)
	end)
	return boidsToFlockWith
end

---Update all boids to new position, velocity and acceleration
---@param flock QuadTree
local function updateAllBoids(flock)
	---@type Boid[]
	local temp = {}
	quadTree.forEach(flock, function(p)
		---@type Boid
		local boid = p.data
		local boidsToFlockWith = boidsAroundMe(flock, p.point)
		boids.flock(boid, boidsToFlockWith)
		temp[#temp + 1] = boid
	end)
	for _, boid in ipairs(temp) do
		local oldPos = boid.position
		boids.update(boid)
		quadTree.movePoint(flock, oldPos, boid.position, function(other)
			return boid == other.data
		end)
	end
end

---Callback function used to update the state of the game every frame.
---@param dt number delta time in milliseconds
function love.update(dt)
	_ = dt -- UNUSED
	updateAllBoids(gameState.flock)
end

---Callback function triggered when a keyboard key is released.
---@param key love.KeyConstant
---@param scancode love.Scancode
function love.keyreleased(key, scancode)
	_ = scancode -- UNUSED
	if key == "r" then
		love.load()
	end
	if key == "f" then
		gameState.showFPS = not gameState.showFPS
	end
end
