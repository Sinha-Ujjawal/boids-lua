local quadTree = {}

local vector2 = require("./vector2")
local bbox = require("./bbox")

---@class Point
---@field point Vector2
---@field data  any

---@class QuadTreeNode
---@field boundary   BBox
---@field points     Point[]
---@field depth      number
---@field subdivided boolean
---@field quad1      QuadTreeNode?
---@field quad2      QuadTreeNode?
---@field quad3      QuadTreeNode?
---@field quad4      QuadTreeNode?

---@class QuadTree
---@field root     QuadTreeNode
---@field capacity number
---@field maxDepth number

---Create a new QuadTreeNode with a given boundary
---@param boundary BBox Boundary of the QuadTreeNode
---@param depth number
---@return QuadTreeNode
local function newNode(boundary, depth)
	return { boundary = boundary, points = {}, depth = depth, subdivided = false }
end

---Subdivides the given QuadTreeNode
---@param qtNode QuadTreeNode
local function subdivideNode(qtNode)
	local quad1, quad2, quad3, quad4 = bbox.toQuads(qtNode.boundary)
	qtNode.quad1 = newNode(quad1, qtNode.depth + 1)
	qtNode.quad2 = newNode(quad2, qtNode.depth + 1)
	qtNode.quad3 = newNode(quad3, qtNode.depth + 1)
	qtNode.quad4 = newNode(quad4, qtNode.depth + 1)
	qtNode.subdivided = true
end

---Add a point to the given QuadTreeNode. If capacity is exceeded, it will insert to the appropriate children
---@param qtNode QuadTreeNode
---@param capacity number
---@param maxDepth number
---@param point Point
---@return boolean ok Returns true if the point was added to the quad tree node, otherwise returns false
local function insertIntoNode(qtNode, capacity, maxDepth, point)
	if not bbox.contains(qtNode.boundary, point.point) then
		return false
	end

	if qtNode.depth > maxDepth or #qtNode.points < capacity then
		table.insert(qtNode.points, point)
		return true
	end

	if not qtNode.subdivided then
		subdivideNode(qtNode)
	end
	assert(qtNode.subdivided)
	assert(qtNode.quad1)
	assert(qtNode.quad2)
	assert(qtNode.quad3)
	assert(qtNode.quad4)

	return insertIntoNode(qtNode.quad1, capacity, maxDepth, point)
		or insertIntoNode(qtNode.quad2, capacity, maxDepth, point)
		or insertIntoNode(qtNode.quad3, capacity, maxDepth, point)
		or insertIntoNode(qtNode.quad4, capacity, maxDepth, point)
end

---Checks if a point is present in the QuadTreeNode
---@param qtNode QuadTreeNode
---@param point Vector2
---@return Point?
local function checkPointInNode(qtNode, point)
	if not bbox.contains(qtNode.boundary, point) then
		return nil
	end
	for _, p in ipairs(qtNode.points) do
		if vector2.equal(point, p.point) then
			return p
		end
	end
	if qtNode.subdivided then
		return checkPointInNode(qtNode.quad1, point)
			or checkPointInNode(qtNode.quad2, point)
			or checkPointInNode(qtNode.quad3, point)
			or checkPointInNode(qtNode.quad4, point)
	end
	return nil
end

---Returns all the points that lie inside a given bounding box
---@param qtNode QuadTreeNode
---@param bb BBox
---@param acc Point[]?
---@return Point[]?
local function queryBBoxFromNode(qtNode, bb, acc)
	if not bbox.intersects(qtNode.boundary, bb) then
		return acc
	end
	if acc == nil then
		acc = {}
	end
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) then
			table.insert(acc, point)
		end
	end
	if qtNode.subdivided then
		if bbox.intersects(qtNode.quad1.boundary, bb) then
			acc = queryBBoxFromNode(qtNode.quad1, bb, acc)
		end
		if bbox.intersects(qtNode.quad2.boundary, bb) then
			acc = queryBBoxFromNode(qtNode.quad2, bb, acc)
		end
		if bbox.intersects(qtNode.quad3.boundary, bb) then
			acc = queryBBoxFromNode(qtNode.quad3, bb, acc)
		end
		if bbox.intersects(qtNode.quad4.boundary, bb) then
			acc = queryBBoxFromNode(qtNode.quad4, bb, acc)
		end
	end
	return acc
end

---Checks if a given QuadTreeNode has empty children
---@param qtNode QuadTreeNode
---@return boolean
local function childrensAreEmpty(qtNode)
	return true
		-- quad 1 check
		and #qtNode.quad1.points == 0
		and not qtNode.quad1.subdivided
		-- quad 2 check
		and #qtNode.quad2.points == 0
		and not qtNode.quad2.subdivided
		-- quad 3 check
		and #qtNode.quad3.points == 0
		and not qtNode.quad3.subdivided
		-- quad 4 check
		and #qtNode.quad4.points == 0
		and not qtNode.quad4.subdivided
end

---Frees the children of the QuadTreeNode
---@param qtNode QuadTreeNode
local function forgetChildren(qtNode)
	qtNode.quad1 = nil
	qtNode.quad2 = nil
	qtNode.quad3 = nil
	qtNode.quad4 = nil
	qtNode.subdivided = false
end

---Delete a given point from the QuadTreeNode
---@param qtNode QuadTreeNode
---@param point Vector2
---@param fn fun(p: Point): boolean If this function returns true, then it will delete the point, otherwise leave
---@param acc Point[]?
---@return Point[]?
local function deleteFromNode(qtNode, point, fn, acc)
	if not bbox.contains(qtNode.boundary, point) then
		return acc
	end
	---@type Point[]
	local nonDeletedPoints = {}
	for _, p in ipairs(qtNode.points) do
		if vector2.equal(point, p.point) and fn(p) then
			if acc == nil then
				acc = {}
			end
			table.insert(acc, p)
		else
			table.insert(nonDeletedPoints, p)
		end
	end
	qtNode.points = nonDeletedPoints
	if qtNode.subdivided then
		if bbox.contains(qtNode.quad1.boundary, point) then
			acc = deleteFromNode(qtNode.quad1, point, fn, acc)
		end
		if bbox.contains(qtNode.quad2.boundary, point) then
			acc = deleteFromNode(qtNode.quad2, point, fn, acc)
		end
		if bbox.contains(qtNode.quad3.boundary, point) then
			acc = deleteFromNode(qtNode.quad3, point, fn, acc)
		end
		if bbox.contains(qtNode.quad4.boundary, point) then
			acc = deleteFromNode(qtNode.quad4, point, fn, acc)
		end
		if acc and childrensAreEmpty(qtNode) then
			forgetChildren(qtNode)
		end
	end
	return acc
end

---Delete points within a BBox from the QuadTreeNode
---@param qtNode QuadTreeNode
---@param bb BBox
---@param fn ?fun(p: Point): boolean If this function returns true, then it will delete the point, otherwise leave
---@param acc Point[]?
---@return Point[]?
local function deleteFromNodeWithinBBox(qtNode, bb, fn, acc)
	if not bbox.intersects(qtNode.boundary, bb) then
		return acc
	end
	---@type Point[]
	local nonDeletedPoints = {}
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) and (fn == nil or fn(point)) then
			if acc == nil then
				acc = {}
			end
			table.insert(acc, point)
		else
			table.insert(nonDeletedPoints, point)
		end
	end
	qtNode.points = nonDeletedPoints
	if qtNode.subdivided then
		if bbox.intersects(qtNode.quad1.boundary, bb) then
			acc = deleteFromNodeWithinBBox(qtNode.quad1, bb, fn, acc)
		end
		if bbox.intersects(qtNode.quad2.boundary, bb) then
			acc = deleteFromNodeWithinBBox(qtNode.quad2, bb, fn, acc)
		end
		if bbox.intersects(qtNode.quad3.boundary, bb) then
			acc = deleteFromNodeWithinBBox(qtNode.quad3, bb, fn, acc)
		end
		if bbox.intersects(qtNode.quad4.boundary, bb) then
			acc = deleteFromNodeWithinBBox(qtNode.quad4, bb, fn, acc)
		end
		if acc and childrensAreEmpty(qtNode) then
			forgetChildren(qtNode)
		end
	end
	return acc
end

---Run a function for each point in the quad tree node
---@param qtNode QuadTreeNode
---@param fn fun(p: Point):any
local function forEachNode(qtNode, fn)
	if qtNode == nil then
		return
	end
	for _, p in ipairs(qtNode.points) do
		fn(p)
	end
	if qtNode.subdivided then
		forEachNode(qtNode.quad1, fn)
		forEachNode(qtNode.quad2, fn)
		forEachNode(qtNode.quad3, fn)
		forEachNode(qtNode.quad4, fn)
	end
end

---Run a function for each point falling within a bbox in the quad tree node
---@param qtNode QuadTreeNode
---@param bb BBox
---@param fn fun(p: Point):any
local function forEachNodeWithinBBox(qtNode, bb, fn)
	if not bbox.intersects(qtNode.boundary, bb) then
		return
	end
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) then
			fn(point)
		end
	end
	if qtNode.subdivided then
		if bbox.intersects(qtNode.quad1.boundary, bb) then
			forEachNodeWithinBBox(qtNode.quad1, bb, fn)
		end
		if bbox.intersects(qtNode.quad2.boundary, bb) then
			forEachNodeWithinBBox(qtNode.quad2, bb, fn)
		end
		if bbox.intersects(qtNode.quad3.boundary, bb) then
			forEachNodeWithinBBox(qtNode.quad3, bb, fn)
		end
		if bbox.intersects(qtNode.quad4.boundary, bb) then
			forEachNodeWithinBBox(qtNode.quad4, bb, fn)
		end
	end
end

---Moves a given point to new position in the QuadTreeNode
---@param qt QuadTree
---@param qtNode QuadTreeNode
---@param point Vector2
---@param newPosition Vector2
---@param fn ?fun(p: Point): boolean If this function returns true, then it will move the point, otherwise leave
---@param acc Point[]?
---@return Point[]? Array of moved points
local function movePointInNode(qt, qtNode, point, newPosition, fn, acc)
	if not bbox.contains(qtNode.boundary, point) then
		return acc
	end
	if bbox.contains(qtNode.boundary, newPosition) then
		for idx, p in ipairs(qtNode.points) do
			if vector2.equal(point, p.point) and (fn == nil or fn(p)) then
				if acc == nil then
					acc = {}
				end
				table.insert(acc, p)
				qtNode.points[idx] = { point = newPosition, data = p.data }
			end
		end
	else
		---@type Point[]
		local pointsToReinsert = {}
		---@type Point[]
		local newQtNodePoints = {}
		for _, p in ipairs(qtNode.points) do
			if vector2.equal(point, p.point) and (fn == nil or fn(p)) then
				if acc == nil then
					acc = {}
				end
				table.insert(acc, p)
				table.insert(pointsToReinsert, { point = newPosition, data = p.data })
			else
				table.insert(newQtNodePoints, p)
			end
		end
		if #pointsToReinsert > 0 then
			qtNode.points = newQtNodePoints
			quadTree.insertMany(qt, pointsToReinsert)
		end
	end
	if qtNode.subdivided then
		if bbox.contains(qtNode.quad1.boundary, point) then
			acc = movePointInNode(qt, qtNode.quad1, point, newPosition, fn, acc)
		end
		if bbox.contains(qtNode.quad2.boundary, point) then
			acc = movePointInNode(qt, qtNode.quad2, point, newPosition, fn, acc)
		end
		if bbox.contains(qtNode.quad3.boundary, point) then
			acc = movePointInNode(qt, qtNode.quad3, point, newPosition, fn, acc)
		end
		if bbox.contains(qtNode.quad4.boundary, point) then
			acc = movePointInNode(qt, qtNode.quad4, point, newPosition, fn, acc)
		end
		if acc and childrensAreEmpty(qtNode) then
			forgetChildren(qtNode)
		end
	end
	return acc
end

---Creates a new QuadTree of a certain boundary, capacity, maxDepth
---@param boundary BBox Boundary of the QuadTree root
---@param capacity number
---@param maxDepth number
---@return QuadTree
function quadTree.new(boundary, capacity, maxDepth)
	return { root = newNode(boundary, 1), capacity = capacity, maxDepth = maxDepth }
end

---Add a point to the given QuadTree
---@param qt QuadTree
---@param point Point
---@return boolean ok Returns true if the point was added to the quad tree, otherwise returns false
function quadTree.insert(qt, point)
	return insertIntoNode(qt.root, qt.capacity, qt.maxDepth, point)
end

---Inserts multiple points to the given QuadTree
---@param qt QuadTree
---@param points Point[]
---@return number count Returns the count of points which were added to the quad tree
function quadTree.insertMany(qt, points)
	local count = 0
	for _, point in ipairs(points) do
		if quadTree.insert(qt, point) then
			count = count + 1
		end
	end
	return count
end

---Checks if a point is present in the QuadTree
---@param qt QuadTree
---@param point Vector2
---@return Point?
function quadTree.check(qt, point)
	return checkPointInNode(qt.root, point)
end

---Returns all the points that lie inside a given bounding box
---@param qt QuadTree
---@param bb BBox
---@return Point[]?
function quadTree.queryBBox(qt, bb)
	return queryBBoxFromNode(qt.root, bb, nil)
end

---Delete a given point from the QuadTree
---@param qt QuadTree
---@param point Vector2
---@param fn fun(p: Point): boolean If this function returns true, then it will delete the point, otherwise leave
---@return Point[]? Array of deleted points at the point
function quadTree.delete(qt, point, fn)
	return deleteFromNode(qt.root, point, fn, nil)
end

---Delete points within a BBox from the QuadTree
---@param qt QuadTree
---@param bb BBox
---@param fn ?fun(p: Point): boolean If this function returns true, then it will delete the point, otherwise leave
---@return Point[]? deletedPoints Points from QuadTree that lie within the BBox and are now deleted from the QuadTree
function quadTree.deleteWithinBBox(qt, bb, fn)
	return deleteFromNodeWithinBBox(qt.root, bb, fn, nil)
end

---Run a function for each point in the quad tree
---@param qt QuadTree
---@param fn fun(p: Point):any
function quadTree.forEach(qt, fn)
	forEachNode(qt.root, fn)
end

---Run a function for each point falling within a bbox in the quad tree
---@param qt QuadTree
---@param bb BBox
---@param fn fun(p: Point):any
function quadTree.forEachWithinBBox(qt, bb, fn)
	forEachNodeWithinBBox(qt.root, bb, fn)
end

---Moves the given point to the new position in the quad tree
---@param qt QuadTree
---@param point Vector2
---@param newPosition Vector2
---@param fn ?fun(p: Point): boolean If this function returns true, then it will move the point, otherwise leave
---@return Point[]? Array of moved points
function quadTree.movePoint(qt, point, newPosition, fn)
	if vector2.equal(point, newPosition) then
		return nil
	end
	return movePointInNode(qt, qt.root, point, newPosition, fn)
end

return quadTree
