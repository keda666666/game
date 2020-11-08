local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local share = require "lua_share"
local ItemConfig = require "resource.ItemConfig"

local Offline = oo.class()

function Offline:ctor(player)
    self.player = player
end

function Offline:onBeforeLogin()
    self:CalcOfflineReward()
end

function Offline:onInitClient()
    self:SendOfflineReward()
end

function Offline:GetMonthCardEx(type)
    local isRewardUp = self.player.welfare:IsRewardUp()
    local isForeverUp = self.player.welfare:IsForeverUp()
    return isRewardUp + isForeverUp
end

function Offline:CalcOfflineReward()
    local offlineTime = lua_app.now() - self.player.cache.lastonlinetime
    if offlineTime < 60 then return end
    offlineTime = math.floor(offlineTime/60)
    local vipCardTime = 0
    if self.player.welfare:IsOffLineRewardUp() then
        vipCardTime = self.player.welfare:IsOffLineRewardUp() * 60
    end
    if offlineTime > (360 + vipCardTime) then offlineTime = (360 + vipCardTime) end
    local msg = {
        offlineTime = offlineTime * 60,
    }
    if self.player.chapter.cache.chapterlevel == 3001 then
	self.player.chapter.cache.chapterlevel = 3000
    end
    local ChaptersConfig = server.configCenter.ChaptersConfig[self.player.chapter.cache.chapterlevel]
    print('---------我去-------:'..self.player.chapter.cache.chapterlevel)
    if not ChaptersConfig then 
        lua_app.log_error("Offline:CalcOfflineReward no ChaptersConfig", self.player.chapter.cache.chapterlevel)
    end
    local dropCount = math.floor((60 * offlineTime) / ChaptersConfig.dropEff)
    local bagSpace = self.player.bag:GetLeftEquipCount()
    local reward = server.dropCenter:DropGroupExpected(ChaptersConfig.offlineDropId, dropCount)

    local equipCount = 0
    local rewardCount = 0
    local selledCount = 0
    local selledGold = 0
    local selledCostList = {}
    for _, v in ipairs(reward) do
        v.count = math.floor(v.count)
        rewardCount = rewardCount + v.count
    end

     if bagSpace >= rewardCount then
        equipCount = rewardCount
        self.player:GiveRewards(reward, 0, server.baseConfig.YuanbaoRecordType.Offline)
    else
        if bagSpace > 0 then
            equipCount = bagSpace
            local left = bagSpace
            for _, v in ipairs(reward) do
                local count = math.min(math.ceil(v.count/rewardCount*bagSpace), left)
                self.player:GiveReward(v.type, v.id, count, 0, server.baseConfig.YuanbaoRecordType.Offline)
                v.count = v.count - count
                left = left - count
            end
            self.player:GiveReward(reward[1].type, reward[1].id, left, 0, server.baseConfig.YuanbaoRecordType.Offline)
        end

        for _, v in ipairs(reward) do
            local ItemCfg = server.configCenter.ItemConfig[v.id]
            if ItemCfg then
                local key = ItemCfg.level * 10000 + ItemCfg.type * 100 + ItemCfg.quality
                local SmeltConfig = server.configCenter.SmeltConfig[key]
                if not SmeltConfig then
                    lua_app.log_error("SmeltConfig not exist itemid =", v.id, ", key =", key)
                else
                    table.insert(selledCostList, SmeltConfig.cost)
                end
                selledCount = selledCount + v.count
            end
        end

        for _, v in ipairs(selledCostList) do
            if v.type == ItemConfig.AwardType.Numeric and v.id == ItemConfig.NumericType.Gold then
                selledGold = selledGold + v.count
            end
        end
    end

    msg.equipNum1 = equipCount
    msg.equipNum2 = selledCount
    local exp = ChaptersConfig.expEff / 60 * offlineTime
    local gold = ChaptersConfig.goldEff / 60 * offlineTime
    local normalEx = {
        type = 1,
        exp = math.floor(exp),
        gold = math.floor(gold),
    }
    local monthcardEx = {
        type = 2,
        exp = math.floor(exp * self:GetMonthCardEx(2)),
        gold = math.floor(gold * self:GetMonthCardEx(1)),
    }
    msg.exp = math.floor(normalEx.exp + monthcardEx.exp)
    msg.money = math.floor(normalEx.gold + monthcardEx.gold) + selledGold
    msg.offlineData = { normalEx, monthcardEx }
    self.onlineMsg = msg
end

function Offline:SendOfflineReward()
    if self.onlineMsg then
        self.player:AddExp(self.onlineMsg.exp)
        self.player:ChangeGold(self.onlineMsg.money)
        server.sendReq(self.player, "sc_raid_chapter_offline_reward", self.onlineMsg)
        self.onlineMsg = nil
    end
end

server.playerCenter:SetEvent(Offline, "offline")
return Offline
