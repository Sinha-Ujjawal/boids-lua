local bbox = {}

local vector2 = require("./vector2")

---@class BBox
---@field x number
---@field y number
---@field width number
---@field height number

---Returns a new BBox
---@param x number
---@param y number
---@param width number
---@param height number
---@return BBox
function bbox.new(x, y, width, height)
	return { x = x, y = y, width = width, height = height }
end

---Checks if the point lies inside the bbox
---@param bb BBox
---@param point Vector2
---@return boolean
function bbox.contains(bb, point)
	return point.x >= bb.x and point.x < bb.x + bb.width and point.y >= bb.y and point.y < bb.y + bb.height
end

---Returns all four corners of the bbox
---@param bb BBox
---@return Vector2 ul upper left corner
---@return Vector2 ur upper right corner
---@return Vector2 bl bottom left corner
---@return Vector2 br bottom right corner
function bbox.corners(bb)
	local ul = vector2.new(bb.x, bb.y)
	local ur = vector2.new(bb.x + bb.width - 1, bb.y)
	local bl = vector2.new(bb.x, bb.y + bb.height - 1)
	local br = vector2.new(bb.x + bb.width - 1, bb.y + bb.height - 1)
	return ul, ur, bl, br
end

---Checks if the other bbox lies inside given bbox
---@param bbox1 BBox
---@param bbox2 BBox
---@return boolean
function bbox.containsBBox(bbox1, bbox2)
	local ul, ur, bl, br = bbox.corners(bbox2)
	return bbox.contains(bbox1, ul)
		and bbox.contains(bbox1, ur)
		and bbox.contains(bbox1, bl)
		and bbox.contains(bbox1, br)
end

---Breaks the given BBox into its four equal adjacent quads
--- ........
--- ........
--- ........
--- ........
---    To
--- ....|....
--- ....|....
--- ---------
--- ....|....
--- ....|....
--- @param bb BBox
--- @return BBox quad1
--- @return BBox quad2
--- @return BBox quad3
--- @return BBox quad4
function bbox.toQuads(bb)
	local widthBy2 = bb.width / 2
	local heightBy2 = bb.height / 2
	local quad1 = bbox.new(bb.x, bb.y, widthBy2, heightBy2)
	local quad2 = bbox.new(bb.x + widthBy2, bb.y, widthBy2, heightBy2)
	local quad3 = bbox.new(bb.x, bb.y + heightBy2, widthBy2, heightBy2)
	local quad4 = bbox.new(bb.x + widthBy2, bb.y + heightBy2, widthBy2, heightBy2)
	return quad1, quad2, quad3, quad4
end

---Get the BBox of a circle
---@param x number
---@param y number
---@param radius number
---@return BBox
function bbox.ofCircle(x, y, radius)
	local bx = x - radius
	local by = y - radius
	local size = 2 * radius
	return bbox.new(bx, by, size, size)
end

---Checks if two BBox are colliding using Simple AABB (Axis-Aligned Bounding Box) Detection
---@param bbox1 BBox
---@param bbox2 BBox
---@return boolean
function bbox.checkCollision(bbox1, bbox2)
	return bbox1.x < bbox2.x + bbox2.width
		and bbox1.x + bbox1.width > bbox2.x
		and bbox1.y < bbox2.y + bbox2.height
		and bbox1.y + bbox1.height > bbox2.y
end

---Checks if two BBox are intersecting using Simple AABB (Axis-Aligned Bounding Box) Detection
---@param bbox1 BBox
---@param bbox2 BBox
---@return boolean
function bbox.intersects(bbox1, bbox2)
	return bbox1.x <= bbox2.x + bbox2.width
		and bbox1.x + bbox1.width >= bbox2.x
		and bbox1.y <= bbox2.y + bbox2.height
		and bbox1.y + bbox1.height >= bbox2.y
end

return bbox
