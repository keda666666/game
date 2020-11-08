local server = require "server"
local lua_app = require "lua_app"

local FightCenter = {}

function FightCenter:Init()
	self.fightlist = self.fightlist or {}
end

function FightCenter:SetFight(dbid, fighting)
	self.fightlist = self.fightlist or {}
	self.fightlist[dbid] = fighting
end

function FightCenter:GetFight(dbid)
	self.fightlist = self.fightlist or {}
	return self.fightlist[dbid]
end

function FightCenter:UseSkill(dbid, msg)
	local fighting = self:GetFight(dbid)
    if fighting then
    	fighting:ClientUseSkill(dbid, msg)
    end
end

function FightCenter:PlayFinish(dbid)
	local fighting = self:GetFight(dbid)
    if fighting then
    	fighting:PlayFinish(dbid)
    end
end

function FightCenter:SetAuto(dbid, isauto, isclient)
	local fighting = self:GetFight(dbid)
    if fighting then
    	fighting:SetAuto(dbid, isauto, isclient)
    end
end

function FightCenter:SendRecord(dbid, record)
	local msg = {}
	msg.events = {}
	for _, r in pairs(record) do
		if r.name == "sc_battle_entitys" then
			msg.raidType = r.msg.raidType
			msg.fbid = r.msg.fbid
			msg.manual = r.msg.manual
			msg.entitydatas = r.msg.entitydatas
		elseif r.name == "sc_battle_action" then
			for i,v in ipairs(r.msg.events) do
				table.insert(msg.events, v)
			end
		end
	end
	server.sendReqByDBID(dbid, "sc_battle_record", msg)
end

function server.FightCall(src, funcname, ...)
	lua_app.ret(server.fightCenter[funcname](server.fightCenter, ...))
end

function server.FightSend(src, funcname, ...)
	server.fightCenter[funcname](server.fightCenter, ...)
end

server.SetCenter(FightCenter, "fightCenter")
return FightCenter