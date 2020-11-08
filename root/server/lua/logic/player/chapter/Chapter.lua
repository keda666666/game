local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local ItemConfig = require "resource.ItemConfig"
local DailyTaskConfig = require "resource.DailyTaskConfig"
local RankConfig = require "resource.RankConfig"

local Chapter = oo.class()

function Chapter:ctor(player)
    self.player = player
    
    self.wave = 0
	self.kills = 0
	self.changeTime = 0
	self.currentWaveTime = lua_app.now()
	self.rewards = {}
end

function Chapter:onCreate()
    self:onLoad()
end

function Chapter:onLoad()
    self.cache = self.player.cache.chapter
end

function Chapter:onInitClient()
	self:SendChapterInitInfo()
	self:NewChapterWave(true)
    self:SendCollaborate()
    server.serverCenter:SendLocalMod("world", "rankCenter", "SendRankDatas", self.player.dbid, RankConfig.RankType.CHAPTER)
end

function Chapter:ResetWave()
	self.wave = 0
	self.kills = 0
end

function Chapter:SendCollaborate()
    server.sendReq(self.player, "sc_raid_chapter_collaborate", {
            appealtime = self.cache.appealtime,
            helptime = self.cache.helptime,
        })
end

function Chapter:SendChapterInitInfo()
	local chapterLevel = self.cache.chapterlevel
    local chapterreward = self.cache.chapterreward
	local ChaptersConfig = server.configCenter.ChaptersConfig[chapterLevel]
	local Monsters2SConfig = server.configCenter.Monsters2SConfig
    if server.serverid <= 4 then
        Monsters2SConfig = server.configCenter.Monsters3SConfig
    end
    local MonstersConfig = Monsters2SConfig[ChaptersConfig.waveMonsterId[1]]
	local BossMonstersConfig = Monsters2SConfig[ChaptersConfig.bossId]
	local mons = {}
	for _, data in ipairs(ChaptersConfig.waveMonsterId) do
		table.insert(mons, Monsters2SConfig[data])
	end
    local rewardchapters = {}
    for chapterid, can in pairs(chapterreward) do
        if can then
            table.insert(rewardchapters, chapterid)
        end
    end
    server.sendReq(self.player,"sc_raid_chapter_init_info", {
		cid				= chapterLevel,
		chapterid		= ChaptersConfig.chapterid,
		sid				= ChaptersConfig.sid,
		minunm			= ChaptersConfig.minunm,
		maxnum			= ChaptersConfig.maxnum,
		waveMonsterId	= mons,
		bossNeedWave	= ChaptersConfig.bossNeedWave,
		bossId			= {
				configId 	= BossMonstersConfig.id,
				name 		= BossMonstersConfig.name,
				level 		= BossMonstersConfig.level,
                avatar		= BossMonstersConfig.avatar,
                talk        = BossMonstersConfig.talk,
			},
		showAward		= ChaptersConfig.showAward,
		desc			= ChaptersConfig.desc,
		goldEff			= ChaptersConfig.goldEff,
		expEff			= ChaptersConfig.expEff,

		killMonsterCount = self.wave,
        nextmap = self.cache.nextmap,
        chapterreward = rewardchapters,
    })
end

function Chapter:NextChapterLevel()
    local chapterreward = self.cache.chapterreward
    local chapterLevel = self.cache.chapterlevel
    local ChaptersConfig = server.configCenter.ChaptersConfig[chapterLevel]
    local nextchapterLevel = chapterLevel + 1
    local NextChaptersConfig = server.configCenter.ChaptersConfig[nextchapterLevel]
    local ChaptersMapConfig = server.configCenter.ChaptersMapConfig

    if NextChaptersConfig and ChaptersConfig then
        if NextChaptersConfig.chapterid > ChaptersConfig.chapterid then
            if not chapterreward[ChaptersConfig.chapterid] then
                chapterreward[ChaptersConfig.chapterid] = true
            end
        end
    end

    for k,v in pairs(ChaptersMapConfig) do
        if v.cid == chapterLevel then
            self.cache.nextmap = true
            break
        end
    end
    if not self.cache.nextmap then
        self.cache.chapterlevel = nextchapterLevel
    end
    self.player.shop:onUpdateUnlock()
    self.player.task:onEventCheck(server.taskConfig.ConditionType.ChapterClear)
    self.player.activityPlug:onDoTarget()
    self.player:CheckOpenFunc({type = server.funcOpen.CondType.Chapter, value = chapterLevel})
end

function Chapter:NewChapterWave(isnew)
    local ChaptersConfig = server.configCenter.ChaptersConfig[self.cache.chapterlevel]
    local dropEff = ChaptersConfig.dropEff / 3600
    local dropCount
    local nowTime = lua_app.now()
    if isnew then
    	if self.preWaveTime and (nowTime - self.preWaveTime) * dropEff < 4 then
    		dropCount = 0
    	else
	        dropCount = 1
    	end
    	self.preWaveTime = self.currentWaveTime
        self.changeTime = dropCount / dropEff
        self.currentWaveTime = nowTime
    else
    	self.preWaveTime = self.currentWaveTime
        if nowTime < self.currentWaveTime or nowTime > self.currentWaveTime + 300 then
            lua_app.log_info("Chapter:NewChapterWave: 注意注意，这不是一个错误，只不过是时间出问题了! self.playerid, nowTime, self.currentWaveTime", self.player.dbid, nowTime, self.currentWaveTime)
            dropCount = 1
            self.changeTime = 1 / dropEff
            self.currentWaveTime = nowTime
        else
            dropCount = math.floor(dropEff * (nowTime - self.currentWaveTime))
            self.changeTime = dropCount / dropEff
            self.currentWaveTime = self.currentWaveTime + self.changeTime
        end
    end
    local goldReward = {{
        type = ItemConfig.AwardType.Numeric,
        id = ItemConfig.NumericType.Gold,
        count = math.ceil(ChaptersConfig.goldEff / 3600 * self.changeTime),-- * (1+self.exgold/10000+self:GetMonthCardEx(self.player, 1))),
    }}
    self.rewards = { goldReward }
    local sendDatas = {
        wave = self.wave,
        kills = self.kills,
        count = ChaptersConfig.waveMonsterCount,
        rewards = {{
            index = 1,
            drops = goldReward,
        }},
    }
    for i = 2, dropCount + 1 do
        local ret = server.dropCenter:DropGroup(ChaptersConfig.offlineDropId)
        if #ret ~= 0 then
            table.insert(sendDatas.rewards, {
                index = i,
                drops = ret,
            })
            table.insert(self.rewards, ret)
        end
    end
    server.sendReq(self.player,"sc_raid_chapter_wave_data", sendDatas)
end

function Chapter:AssistAttack(dbid, chapterlevel)
    local target = server.playerCenter:GetPlayerByDBID(dbid)
    if not self:CheckAssist(target, chapterlevel) then
        return 1
    end
    local fightdatas = {
        playerlist = server.dataPack:TeamFightInfoByDBID({dbid, self.player.dbid}),
        exinfo = {
            chapterlevel = chapterlevel,
            assistantid = self.player.dbid,
        }
    }
    local lockids = {
        self.player.dbid,
    }
    if not server.raidMgr:Enter(server.raidConfig.type.ChapterBoss, dbid, fightdatas, lockids) then
        server.sendErr(self.player, ChaptersCommonConfig.notice_5)
    end
    return 0
end

function Chapter:CheckAssist(target, chapterlevel)
    local ChaptersCommonConfig = server.configCenter.ChaptersCommonConfig
    if target.cache.chapter.chapterlevel ~= chapterlevel then
        server.sendErr(self.player, ChaptersCommonConfig.notice_2)
        return false
    end

    if target.dbid == self.player.dbid then
        server.sendErr(self.player, ChaptersCommonConfig.notice_1)
        return false
    end

    if self.cache.helptime >= ChaptersCommonConfig.helptime then
        server.sendErr(self.player, ChaptersCommonConfig.notice_4)
        return false
    end

    if self.cache.chapterlevel <= chapterlevel then
        server.sendErr(self.player, ChaptersCommonConfig.notice_3)
        return false
    end

    if not target.isLogin then
        server.sendErr(self.player, ChaptersCommonConfig.notice_6)
        return false
    end

    if server.raidMgr:IsInRaid(target.dbid) or server.raidMgr:IsInRaid(self.player.dbid) then
        server.sendErr(self.player, ChaptersCommonConfig.notice_5)
        return false
    end
    return true
end

function Chapter:NoticeAssistWin(targetname, chapterlevel)
    local ChaptersConfig = server.configCenter.ChaptersConfig[chapterlevel]
    server.chatCenter:ChatLink(21, self.player, nil, self.player.cache.name, targetname, ChaptersConfig.desc)
end

function Chapter:ReqNextWave(killCount)
    local ChaptersConfig = server.configCenter.ChaptersConfig[self.cache.chapterlevel]
    local exp = math.ceil(ChaptersConfig.expEff/3600*self.changeTime)--*(1 + self.exgold / 10000 +self:GetMonthCardEx(self.player, 2)))
    exp = self.player.marry:GetMarryExpAddition(exp)
    local rewards = ItemConfig:MergeRewardsList(self.rewards)
    local isVipCard = self.player.welfare:IsRewardUp()
    local isForeverUp = self.player.welfare:IsForeverUp()
    local rewardUp = isVipCard + isForeverUp
    if rewardUp ~= 0 then
        exp = math.floor(exp * (1 + rewardUp))
        for _,v in pairs(rewards) do
            if v.type == ItemConfig.AwardType.Numeric and 
            (v.id == ItemConfig.NumericType.Exp or v.id == ItemConfig.NumericType.Gold) then
                v.count = math.floor(v.count * (1 + rewardUp))
            end
        end
    end
    self.rewards = {}
    local bag = self.player.bag
    bag:GiveRewardAsFullSmelt(rewards, nil, server.baseConfig.YuanbaoRecordType.Chapter)
	self.player:AddExp(exp)
    self.wave = self.wave + 1
    self.kills = self.kills + killCount
    self:NewChapterWave()

    self.player.task:onEventAdd(server.taskConfig.ConditionType.HookKill)
    self.player.dailyTask:OtherActivityAdd(DailyTaskConfig.DailyActivity.ChapterWar)
end

function Chapter:ReqNextMap()
    local nextmap = self.cache.nextmap
    if nextmap then
        local chapterLevel = self.cache.chapterlevel
        local chapterreward = self.cache.chapterreward
        self.cache.chapterlevel = chapterLevel + 1
        self.cache.nextmap = false
        self:SendChapterInitInfo()
        self.player.task:onEventCheck(server.taskConfig.ConditionType.ChapterGoto)
    end
end

function Chapter:GetChapterReward(chapterid)
    local chapterreward = self.cache.chapterreward
    if chapterreward[chapterid] then
        local ChaptersRewardConfig = server.configCenter.ChaptersRewardConfig[chapterid]
        local rewards = server.dropCenter:DropGroup(ChaptersRewardConfig.reward)
        if rewards then
            chapterreward[chapterid] = false
            self.player:GiveRewardAsFullMailDefault(rewards, "章节BOSS", server.baseConfig.YuanbaoRecordType.Chapter)
            self:SendChapterInitInfo()
            return {ret = true}
        end
    end
    return {ret = false}
end

function Chapter:UpdateCollaborate(assistantid, chapterlevel)
    if assistantid then
        self:AddAppealtime()
        self:SendCollaborate()
        local assistant = server.playerCenter:DoGetPlayerByDBID(assistantid)
        assistant.chapter:AddHelptime(chapterlevel, self.player)
    end
end

function Chapter:AddAppealtime()
     self.cache.appealtime = self.cache.appealtime + 1
end

function Chapter:AddHelptime(chapterlevel, target)
    self.cache.helptime = self.cache.helptime + 1
    self:SendCollaborate()
    local ChaptersConfig = server.configCenter.ChaptersConfig[chapterlevel]
    local mailinfo = server.configCenter.ChaptersCommonConfig.mail
    local mailcontext = string.format(mailinfo.des, target.cache.name, ChaptersConfig.desc)
    local rewards = {ChaptersConfig.helpreward}
    self.player:SendMail(mailinfo.title, mailcontext, rewards, server.baseConfig.YuanbaoRecordType.Chapter)
end

function Chapter:onDayTimer()
    self.cache.appealtime = 0
    self.cache.helptime = 0
    self:SendCollaborate()
end

server.playerCenter:SetEvent(Chapter, "chapter")
return Chapter
