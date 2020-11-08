local lua_util = require "lua_util"
local lua_math = {}

function lua_math.distance(point1,point2)
	local disx = point1.x - point2.x
	local disy = point1.y - point2.y
	return math.sqrt(disx * disx + disy * disy)
end

--判断圆形
function lua_math.incircle(point,mid,range)
	local dis = lua_math.distance(point,mid)
	return dis <= range
end

--判断扇形待优化 TODO
function lua_math.insector(point,midp,tarp,range,theta)
	local result = lua_math.incircle(point,midp,range)
	if result == false then
		return false
	end
	local len1 = lua_math.distance(tarp,midp)
	local len2 = lua_math.distance(point,midp)
	local dx1 = point.x - midp.x
	local dy1 = point.y - midp.y
	local dx2 = tarp.x - midp.x
	local dy2 = tarp.y - midp.y
	local angle = math.acos((dx1*dx2 + dy1*dy2)/(len1*len2))
	return angle < theta*math.pi/180
end

--判断凸多边形
function lua_math.inpolygon(point,points)
	local len = table.length(points)
	if len < 3 then
		return false
	end
	local bLeft
	if (point.y - points[1].y)*(points[2].x - points[1].x) - 
		(point.x - points[1].x)*(points[2].y -points[1].y) > 0 then
		bLeft = true
	else
		bLeft = false
	end
	
	for i = 2,#points do
		local bTemp
		local next = i + 1
		if i == #points then
			next = 1
		end
		if (point.y - points[i].y)*(points[next].x - points[i].x) - 
			(point.x - points[i].x)*(points[next].y -points[i].y) > 0 then
			bTemp = true
		else
			bTemp = false
		end

		if bLeft ~= bTemp then
			return false
		end
	end
	return true
end

local function mid(point1,point2)
	local dx = point2.posX - point1.posX
	local dy = point2.posY - point1.posY
	local point = {}
	point.posX = point1.posX + dx
	point.posY = point1.posY + dy
	return point
end

function lua_math.midpoint(ar)
	assert(#ar <= 3)
	if #ar == 1 then
		return ar
	end
	if #ar == 2 then
		return mid(ar[1],ar[2])
	end
	if #ar == 3 then
		return mid(mid(ar[1],ar[2]),ar[3])
	end
end

return lua_math
