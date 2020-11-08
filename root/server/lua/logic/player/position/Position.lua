local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
--阵位

local Position = oo.class()

function Position:ctor(player)
	self.player = player
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.PositionSystem
end

function Position:onCreate()
	self:onLoad()
end

function Position:onLoad()
	--加载,计算属性
	self.cache = self.player.cache.position

	local stationConfig = server.configCenter.StationConfig
	for no,data in pairs(stationConfig) do
		if not self.cache.data[no] then
			self.cache.data[no] = {
				no = no,
				typ = 0,
			}
		end
	end
end

function Position:onInitClient()
	--登录发送
	self:SendInfo()
end

function Position:SendInfo()
	local msg = self:packInfo()
	server.sendReq(self.player, "sc_position_info",msg)
end

function Position:packInfo()
	local msg = {
		creatTime = self.player.cache.createtime,
		data = self.cache.data,
	}
	return msg
end

function Position:onLogout(player)
	--离线
end

function Position:onLogin(player)
	--加载后续处理？？
end

function Position:onDayTimer()
	--每天第一次登录或者跨天数据处理
end

function Position:onLevelUp(oldlevel, newlevel)
	--升级
end

--完成
function Position:AddClearNum(no, val)
	-- val = val or 1
	local data = self.cache.data[no]
	if not data then
		return
	end

	if data.typ > 0 then
		return
	end
	
	local stationConfig = server.configCenter.StationConfig
	if not stationConfig[no].dule or stationConfig[no].dule == val then
		if stationConfig[no].attrpower then
			if (lua_app.now() - self.player.cache.createtime) > stationConfig[no].attrpower then
				data.typ = 2
			else
				data.typ = 1
			end
		else
			data.typ = 1
		end
	end
	-- data.num = data.num + val
	-- if data.num >= stationConfig[no].dule then
	-- 	data.num = stationConfig[no].dule
	-- 	if stationConfig[no].attrpower then
	-- 		if (lua_app.now() - self.player.cache.createtime) > stationConfig[no].attrpower then
	-- 			data.typ = 2
	-- 		else
	-- 			data.typ = 1
	-- 		end
	-- 	else
	-- 		data.typ = 1
	-- 	end
	-- end
	self:SendInfo()
end

function Position:GetReward(no)
	local data = self.cache.data[no]
	if not data then
		return {ret = false}
	end
	if data.typ ~= 1 then
		return {ret = false}
	end

	local stationConfig = server.configCenter.StationConfig
	if not stationConfig[no] then
		return {ret = false}
	end

	local rewards = stationConfig[no].rewards
	data.typ = 3
	self.player:GiveRewardAsFullMailDefault(rewards, "阵位系统", self.YuanbaoRecordType, "阵位系统领取奖励"..no)

	self:SendInfo()
	return {ret = true}
end

server.playerCenter:SetEvent(Position, "position")
return Position