local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
-- local config = require "logic.dbbase.config"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "recharge_godlike"
-- 条件推送天降好礼
local RechargeGodLike = oo.class()

function RechargeGodLike:ctor(heavenGifts, payType)
	self.heavenGifts = heavenGifts
	self.payType = payType
end

function RechargeGodLike:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	if not self.cache.list then
		self.cache.list = {}
		self.cache.willclose = {}
	end
	self.config = self.cache.list
	self.willclose = self.cache.willclose
end

function RechargeGodLike:Release()
	if self.cache then
		self.cache(true)
		-- self.cache = nil
	end
end

function RechargeGodLike:GetRecharge(player, gindex)
	return self.heavenGifts:GetRecharge(player, gindex, self)
end

function RechargeGodLike:Recharge(player, gindex)
	return self.heavenGifts:Recharge(player, gindex, self)
end

function RechargeGodLike:GetBlob(player)
	return player.cache.recharge_godlike
end

local _GetCheckValue = {}
_GetCheckValue[1] = function(player)		-- 注册时间
	return player.cache.createtime
end
_GetCheckValue[2] = function(player)		-- 最后登录时间
	return player.cache.lastonlinetime
end
-- _GetCheckValue[3] = function(player)		-- 区服
-- 	return player:Get(config.createtimenum)
-- end
_GetCheckValue[4] = function(player)		-- 角色等级
	return player.cache.level
end
_GetCheckValue[5] = function(player)		-- VIP等级
	return player.cache.vip
end
_GetCheckValue[6] = function(player)		-- 战斗力
	return player.cache.totalpower
end
_GetCheckValue[7] = function(player)		-- 累计登录天数
	return player.cache.totalloginday
end
_GetCheckValue[8] = function(player)		-- 现有元宝
	return player.cache.yuanbao
end
_GetCheckValue[9] = function(player)		-- 最后充值时间
	return player.cache.yuanbao.recharge_lasttime
end
_GetCheckValue[10] = function(player)	-- 单笔最大充值金额
	return player.cache.yuanbao.recharge_maxone
end

local function _CheckCondDefault(player, ctype, params)
	if not _GetCheckValue[ctype] then
		lua_app.log_error("_CheckCondDefault:: no ctype", ctype)
		return false
	end
	local cValue = _GetCheckValue[ctype](player)
	if params.min and cValue < params.min then return false end
	if params.max and cValue > params.max then return false end
	return true
end

local _CheckCond = {}
_CheckCond[11] = function(player, params, cfg, self)		-- 忽略后面的条件变化，一次不通过就直接无视
	local gifts, ignores = self.heavenGifts:GetGifts(player, self)
	if ignores[cfg.gid] then return false end
	return true
end

function RechargeGodLike:CheckAddActor(cfg, player)
	for _, cond in pairs(cfg.conditions) do
		if _CheckCond[cond.ctype] then
			if not _CheckCond[cond.ctype](player, cond.params, cfg, self) then
				local _, ignores = self.heavenGifts:GetGifts(player, self)
				ignores[cfg.gid] = true
				return
			end
		else
			if not _CheckCondDefault(player, cond.ctype, cond.params) then
				local _, ignores = self.heavenGifts:GetGifts(player, self)
				ignores[cfg.gid] = true
				return
			end
		end
	end
	self.heavenGifts:AddOne(cfg, player, self)
end

function RechargeGodLike:AddConfig(cfg)
	self.config[cfg.gid] = cfg
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		self:CheckAddActor(cfg, player)
	end
end

function RechargeGodLike:CloseConfig(gid)
	if not self.config[gid] then
		lua_app.log_error("RechargeGodLike:CloseConfig no gid", gid)
		return
	end
	self.config[gid] = nil
	self.willclose[gid] = lua_app.now() + 1800
	for _, player in pairs(server.playerCenter:GetOnlinePlayers()) do
		self.heavenGifts:CloseOne(gid, player, self)
	end
end

function RechargeGodLike:onBeforeLogin(player)
	local gifts, ignores = self.heavenGifts:GetGifts(player, self)
	for gid, gift in pairs(gifts) do
		if not self.config[gid] then
			if self.willclose[gid] then
				self.heavenGifts:CloseOne(gid, player, self)
			else
				self.heavenGifts:CloseOne(gid, player, self, 3600)
			end
		end
	end
	local remove = {}
	for gid, _ in pairs(ignores) do
		if not self.config[gid] then
			remove[gid] = true
		end
	end
	for gid, _ in pairs(remove) do
		ignores[gid] = nil
	end
	for gid, cfg in pairs(self.config) do
		if not gifts[gid] then
			self:CheckAddActor(cfg, player)
		end
	end
end

return RechargeGodLike