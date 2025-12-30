local loveUtils = {}

---@class Color
---@field r number
---@field g number
---@field b number
---@field a number

---Love2d wrapper for love.math.colorFromBytes
---To return as Color table
---@param r number
---@param g number
---@param b number
---@param a number?
---@return Color
function loveUtils.colorFromBytes(r, g, b, a)
	local cr, cg, cb, ca = love.math.colorFromBytes(r, g, b, a)
	return { r = cr, g = cg, b = cb, a = ca }
end

---Love2d Utility to set the color before calling `drawFn`
---After calling it will reset the color to the original
---@param color  Color
---@param drawFn function()
function loveUtils.drawWithColor(color, drawFn)
	local origR, origG, origB, origA = love.graphics.getColor()
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	drawFn()
	love.graphics.setColor(origR, origG, origB, origA)
end

---Love2d Utility to set the line width before calling `drawFn`
---After calling it will reset the line width to the original
---@param lineWidth number
---@param drawFn    function()
function loveUtils.drawWithLineWidth(lineWidth, drawFn)
	local origLineWidth = love.graphics.getLineWidth()
	love.graphics.setLineWidth(lineWidth)
	drawFn()
	love.graphics.setLineWidth(origLineWidth)
end

return loveUtils
