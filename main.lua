local boids = require("./boids")

local lick = require("./libraries/LICK/lick")
lick.reset = true
lick.updateAllFiles = true
lick.clearPackages = true

---@class GameState
---@field flock Boid[]

---@type GameState
local gameState = {
	flock = {},
}

---This function is called exactly once at the beginning of the game.
---@param arg table
---@param unfilteredArg table
function love.load(arg, unfilteredArg)
	_ = arg -- UNUSED
	_ = unfilteredArg -- UNUSED
	math.randomseed(os.time()) -- Seed random number
	for i = 1, 100 do
		gameState.flock[i] = boids.initial()
	end
end

---Callback function used to draw on the screen every frame.
function love.draw()
	for _, boid in ipairs(gameState.flock) do
		boids.draw(boid)
	end
end

---Callback function used to update the state of the game every frame.
---@param dt number delta time in milliseconds
function love.update(dt)
	_ = dt -- UNUSED
	---@type Boid[]
	local origFlock = {}
	for i, boid in ipairs(gameState.flock) do
		origFlock[i] = boids.copy(boid)
	end
	for _, boid in ipairs(gameState.flock) do
		boids.flock(boid, origFlock)
		boids.update(boid)
	end
end

---Callback function triggered when a keyboard key is released.
---@param key love.KeyConstant
---@param scancode love.Scancode
function love.keyreleased(key, scancode)
	_ = scancode -- UNUSED
	if key == "r" then
		love.load()
	end
end
