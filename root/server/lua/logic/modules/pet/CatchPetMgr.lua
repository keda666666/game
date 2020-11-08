local server = require "server"
local lua_app = require "lua_app"
local WeightData = require "WeightData"
local tbname = "datalist"
local tbcolumn = "catchpet"

local CatchPetMgr = {}

local CATCH_STATE = {
	DISABLE = 0,
	FIRST = 1,
	NORMOL = 2,
}

function CatchPetMgr:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.waitfinishlist = self.cache.waitfinishlist
	self.waitcatchlist = {}
	self:SecondTimer()
end

function CatchPetMgr:Release()
	if self.cache then
		self.cache(true)
		self.cache = nil
	end
end

local _CatchPool = {}
function _GetPetByCatchPool(id)
	local catchContain = _CatchPool[id]
	if not catchContain then
		local CatchPetConfig = assert(server.configCenter.CatchPetConfig[id], string.format("not exist id:%d", id))
		catchContain = WeightData.new()
		for __, pet in ipairs(CatchPetConfig.catch) do
			catchContain:Add(pet.rate, pet)
		end
		_CatchPool[id] = catchContain
	end
	return catchContain:GetRandom()
end

function CatchPetMgr:onLogin(player)
	if self:CheckCatchAndJoinWait(player) then
		self:SendCatchMsg(player)
	end
end

function CatchPetMgr:UnlockCatch(player)
	if player.cache.catchpet.state == CATCH_STATE.DISABLE then
		player.cache.catchpet.state = CATCH_STATE.FIRST
		self:JoinWaitCatch(player)
	end
end

function CatchPetMgr:DisposeCatch(player)
	local catchinfo = self.waitfinishlist[player.dbid]
	local sucpro = catchinfo and catchinfo.sucpro or 0
	local succeed = self:CatchResult(sucpro)
	if succeed then
		local rewards = server.dropCenter:DropGroup(catchinfo.dropid)
		player:GiveRewardAsFullMailDefault(rewards, "捕捉宠物", server.baseConfig.YuanbaoRecordType.CatchPet, nil, 0)
	end
	server.sendReq(player, "sc_pet_catch_result", { 
			result = succeed,
		})
	player.cache.catchpet.state = CATCH_STATE.NORMOL
	self:JoinWaitCatch(player)
end

function CatchPetMgr:CatchResult(sucpro)
	local randomsucpro = math.random(1, 100)
	return randomsucpro <= sucpro
end

function CatchPetMgr:CheckCatchAndJoinWait(player)
	if not self.waitfinishlist[player.dbid] then
		self:JoinWaitCatch(player)
		return false
	end 
	return true
end

function CatchPetMgr:JoinWaitCatch(player)
	if player.cache.catchpet.state ~= CATCH_STATE.DISABLE then
		self.waitfinishlist[player.dbid] = nil
		self.waitcatchlist[player.dbid] = self:GetWaitTimeSec(player) + lua_app.now()
	end
end

function CatchPetMgr:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		self.sectimer = lua_app.add_timer(3000, _DoSecond)
		self:ScheduleCatch()
	end
	self.sectimer = lua_app.add_timer(3000, _DoSecond)
end

function CatchPetMgr:ScheduleCatch()
	local nowtime = lua_app.now()
	for dbid, waittime in pairs(self.waitcatchlist) do
		if waittime <= nowtime then
			self:Waitout(dbid)
		end
	end
end

function CatchPetMgr:Waitout(dbid)
	local player = server.playerCenter:DoGetPlayerByDBID(dbid)
	local catchCfg = self:GetCatchConfig(player)
	self.waitcatchlist[dbid] = nil
	local petCfg = _GetPetByCatchPool(catchCfg.id)
	self.waitfinishlist[dbid] = {
		monsterid = petCfg.monsterid,
		sucpro = petCfg.sucpro,
		dropid = petCfg.dropid
	}
	self:SendCatchMsg(player)
end

function CatchPetMgr:GetWaitTimeSec(player)
	local catchCfg = self:GetCatchConfig(player)
	local waittimeMinute = math.random(catchCfg.refreshTimeMin, catchCfg.refreshTimeMax)
	return waittimeMinute * 60
end


local _GetCfg = {}
_GetCfg[CATCH_STATE.FIRST] = function(player, CatchPetConfig)
	local GuideBaseConfig = server.configCenter.GuideBaseConfig
	return CatchPetConfig[GuideBaseConfig.firstpet]
end

_GetCfg[CATCH_STATE.NORMOL] = function(player, CatchPetConfig)
	local maxchapterLevel = CatchPetConfig[#CatchPetConfig].level
	local chapterlevel = math.min(player.cache.chapter.chapterlevel, maxchapterLevel)
	return table.matchValue(CatchPetConfig, function(subCfg)
		return subCfg.level - chapterlevel
	end)
end

function CatchPetMgr:GetCatchConfig(player)
	local CatchPetConfig = server.configCenter.CatchPetConfig
	return _GetCfg[player.cache.catchpet.state](player, CatchPetConfig)
end

function CatchPetMgr:SendCatchMsg(player)
	local catchinfo = self.waitfinishlist[player.dbid]
	server.sendReq(player, "sc_pet_catch", {
			monsterid = catchinfo.monsterid,
			catchtime = 0,
		})
end

function CatchPetMgr:onLogout(player)
	self.waitcatchlist[player.dbid] = nil
end

function CatchPetMgr:Release()
end

function CatchPetMgr:TestUnlock(player)
	player.cache.catchpet.state = 0
	self:UnlockCatch(player)
end

function CatchPetMgr:TestCatch(player)
	self.waitcatchlist[player.dbid] = lua_app.now()
end

server.SetCenter(CatchPetMgr, "catchPetMgr")
return CatchPetMgr
