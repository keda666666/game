local oo = require "class"
local lua_app = require "lua_app"

-- 太经典了，我要写成C++
-- 根据权重查找数据的数据结构
local WeightData = oo.class()

local _LargerFunc = {}
function _LargerFunc.int(a, b)
	return a > b
end
function _LargerFunc.float(a, b)
	return a >= b
end

local _RandomFunc = {}
function _RandomFunc.int(max)
	return math.random(1, max)
end
function _RandomFunc.float(max)
	return math.random() * max
end

function WeightData:ctor(probType)
	self.datas = { [0] = { prob = 0 } }
	self.maxProb = 0
	self.maxindex = 0
	self.c_maxProb = 0
	self.largerFunc = _LargerFunc[probType or "int"]
	self.randomFunc = _RandomFunc[probType or "int"]
end

-- 添加权重值
function WeightData:Add(prob, value)
	self.maxindex = self.maxindex + 1
	self.maxProb = self.maxProb + prob
	self.c_maxProb = self.c_maxProb + prob
	self.datas[self.maxindex] = { prob = self.maxProb, dprob = prob, value = value }
	return self.maxindex
end

local function _FindProb(datas, prob, beginindex, endindex, largerFunc)
	if beginindex == endindex then
		return datas[beginindex].value, beginindex
	end
	local checkindex = beginindex + math.floor((endindex - beginindex)/2)
	if largerFunc(prob, datas[checkindex].prob) then
		return _FindProb(datas, prob, checkindex + 1, endindex, largerFunc)
	else
		return _FindProb(datas, prob, beginindex, checkindex, largerFunc)
	end
end

function WeightData:GetMaxProb()
	return self.maxProb
end

function WeightData:GetMaxValue()
	return self.datas[self.maxindex].value
end

function WeightData:Get(prob)
	if not self.largerFunc(prob, 0) or self.largerFunc(prob, self.maxProb) then return end
	return (_FindProb(self.datas, prob, 1, self.maxindex, self.largerFunc))
end

function WeightData:GetRandom()
	return (_FindProb(self.datas, self.randomFunc(self.maxProb), 1, self.maxindex, self.largerFunc))
end
-- 搜索num个随机值，需要num比较小
function WeightData:GetRandomCounts(num)
	local result = {}
	local getindexs = {}
	local probReduce = 0
	for i = 1, num do
		local prob = self.randomFunc(self.maxProb - probReduce)
		local beginindex, endindex = 1, self.maxindex
		for _, index in ipairs(getindexs) do
			if self.largerFunc(prob, self.datas[index - 1].prob) then
				prob = prob + self.datas[index].dprob
				beginindex = index + 1
			else
				endindex = index - 1
				break
			end
		end
		local value, index = _FindProb(self.datas, prob, beginindex, endindex, self.largerFunc)
		probReduce = probReduce + self.datas[index].dprob
		table.insert(getindexs, index)
		table.insert(result, value)
		table.sort(getindexs)
	end
	return result
end
-- 设置和获取变动权重，需要总个数比较小
function WeightData:C_SetValid(index, statu)
	local data = self.datas[index]
	if not data then
		lua_app.log_error("WeightData:C_SetValid:: no data", index)
		return
	end
	if statu then
		if not data.invalid then return end
		data.invalid = nil
		self.c_maxProb = self.c_maxProb + data.dprob
	else
		if data.invalid then return end
		data.invalid = true
		self.c_maxProb = self.c_maxProb - data.dprob
	end
end
function WeightData:C_GetRandom()
	local prob = self.randomFunc(self.c_maxProb)
	for index = 1, self.maxindex do
		local data = self.datas[index]
		if data.invalid then
			prob = prob + data.dprob
		else
			if not self.largerFunc(prob, data.prob) then
				return data.value
			end
		end
	end
	lua_app.log_error("WeightData:C_GetRandom:: no random result", prob, self.c_maxProb, self.maxindex, self.maxProb)
end

return WeightData