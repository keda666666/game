local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
-- local PayConfig = require "common.resource.PayConfig"
-- local config = require "logic.dbbase.config"

local HolyShit = 101	-- 单人推送天降好礼
local GodLike = 102		-- 条件推送天降好礼

local RechargeNo 		= 1		-- 充值购买活动
local YuanbaoNo 		= 2		-- 元宝购买活动
local _PayPrice = {}

local AddRecharge		= 1			-- 活动开始后累计充值金额
local AddPayYuanbao		= 2			-- 活动开始后累计元宝消耗
local OneRecharge		= 3			-- 活动开始后单次充值金额

local _PayTypeList = {
	[HolyShit]	= require "rechargew.RechargeHolyShit",		-- 单人推送天降好礼
	[GodLike]	= require "rechargew.RechargeGodLike",		-- 条件推送天降好礼
}

local HeavenGifts = oo.class()

function HeavenGifts:ctor()
	
end

function HeavenGifts:Init()
	self.payTypeList = {}
	for payType, Mod in pairs(_PayTypeList) do
		self.payTypeList[payType] = Mod.new(self, payType)
	end
	self.rechargeHolyShit = self.payTypeList[HolyShit]
	self.rechargeGodLike = self.payTypeList[GodLike]
	for payType, rMod in pairs(self.payTypeList) do
		rMod:Init()
		server.rechargeCenter:AddRechargeMod(payType, rMod)
	end
end

-- function HeavenGifts:Save()
-- 	self.rechargeGodLike:Save()
-- end

function HeavenGifts:GetGifts(player, rMod)
	local tmp = rMod:GetBlob(player)
	if not tmp.list then
		tmp.list = {}
		tmp.ignore = {}
		tmp.gindex = 0
	end
	tmp.ignore = tmp.ignore or {}
	return tmp.list, tmp.ignore
end

function HeavenGifts:AddOne(cfg, player, rMod)
	local gifts = self:GetGifts(player, rMod)
	if not cfg.startTime then
		cfg.startTime = lua_app.now()
	end
	local gift = { config = cfg, info = {
		payType = cfg.payType,
		gid = cfg.gid,
		nopop = false,
		step = 0,
		steps = {},
		getnum = {},
		gindexlist = {},
	} }
	for i, _ in ipairs(cfg.awards) do
		table.insert(gift.info.steps, 0)
		table.insert(gift.info.getnum, 0)
	end
	gifts[cfg.gid] = gift
	if lua_app.now() < gift.config.endTime then
		server.sendReq(player, "sc_rechargew_shit", gift)
	end
end

function HeavenGifts:CloseOne(gid, player, rMod, dTime)
	local gift = self:GetGifts(player, rMod)[gid]
	if not gift then
		return
	end
	local nowTime = lua_app.now() - (dTime or 0)
	if gift.config.endTime > nowTime then
		gift.config.endTime = nowTime
		server.sendReq(player, "sc_rechargew_shitclose", {
				payType = gift.config.payType,
				gid = gift.config.gid,
			})
	end
end

function HeavenGifts:DayTimer(player)
	local nowTime = lua_app.now()
	for payType, rMod in pairs(self.payTypeList) do
		local gifts = self:GetGifts(player, rMod)
		for _, gift in pairs(gifts) do
			if gift.config.dayRefresh > 0 and nowTime >= gift.config.startTime and nowTime < gift.config.endTime then
				for i, _ in ipairs(gift.config.awards) do
					gift.info.getnum[i] = 0
				end
				if gift.config.dayRefresh == 2 then
					gift.info.step = 0
					for i, _ in ipairs(gift.config.awards) do
						gift.info.steps[i] = 0
					end
				end
				server.sendReq(player, "sc_rechargew_shitstep", gift.info)
			end
		end
	end
end

function HeavenGifts:onLogin(player)
	local nowTime = lua_app.now()
	for payType, rMod in pairs(self.payTypeList) do
		local gifts = self:GetGifts(player, rMod)
		local removes, sends = {}, {}
		for gid, gift in pairs(gifts) do
			if nowTime < gift.config.endTime then
				table.insert(sends, gift)
			elseif nowTime >= gift.config.endTime + 3600 then
				table.insert(removes, gid)
			else
				local finish = true
				for i, v in ipairs(gift.config.awards) do
					if gift.info.getnum[i] ~= (v.buycount or 1) then
						finish = false
						break
					end
				end
				if finish then
					table.insert(removes, gid)
				end
			end
		end
		if #sends > 0 then
			server.sendReq(player, "sc_rechargew_shitinit", { initinfo = sends})
		end
		for _, gid in pairs(removes) do
			gifts[gid] = nil
		end
	end
end

local _SetStep = {}
_SetStep[OneRecharge] = function(step, info, cfg)
	for i, target in ipairs(cfg.targets) do
		if step == target then
			info.steps[i] = info.steps[i] + step
			return
		end
	end
end

local _DelStep = {}
_DelStep[OneRecharge] = function(index, info, cfg)
	info.steps[index] = info.steps[index] - cfg.targets[index]
end

function HeavenGifts:onUpdateStep(player, condType, count)
	local step = math.floor(count)
	if step == 0 then return end
	local nowTime = lua_app.now()
	for payType, rMod in pairs(self.payTypeList) do
		local gifts = self:GetGifts(player, rMod)
		for _, gift in pairs(gifts) do
			if condType == gift.config.condType and nowTime >= gift.config.startTime and nowTime < gift.config.endTime then
				if _SetStep[condType] then
					_SetStep[condType](step, gift.info, gift.config)
				else
					gift.info.step = gift.info.step + step
				end
				server.sendReq(player, "sc_rechargew_shitstep", gift.info)
			end
		end
	end
end

local _GetStepOther = {}
_GetStepOther[OneRecharge] = function(info, index)
	return info.steps[index]
end

local function _GetStep(info, index, condType)
	if _GetStepOther[condType] then
		return _GetStepOther[condType](info, index)
	end
	return info.step
end

local function _GetHolyShitByGindex(gindex, gifts)
	for gid, gift in pairs(gifts) do
		for gidx, index in pairs(gift.info.gindexlist) do
			if gindex == gidx then
				return gid, gift, index
			end
		end
	end
end

local _GetRecharge = {}
_GetRecharge[RechargeNo] = function(player, gift, index)
	return gift.info.getnum[index] ~= (gift.config.awards[index].buycount or 1) and math.floor(gift.config.prices[index] or 0)
end

function HeavenGifts:GetRecharge(player, gindex, rMod)
	local gid, gift, index = _GetHolyShitByGindex(gindex, self:GetGifts(player, rMod))
	if not gid then
		lua_app.log_error("HeavenGifts:GetRecharge no gindex", gindex, player.account, player.dbid)
		return
	end
	return _GetRecharge[gift.config.gtype] and _GetRecharge[gift.config.gtype](player, gift, index)
end

local _GetYuanbao = {}
-- _GetYuanbao[RechargeNo] = function(player, gift)
-- 	return 0
-- end

function HeavenGifts:GetYuanbao(player, gift)
	return _GetYuanbao[gift.config.gtype] and _GetYuanbao[gift.config.gtype](player, gift) or 0
end

function HeavenGifts:Recharge(player, gindex, rMod)
	local gid, gift, index = _GetHolyShitByGindex(gindex, self:GetGifts(player, rMod))
	if not gid then
		lua_app.log_error("HeavenGifts:Recharge no gindex", gindex, player.account, player.dbid)
		return
	end
	local yuanbao = self:GetYuanbao(player, gift)
	lua_app.log_info(">> HeavenGifts:Recharge::", gift.config.payType, gid, gift.config.gtype, index, gindex,
		_GetStep(gift.info, index, gift.config.condType), gift.info.getnum[index] or 0, player.account, player.dbid)
	gift.info.gindexlist[gindex] = nil
	gift.info.index = index
	self:GetAward(player, gift.config.payType, gid)
	return yuanbao
end

_PayPrice[YuanbaoNo] = function(player, price, cfg)
	return player:PayYuanBao(price, server.baseConfig.YuanbaoRecordType.HeavenGifts, "HeavenGifts:" .. cfg.gid)
end

local function _GetAwardDefault(player, cfg, info, index)
	local award = cfg.awards[index]
	if not award then
		lua_app.log_error("_GetAwardDefault no award: payType, gid, index, step, getnum",
			cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
		return
	end
	if info.getnum[index] == (award.buycount or 1) then
		lua_app.log_info("_GetAwardDefault reget award: payType, gid, index, step, getnum",
			cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
		return
	end
	if cfg.targets[index] and cfg.targets[index] > _GetStep(info, index, cfg.condType) then
		lua_app.log_error("_GetAwardDefault not reach target: payType, gid, index, target, step, getnum",
			cfg.payType, cfg.gid, index, cfg.targets[index], _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
		return
	end
	if cfg.prices[index] and cfg.prices[index] > 0 then
		if not _PayPrice[cfg.gtype](player, math.floor(cfg.prices[index]), cfg) then
			return
		end
	end
	info.getnum[index] = (info.getnum[index] or 0) + 1
	return award.items, index
end

local function _GetGIndex(player, rMod)
	local tmp = rMod:GetBlob(player)
	tmp.gindex = (tmp.gindex + 1)%10000
	return tmp.gindex
end

local _GetAward = {}
_GetAward[RechargeNo] = function(player, cfg, info, index, rMod)
	if index then
		if cfg.prices[index] and cfg.prices[index]>0 then
			-- 先设置，等待付款后再给奖励
			if not cfg.awards[index] then
				lua_app.log_error("_GetAward[Recharge] no award: payType, gid, index, step, getnum",
					cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
				return
			end
			if cfg.targets[index] and cfg.targets[index] > _GetStep(info, index, cfg.condType) then
				lua_app.log_error("_GetAward[Recharge] not reach target: payType, gid, index, target, step, getnum",
					cfg.payType, cfg.gid, index, cfg.targets[index], _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
				return
			end
			if info.getnum[index] == (cfg.awards[index].buycount or 1) then
				lua_app.log_info("_GetAward[Recharge] reget award: payType, gid, index, step, getnum",
					cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
				return
			end
			local gindex = _GetGIndex(player, rMod)
			info.gindexlist[gindex] = index
			lua_app.log_info(">> _GetAward[Recharge] set gindex", cfg.payType, cfg.gid, cfg.gtype,
				index, cfg.prices[index], gindex, _GetStep(info, index, cfg.condType), info.getnum[index], player.account, player.dbid)
			server.sendReq(player, "sc_rechargew_shitindex", {
				payType = cfg.payType,
				gid = cfg.gid,
				index = gindex,
				price = cfg.prices[index],
			})
			return
		else
			if cfg.targets[index] and cfg.targets[index] > _GetStep(info, index, cfg.condType) then
				lua_app.log_error("_GetAward[Recharge] not reach target: payType, gid, index, target, step, getnum",
					cfg.payType, cfg.gid, index, cfg.targets[index], _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
				return
			end
			info.index = index
		end
	else
		index = info.index
		if not index then
			lua_app.log_error("_GetAward[Recharge] no index: payType, gid, step, getnum",
				cfg.payType, cfg.gid, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
			return
		end
	end
	local award = cfg.awards[index]
	if not award then
		lua_app.log_error("_GetAward[Recharge] no award: payType, gid, index, step, getnum",
			cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
		return
	end
	if info.getnum[index] == (award.buycount or 1) then
		lua_app.log_info("_GetAward[Recharge] reget award: payType, gid, index, step, getnum",
			cfg.payType, cfg.gid, index, _GetStep(info, index, cfg.condType), info.getnum[index], player.account)
		return
	end
	info.getnum[index] = (info.getnum[index] or 0) + 1
	info.index = nil
	return award.items, index
end

function HeavenGifts:GetAward(player, payType, gid, index)
	local rMod = self.payTypeList[payType]
	local gift = self:GetGifts(player, rMod)[gid]
	if not gift then
		lua_app.log_error("HeavenGifts:GetAward", gid, player.cache.name)
		return
	end
	local func = _GetAward[gift.config.gtype] or _GetAwardDefault
	local award, index = func(player, gift.config, gift.info, index, rMod)
	if award then
		if _DelStep[gift.config.condType] then
			_DelStep[gift.config.condType](index, gift.info, gift.config)
		end
		player:GiveRewardAsFullMailDefault(award, "天降馅饼", server.baseConfig.YuanbaoRecordType.HeavenGifts, "HeavenGifts:" .. gid)
		server.sendReq(player, "sc_rechargew_shitstep", gift.info)
		local otherinfo = {
			headtext = gift.config.headtext,
			content = gift.config.content,
			award = award,
		}
		local startTime = gift.config.startTime and os.date("%Y-%m-%d %X", gift.config.startTime)
		local endTime = os.date("%Y-%m-%d %X", gift.config.endTime)
		 server.serverCenter:SendDtbMod("httpr", "recordDatas", "LogHeavenGifts", player.cache.serverid, player.account, player.dbid, player.cache.name, payType, gid, index,
			gift.config.gtype, gift.config.prices[index], gift.config.condType, gift.config.targets[index], _GetStep(gift.info, index, gift.config.condType), startTime, endTime, otherinfo, player.ip)
	end
end

function HeavenGifts:SetPop(player, payType, gid, nopop)
	local gift = self:GetGifts(player, self.payTypeList[payType])[gid]
	if not gift then
		lua_app.log_error("HeavenGifts:SetPop", gid, player.cache.name)
		return
	end
	gift.info.nopop = nopop
end

server.SetCenter(HeavenGifts, "heavenGifts")
return HeavenGifts