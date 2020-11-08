local server = require "server"
local lua_app = require "lua_app"
local FightConfig = require "resource.FightConfig"

local ChapterBoss = {}

function ChapterBoss:Init()
	self.type = server.raidConfig.type.ChapterBoss
	self.chapterlist = {}
	server.raidMgr:SetRaid(self.type, ChapterBoss)
end

function ChapterBoss:SendMonsterConfig(fbid, dbid)
	local data = {}
	local MonConfig = server.configCenter.Monsters2SConfig
	if server.serverid <= 4 then
		MonConfig = server.configCenter.Monsters3SConfig
	end
	for _, monsterinfo in pairs(server.configCenter.Instance2SConfig[fbid].initmonsters) do
		local moncfg = MonConfig[monsterinfo.monid]
		table.insert(data, {
			id			= moncfg.id,
			name		= moncfg.name,
			type		= moncfg.type,
			level		= moncfg.level,
			hp			= moncfg.hp,
			atk			= moncfg.atk,
			def			= moncfg.def,
			speed		= moncfg.speed,
			crit		= moncfg.crit,
			tough		= moncfg.tough,
			hitrate		= moncfg.hitrate,
			evade		= moncfg.evade,
			ms			= moncfg.ms,
			avatar		= moncfg.avatar,
			head		= moncfg.head,
		})
	end
	server.sendReqByDBID(dbid, "sc_raid_chapter_mondata", {
			mondata = data,
			fbcfg = server.configCenter.Instance2SConfig[fbid],
		})
end

function ChapterBoss:Enter(dbid, datas)
	local info = self.chapterlist[dbid]
	if not info then
		info = {}
		self.chapterlist[dbid] = info
	end
	if info.fighting then
		lua_app.log_error("ChapterBoss:Enter player is in fighting", dbid)
		return false
	end
	local exinfo = datas.exinfo
	info.chapterlevel = exinfo.chapterlevel

	local ChaptersConfig = server.configCenter.ChaptersConfig[exinfo.chapterlevel]
	self:SendMonsterConfig(ChaptersConfig.bossFid, dbid)

	if exinfo.assistantid then
		self:SendMonsterConfig(ChaptersConfig.bossFid, exinfo.assistantid)
		info.assistantid = exinfo.assistantid
	end

	local fighting = server.NewFighting()
	fighting:Init(ChaptersConfig.bossFid, self, nil, server.configCenter.Instance2SConfig[ChaptersConfig.bossFid].initmonsters)

	for i, playerdata in ipairs(datas.playerlist) do
		fighting:AddPlayer(FightConfig.Side.Attack, playerdata.playerinfo.dbid, playerdata, i)
	end

	info.fighting = fighting
	info.rewards = info.rewards or server.dropCenter:DropGroup(ChaptersConfig.reward)
	fighting:StartRunAll()
	return true
end

function ChapterBoss:Exit(dbid)
	local info = self.chapterlist[dbid]
	if info then
		if info.fighting then
			info.fighting:Release()
			info.fighting = nil
		end
		info.iswin = nil
	-- else
	-- 	lua_app.log_error("ChapterBoss:Exit no chapter fighting", dbid)
	end
	return true
end

function ChapterBoss:FightResult(retlist)
	for dbid, iswin in pairs(retlist) do
		local info = self.chapterlist[dbid]
		if info and info.fighting then
			info.fighting:BroadcastFighting()
			info.fighting:Release()
			info.fighting = nil
			local msg = {}
			if iswin then
				msg.result = 1
				msg.rewards = info.rewards
				local player = server.playerCenter:GetPlayerByDBID(dbid)
				player.chapter:NextChapterLevel()
				player.chapter:ResetWave()
				player.chapter:UpdateCollaborate(info.assistantid, info.chapterlevel)
			else
				msg.result = 0
				msg.rewards = {}
			end
			server.sendReqByDBID(dbid, "sc_raid_chapter_boss_result", msg)

			if info.assistantid then
				server.sendReqByDBID(info.assistantid, "sc_raid_chapter_boss_result", {
						result = iswin and 2 or 0,
						rewards = {},
					})
			end
		end
	end
end

function ChapterBoss:GetReward(dbid)
	local info = self.chapterlist[dbid]
	local rewards = info.rewards
	if rewards then
		info.rewards = nil
		local player = server.playerCenter:GetPlayerByDBID(dbid)
		player:GiveRewardAsFullMailDefault(rewards, "章节BOSS", server.baseConfig.YuanbaoRecordType.Chapter)
		if info.assistantid then
			local assistant = server.playerCenter:GetPlayerByDBID(info.assistantid)
			assistant.chapter:NoticeAssistWin(player.cache.name(), info.chapterlevel)
			info.assistantid = nil
		end
	end
end

server.SetCenter(ChapterBoss, "chapterBoss")
return ChapterBoss