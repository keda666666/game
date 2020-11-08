--四方向B*寻路
local DIR_NONE = 0
local DIR_LEFT = 1
local DIR_RIGHT = 2
local DIR_UP = 3
local DIR_DOWN = 4
local BLOCK = 1
local UNBLOCK = 0


local function GetNode(nodeArr,x)
	local node = nodeArr[x]
	if node == nil then
		node = {}
		node.visited = false
		node.x = 0
		node.y = 0
		node.dir = DIR_NONE
		nodeArr[x] = node
	end
	return node
end

local function CheckNode(nodeArr,x)
	local node = nodeArr[x]
	if node == nil then
		node = {}
		node.visited = false
		node.x = 0
		node.y = 0
		node.dir = DIR_NONE
		nodeArr[x] = node
		return false
	end
	return node.visited
end

local oo = require "class"
local BStar = oo.class()

function BStar:ctor()
	self.mapData = {}
	self.x = 100
	self.y = 100
	for i = 1,self.x*self.y do
		self.mapData[i] = UNBLOCK
	end
end

function BStar:Init(mapData)
	
end

function BStar:CheckRange(p)
	if p.x < 1 or p.y < 1 or p.x > self.x or p.y > self.y then
		return false
	end
	return true
end

function BStar:Find(start,target)
	local path = {}
	if start.x < 1 or start.y < 1 or target.x < 1 or target.y < 1 then
		return false,{}
	end
	if start.x >= self.x or start.y >= self.y or target.x >= self.x or target.y >= self.y then
		return false,{}
	end
	if self.mapData[start.x*start.y] == BLOCK or self.mapData[target.x*target.y] == BLOCK then
		return false,{}
	end

	if start.x == target.x and start.y == target.y then
		return true,{}
	end

	local curDir = DIR_LEFT
	local nextDir = DIR_NONE

	if math.abs(target.x - start.x) >= math.abs(target.y - start.y) then
		if target.x > start.x then
			curDir = DIR_RIGHT
		else
			curDir = DIR_LEFT
		end
	else
		if target.y > start.y then
			curDir = DIR_DOWN
		else
			curDir = DIR_UP
		end
	end

	local visit = {}
	local nodeArr = {}

	local pos = {}
	local cur = {}
	local next = {}
	local pos = {}

	cur = GetNode(nodeArr,self.x * (start.y-1) + start.x)
	cur.x = start.x
	cur.y = start.y
	cur.visited = true
	cur.dir = curDir
	table.insert(visit,cur)
	while #visit ~= 0 do
		cur = visit[#visit]
		curDir = cur.dir
		if cur.x == target.x and cur.y == target.y then
			for i = 1,#visit do
				table.insert(path,{visit[i].x,visit[i].y})
			end
			return true,path
		end
		if curDir == DIR_LEFT then
			pos.x = cur.x - 1
			pos.y = cur.y
		elseif curDir == DIR_RIGHT then
			pos.x = cur.x + 1
			pos.y = cur.y
		elseif curDir == DIR_DOWN then
			pos.x = cur.x
			pos.y = cur.y + 1
		elseif curDir == DIR_UP then
			pos.x = cur.x
			pos.y = cur.y - 1
		end


		if self:CheckRange(pos) == true and CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == false and self.mapData[pos.x*pos.y] == UNBLOCK then
			next = nodeArr[self.x * (pos.y-1) + pos.x]
			next.x = pos.x
			next.y = pos.y
			next.visited = true
			next.dir = curDir
			table.insert(visit,next)
			if curDir == DIR_LEFT or curDir == DIR_RIGHT then
				if next.x == target.x then
					if target.y >= cur.y then
						pos.x = cur.x
						pos.y = cur.y + 1
						if self:CheckRange(pos) == true and CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == false and self.mapData[pos.x*pos.y] == UNBLOCK then
							next.dir = DIR_DOWN
							curDir = DIR_DOWN
						end
					else
						pos.x = cur.x
						pos.y = cur.y - 1
						if self:CheckRange(pos) == true and CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == false and self.mapData[pos.x*pos.y] == UNBLOCK then
							next.dir = DIR_UP
							curDir = DIR_UP
						end
					end
				end
			elseif curDir == DIR_DOWN or curDir == DIR_UP then
				if next.y == target.y then
					if target.x >= cur.x then
						pos.x = cur.x + 1
						pos.y = cur.y
						if self:CheckRange(pos) == true and CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == false and self.mapData[pos.x*pos.y] == UNBLOCK then
							curDir = DIR_RIGHT
							next.dir = DIR_RIGHT
						end
					else
						pos.x = cur.x - 1
						pos.y = cur.y
						if self:CheckRange(pos) == true and CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == false and self.mapData[pos.x*pos.y] == UNBLOCK then
							next.dir = DIR_LEFT
							curDir = DIR_LEFT
						end
					end
				end
			end
		else
			if curDir == DIR_LEFT or curDir == DIR_RIGHT then
				if target.y >= cur.y then
					pos.x = cur.x
					pos.y = cur.y + 1
					nextDir = DIR_DOWN
					if self:CheckRange(pos) == false or CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == true or self.mapData[pos.x*pos.y] == BLOCK then
						pos.x = cur.x
						pos.y = cur.y - 1
						nextDir = DIR_UP
					end
				else
					pos.x = cur.x
					pos.y = cur.y - 1
					nextDir = DIR_UP
					if self:CheckRange(pos) == false or CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == true or self.mapData[pos.x*pos.y] == BLOCK then
						pos.x = cur.x
						pos.y = cur.y + 1
						nextDir = DIR_DOWN
					end
				end
			elseif curDir == DIR_DOWN or curDir == DIR_UP then
				if target.x >= cur.x then
					pos.x = cur.x + 1
					pos.y = cur.y
					nextDir = DIR_RIGHT
					if self:CheckRange(pos) == false or CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == true or self.mapDta[pos.x*pos.y] == BLOCK then
						pos.x = cur.x - 1
						pos.y = cur.y
						nextDir = DIR_LEFT
					end
				else
					pos.x = cur.x - 1
					pos.y = cur.y
					nextDir = DIR_LEFT
					if self:CheckRange(pos) == false or CheckNode(nodeArr,self.x*(pos.y-1)+pos.x) == true or self.mapData[pos.x*pos.y] == BLOCK then
						pos.x = cur.x + 1
						pos.y = cur.y
						nextDir = DIR_RIGHT
					end
				end
			end
			if self:CheckRange(pos) == false or CheckNode(nodeArr,self.x *(pos.y-1) + pos.x) == true or self.mapData[pos.x*pos.y] == BLOCK then
				table.remove(visit,#visit)
			else
				next = GetNode(nodeArr,self.x*(pos.y-1)+pos.x)
				next.x = pos.x
				next.y = pos.y
				next.visited = true
				next.dir = nextDir
				table.insert(visit,next)
			end
		end
	end
	return false
end

return BStar
