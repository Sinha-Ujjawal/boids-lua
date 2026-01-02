local quadTree2 = {}

local vector2 = require("./vector2")
local bbox = require("./bbox")

---@class Point2
---@field point Vector2
---@field data  any

---@class QuadTreeNode2
---@field idx                number
---@field boundary           BBox
---@field points             Point2[]
---@field depth              number
---@field numPointsInSubtree number

---@class QuadTree2
---@field nodes    QuadTreeNode2[]
---@field capacity number
---@field maxDepth number

---Finds the first ancestor of a quad tree node which satisfies the filter
---@param idx number
---@param filter fun(q: QuadTreeNode2): boolean
---@return QuadTreeNode2?
local function findFirstAncestorSatifying(qt, idx, filter)
	if idx <= 1 or idx > #qt.nodes then
		return nil
	end
	local parentIdx = math.ceil((idx - 1) / 4)
	while parentIdx >= 1 and parentIdx <= #qt.nodes do
		if filter(qt.nodes[parentIdx]) then
			return qt.nodes[parentIdx]
		end
		if parentIdx == 1 then
			return nil
		end
		parentIdx = math.ceil((parentIdx - 1) / 4)
	end
	return nil
end

---Updates the count of the node given its children nodes
---@param qt QuadTree2
---@param idx number
local function updateCount(qt, idx)
	if idx < 1 or idx > #qt.nodes then
		return
	end
	local s = 4 * idx - 2
	local count = 0
	for off = 0, 3 do
		local child = qt.nodes[s + off]
		count = count + child.numPointsInSubtree + #child.points
	end
	qt.nodes[idx].numPointsInSubtree = count
end

---Add a point to the given QuadTreeNode2. If capacity is exceeded, it will insert to the appropriate children
---@param qt QuadTree2
---@param idx number
---@param capacity number
---@param maxDepth number
---@param point Point2
---@return boolean ok Returns true if the point was added to the quad tree node, otherwise returns false
local function insertIntoNode(qt, idx, capacity, maxDepth, point)
	local qtNode = qt.nodes[idx]
	if not bbox.contains(qtNode.boundary, point.point) then
		return false
	end

	if qtNode.depth >= maxDepth or #qtNode.points < capacity then
		qtNode.points[#qtNode.points + 1] = point
		return true
	end

	local s = 4 * idx - 2
	local ret = insertIntoNode(qt, s + 0, capacity, maxDepth, point)
		or insertIntoNode(qt, s + 1, capacity, maxDepth, point)
		or insertIntoNode(qt, s + 2, capacity, maxDepth, point)
		or insertIntoNode(qt, s + 3, capacity, maxDepth, point)
	if ret then
		qtNode.numPointsInSubtree = qtNode.numPointsInSubtree + 1
	end
	return ret
end

---Checks if a point is present in the QuadTreeNode2
---@param qt QuadTree2
---@param idx number
---@param point Vector2
---@return Point2?
local function checkPointInNode(qt, idx, point)
	local qtNode = qt.nodes[idx]
	if not bbox.contains(qtNode.boundary, point) then
		return nil
	end
	for _, p in ipairs(qtNode.points) do
		if vector2.equal(point, p.point) then
			return p
		end
	end
	local s = 4 * idx - 2
	if qtNode.numPointsInSubtree > 0 then
		return checkPointInNode(qt, s + 0, point)
			or checkPointInNode(qt, s + 1, point)
			or checkPointInNode(qt, s + 2, point)
			or checkPointInNode(qt, s + 3, point)
	end
	return nil
end

---Returns all the points that lie inside a given bounding box
---@param qt QuadTree2
---@param idx number
---@param bb BBox
---@param acc Point2[]?
---@return Point2[]?
local function queryBBoxFromNode(qt, idx, bb, acc)
	local qtNode = qt.nodes[idx]
	if not bbox.intersects(qtNode.boundary, bb) then
		return acc
	end
	if acc == nil then
		acc = {}
	end
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) then
			acc[#acc + 1] = point
		end
	end
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.intersects(qt.nodes[s + off].boundary, bb) then
				acc = queryBBoxFromNode(qt, s + off, bb, acc)
			end
		end
	end
	return acc
end

---Delete a given point from the QuadTreeNode2
---@param qt QuadTree2
---@param idx number
---@param point Vector2
---@param fn fun(p: Point2): boolean If this function returns true, then it will delete the point, otherwise leave
---@param acc Point2[]?
---@return Point2[]?
local function deleteFromNode(qt, idx, point, fn, acc)
	local qtNode = qt.nodes[idx]
	if not bbox.contains(qtNode.boundary, point) then
		return acc
	end
	---@type Point2[]
	local nonDeletedPoint2s = {}
	for _, p in ipairs(qtNode.points) do
		if vector2.equal(point, p.point) and fn(p) then
			if acc == nil then
				acc = {}
			end
			acc[#acc + 1] = p
		else
			nonDeletedPoint2s[#nonDeletedPoint2s + 1] = p
		end
	end
	qtNode.points = nonDeletedPoint2s
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.contains(qt.nodes[s + off].boundary, point) then
				local before = (acc and #acc) or 0
				acc = deleteFromNode(qt, s + off, point, fn, acc)
				local after = (acc and #acc) or 0
				qtNode.numPointsInSubtree = qtNode.numPointsInSubtree - (after - before)
			end
		end
	end
	return acc
end

---Delete points within a BBox from the QuadTreeNode2
---@param qt QuadTree2
---@param idx number
---@param bb BBox
---@param fn ?fun(p: Point2): boolean If this function returns true, then it will delete the point, otherwise leave
---@param acc Point2[]?
---@return Point2[]?
local function deleteFromNodeWithinBBox(qt, idx, bb, fn, acc)
	local qtNode = qt.nodes[idx]
	if not bbox.intersects(qtNode.boundary, bb) then
		return acc
	end
	---@type Point2[]
	local nonDeletedPoint2s = {}
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) and (fn == nil or fn(point)) then
			if acc == nil then
				acc = {}
			end
			acc[#acc + 1] = point
		else
			nonDeletedPoint2s[#nonDeletedPoint2s + 1] = point
		end
	end
	qtNode.points = nonDeletedPoint2s
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.intersects(qt.nodes[s + off].boundary, bb) then
				local before = (acc and #acc) or 0
				acc = deleteFromNodeWithinBBox(qt, s + off, bb, fn, acc)
				local after = (acc and #acc) or 0
				qtNode.numPointsInSubtree = qtNode.numPointsInSubtree - (after - before)
			end
		end
	end
	return acc
end

---Run a function for each point in the quad tree node
---@param qt QuadTree2
---@param idx number
---@param fn fun(p: Point2):any
local function forEachNode(qt, idx, fn)
	local qtNode = qt.nodes[idx]
	if qtNode == nil then
		return
	end
	for _, p in ipairs(qtNode.points) do
		fn(p)
	end
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			forEachNode(qt, s + off, fn)
		end
	end
end

---Run a function for each point falling within a bbox in the quad tree node
---@param qt QuadTree2
---@param idx number
---@param bb BBox
---@param fn fun(p: Point2):any
local function forEachNodeWithinBBox(qt, idx, bb, fn)
	local qtNode = qt.nodes[idx]
	if not bbox.intersects(qtNode.boundary, bb) then
		return
	end
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) then
			fn(point)
		end
	end
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.intersects(qt.nodes[s + off].boundary, bb) then
				forEachNodeWithinBBox(qt, s + off, bb, fn)
			end
		end
	end
end

---Run a function for each point falling within a scope in the quad tree node
---A scope is a bbox (main) and an offset with width and height defining bbox for each
---point that lies inside the main bbox.
---@param qt QuadTree2
---@param idx number
---@param bb BBox
---@param ox number
---@param oy number
---@param wx number
---@param wy number
---@param fn fun(p: Point2, neighborsWithinScope: Point2[]):any
local function forEachNodeWithinScope(qt, idx, bb, ox, oy, wx, wy, fn)
	local qtNode = qt.nodes[idx]
	if not bbox.intersects(qtNode.boundary, bb) then
		return
	end
	for _, point in ipairs(qtNode.points) do
		if bbox.contains(bb, point.point) then
			---@type Point2[]
			local neighborsWithinScope = {}
			local bboxAroundPoint2 = bbox.new(point.point.x + ox, point.point.y + oy, wx, wy)
			if qtNode.idx == 1 or bbox.containsBBox(qtNode.boundary, bboxAroundPoint2) then
				forEachNodeWithinBBox(qt, qtNode.idx, bboxAroundPoint2, function(p)
					neighborsWithinScope[#neighborsWithinScope + 1] = p
				end)
			else
				local validAncestor = findFirstAncestorSatifying(qt, qtNode.idx, function(q)
					return q.idx == 1 -- is the root
						or bbox.containsBBox(q.boundary, bboxAroundPoint2)
				end)
				assert(validAncestor ~= nil)
				forEachNodeWithinBBox(qt, validAncestor.idx, bboxAroundPoint2, function(p)
					neighborsWithinScope[#neighborsWithinScope + 1] = p
				end)
			end
			fn(point, neighborsWithinScope)
		end
	end
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.intersects(qt.nodes[s + off].boundary, bb) then
				forEachNodeWithinScope(qt, s + off, bb, ox, oy, wx, wy, fn)
			end
		end
	end
end

---Moves a given point to new position in the QuadTreeNode2
---@param qt QuadTree2
---@param idx number
---@param point Vector2
---@param newPosition Vector2
---@param fn ?fun(p: Point2): boolean If this function returns true, then it will move the point, otherwise leave
---@param acc Point2[]?
---@return Point2[]? Array of moved points
local function movePointInNode(qt, idx, point, newPosition, fn, acc)
	local qtNode = qt.nodes[idx]
	if not bbox.contains(qtNode.boundary, point) then
		return acc
	end
	if bbox.contains(qtNode.boundary, newPosition) then
		for i, p in ipairs(qtNode.points) do
			if vector2.equal(point, p.point) and (fn == nil or fn(p)) then
				if acc == nil then
					acc = {}
				end
				acc[#acc + 1] = p
				qtNode.points[i] = { point = newPosition, data = p.data }
			end
		end
	else
		---@type Point2[]
		local pointsToReinsert = {}
		---@type Point2[]
		local newQtNodePoint2s = {}
		for _, p in ipairs(qtNode.points) do
			if vector2.equal(point, p.point) and (fn == nil or fn(p)) then
				if acc == nil then
					acc = {}
				end
				acc[#acc + 1] = p
				pointsToReinsert[#pointsToReinsert + 1] = { point = newPosition, data = p.data }
			else
				newQtNodePoint2s[#newQtNodePoint2s + 1] = p
			end
		end
		if #pointsToReinsert > 0 then
			qtNode.points = newQtNodePoint2s
			---@type QuadTreeNode2?
			local nearestRoot = qtNode
			if qtNode.idx > 1 then
				nearestRoot = findFirstAncestorSatifying(qt, qtNode.idx, function(q)
					return q.idx == 1 or bbox.contains(q.boundary, newPosition)
				end)
			end
			assert(nearestRoot ~= nil)
			for _, p in ipairs(pointsToReinsert) do
				insertIntoNode(qt, nearestRoot.idx, qt.capacity, qt.maxDepth, p)
			end
		end
	end
	if qtNode.numPointsInSubtree > 0 then
		local s = 4 * idx - 2
		for off = 0, 3 do
			if bbox.contains(qt.nodes[s + off].boundary, point) then
				acc = movePointInNode(qt, s + off, point, newPosition, fn, acc)
				updateCount(qt, idx)
			end
		end
	end
	return acc
end

---Creates a new QuadTree2 of a certain boundary, capacity, maxDepth
---@param boundary BBox Boundary of the QuadTree2 root
---@param capacity number
---@param maxDepth number
---@return QuadTree2
function quadTree2.new(boundary, capacity, maxDepth)
	---Create a new QuadTreeNode2 with a given boundary
	---@param idx number Index of the QuadTreeNode2
	---@param newNodeBoundary BBox Boundary of the QuadTreeNode2
	---@param depth number
	---@param parent QuadTreeNode2?
	---@return QuadTreeNode2
	local function newNode(idx, newNodeBoundary, depth, parent)
		return {
			idx = idx,
			boundary = newNodeBoundary,
			points = {},
			depth = depth,
			parent = parent,
			numPointsInSubtree = 0,
		}
	end
	---@type QuadTreeNode2[]
	local nodes = { newNode(1, boundary, 0, nil) }
	for d = 1, maxDepth do
		local startIndex = 4 * d - 2
		local endIndex = startIndex + 4 ^ d - 1
		for i = startIndex, endIndex, 4 do
			local parentIdx = math.ceil((i - 1) / 4)
			local parentBoundary = nodes[parentIdx].boundary
			local boundary1, boundary2, boundary3, boundary4 = bbox.toQuads(parentBoundary)
			nodes[i] = newNode(i, boundary1, d, nodes[parentIdx])
			nodes[i + 1] = newNode(i + 1, boundary2, d, nodes[parentIdx])
			nodes[i + 2] = newNode(i + 2, boundary3, d, nodes[parentIdx])
			nodes[i + 3] = newNode(i + 3, boundary4, d, nodes[parentIdx])
		end
	end
	return { nodes = nodes, capacity = capacity, maxDepth = maxDepth }
end

---Returns the number of points in the quad tree
---@param qt QuadTree2
---@return number
function quadTree2.count(qt)
	return qt.nodes[1].numPointsInSubtree + #qt.nodes[1].points
end

---Add a point to the given QuadTree2
---@param qt QuadTree2
---@param point Point2
---@return boolean ok Returns true if the point was added to the quad tree, otherwise returns false
function quadTree2.insert(qt, point)
	return insertIntoNode(qt, 1, qt.capacity, qt.maxDepth, point)
end

---Inserts multiple points to the given QuadTree2
---@param qt QuadTree2
---@param points Point2[]
---@return number count Returns the count of points which were added to the quad tree
function quadTree2.insertMany(qt, points)
	local count = 0
	for _, point in ipairs(points) do
		if quadTree2.insert(qt, point) then
			count = count + 1
		end
	end
	return count
end

---Checks if a point is present in the QuadTree2
---@param qt QuadTree2
---@param point Vector2
---@return Point2?
function quadTree2.check(qt, point)
	return checkPointInNode(qt, 1, point)
end

---Returns all the points that lie inside a given bounding box
---@param qt QuadTree2
---@param bb BBox
---@return Point2[]?
function quadTree2.queryBBox(qt, bb)
	return queryBBoxFromNode(qt, 1, bb, nil)
end

---Delete a given point from the QuadTree2
---@param qt QuadTree2
---@param point Vector2
---@param fn fun(p: Point2): boolean If this function returns true, then it will delete the point, otherwise leave
---@return Point2[]? Array of deleted points at the point
function quadTree2.delete(qt, point, fn)
	return deleteFromNode(qt, 1, point, fn, nil)
end

---Delete points within a BBox from the QuadTree2
---@param qt QuadTree2
---@param bb BBox
---@param fn ?fun(p: Point2): boolean If this function returns true, then it will delete the point, otherwise leave
---@return Point2[]? deletedPoint2s Point2s from QuadTree2 that lie within the BBox and are now deleted from the QuadTree2
function quadTree2.deleteWithinBBox(qt, bb, fn)
	return deleteFromNodeWithinBBox(qt, 1, bb, fn, nil)
end

---Run a function for each point in the quad tree
---@param qt QuadTree2
---@param fn fun(p: Point2):any
function quadTree2.forEach(qt, fn)
	forEachNode(qt, 1, fn)
end

---Run a function for each point falling within a bbox in the quad tree
---@param qt QuadTree2
---@param bb BBox
---@param fn fun(p: Point2):any
function quadTree2.forEachWithinBBox(qt, bb, fn)
	forEachNodeWithinBBox(qt, 1, bb, fn)
end

---Run a function for each point falling within a scope in the quad tree
---A scope is a bbox (main) and an offset with width and height defining bbox for each
---point that lies inside the main bbox.
---@param qt QuadTree2
---@param bb BBox
---@param ox number
---@param oy number
---@param wx number
---@param wy number
---@param fn fun(p: Point2, neighborsWithinScope: Point2[]):any
function quadTree2.forEachWithinScope(qt, bb, ox, oy, wx, wy, fn)
	forEachNodeWithinScope(qt, 1, bb, ox, oy, wx, wy, fn)
end

---Moves the given point to the new position in the quad tree
---@param qt QuadTree2
---@param point Vector2
---@param newPosition Vector2
---@param fn ?fun(p: Point2): boolean If this function returns true, then it will move the point, otherwise leave
---@return Point2[]? Array of moved points
function quadTree2.movePoint(qt, point, newPosition, fn)
	if vector2.equal(point, newPosition) then
		return nil
	end
	return movePointInNode(qt, 1, point, newPosition, fn)
end

return quadTree2
