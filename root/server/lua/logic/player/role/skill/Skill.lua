local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"

local Skill = oo.class()

function Skill:ctor(role)
    self.role = role
    self.player = role.player
    self.skillLevel = {0, 0, 0, 0, 0, 0, 0, 0}
    self.skillSort = table.copy(server.configCenter.RoleBaseConfig.skilldefault)
end

function Skill:onCreate()
    self.skillLevel = self.role.cache.skill.skillLevel
    self.skillSort = table.copy(server.configCenter.RoleBaseConfig.skilldefault)
    self.role.cache.skill.skillSort = self.skillSort
    self:SetSkillLevel(1, 1)
end

function Skill:onLoad()
    self.skillLevel = self.role.cache.skill.skillLevel
    self.skillSort = self.role.cache.skill.skillSort
    local job = self.player.cache.job

    for num, level in ipairs(self.skillLevel) do
        if level > 0 then
            local config = server.configCenter.SkillsOpenConfig[num]
            if config then
                local skillid = config.id[job]
                local changeb = server.configCenter.SkillsUpgradeConfig[level].changeb[num]
                self.role:AddSkill(skillid, {changeb = changeb})
            end
        end
    end

    self:UpdateSort()
end

function Skill:GetMsgData()
    return self.skillLevel
end

function Skill:GetSortMsgData()
    return self.skillSort
end

function Skill:GetMaxLevel()
    local maxlevel = math.min(self.player.cache.level, #server.configCenter.SkillsUpgradeConfig)
    return maxlevel
end

function Skill:SetSkillLevel(num, level)
    local SkillsOpenConfig = server.configCenter.SkillsOpenConfig[num]
    local SkillsConfig = server.configCenter.SkillsConfig
    local job = self.player.cache.job
    if self.skillLevel[num] > 0 then
        local skillid = SkillsOpenConfig.id[job]
    	self.role:DelSkill(skillid)
    end
    self.skillLevel[num] = level
    local skillid = SkillsOpenConfig.id[job]
    local changeb = server.configCenter.SkillsUpgradeConfig[level].changeb[num]
    self.role:AddSkill(skillid, {changeb = changeb})
end

function Skill:Upgrade(skillID)
    local level = self.skillLevel[skillID + 1]
    --print("test Upgrade:",skillID,level)
    if level >= self:GetMaxLevel() or level == 0 then
        -- lua_app.log_info("Skill:Upgrade: actor(", self.actor.accountname, ") error up level:", level)
        return
    end
    local SkillsUpgradeConfig = server.configCenter.SkillsUpgradeConfig[level]
    if self.player:PayGold(SkillsUpgradeConfig.cost) then
        self:SetSkillLevel(skillID + 1, level + 1)
        server.sendReq(self.player,"sc_skill_upgrade_result", {
                skillID = skillID,
                level   = level + 1,
            })
        self.player:ToReCalcPower()
       -- server.raidMgr:RoleUpdateSkills(self.role,self.skilllevel,self:GetTupoIDs())
    end
    self:Show()
    self:UpdateSort()
    self.player:ToReCalcPower()
    self.player.task:onEventCheck(server.taskConfig.ConditionType.SkillUpgrade)
end

function Skill:UpgradeAll()
    local gold = self.player.cache.gold
    local maxlevel = self:GetMaxLevel()
    local minlevel = maxlevel
    for _, v in pairs(self.skillLevel) do
        if v < minlevel and v ~= 0 then minlevel = v end
    end
    local SkillsUpgradeConfig = server.configCenter.SkillsUpgradeConfig
    local pay = 0
    local function _PayResult()
        self.player:PayGold(pay)
        server.sendReq(self.player,"sc_skill_all_upgrade_result", {
                level   = self:GetMsgData(),
            })
        self.player:ToReCalcPower()
       -- self:Show()
       self:UpdateSort()
       self.player:ToReCalcPower()
       self.player.task:onEventCheck(server.taskConfig.ConditionType.SkillUpgrade)
    end
    for lvl = minlevel, maxlevel - 1 do
        for i = 1, #self.skillLevel do
            if self.skillLevel[i] == lvl and self.skillLevel[i] ~= 0 then
                if pay + SkillsUpgradeConfig[lvl].cost > gold then
                    _PayResult()
                    return
                end
                pay = pay + SkillsUpgradeConfig[lvl].cost
                self:SetSkillLevel(i, lvl + 1)
            end
        end
    end
    _PayResult()
   -- server.raidMgr:RoleUpdateSkills(self.role,self.skilllevel,self:GetTupoIDs())
end

function Skill:onLevelUp(oldlevel, level)
    local ischange = false
    local SkillsOpenConfig = server.configCenter.SkillsOpenConfig
    for _, v in pairs(SkillsOpenConfig) do
        if self.skillLevel[v.index] == 0 and v.level <= level then
            self:SetSkillLevel(v.index, 1)
            ischange = true

        end
    end
    if ischange then
        server.sendReq(self.player,"sc_skill_all_upgrade_result", {
                level   = self:GetMsgData(),
            })
    end
    self:UpdateSort()
   -- self:Show()
end

function Skill:Show()
    print("skill level info")
    table.print(self.skillLevel)
end

function Skill:GetSkillPower()
    local power = 0
    local SkillPowerConfig = server.configCenter.SkillPowerConfig
    for k,v in pairs(self.skillLevel) do
        if SkillPowerConfig[k] then
            power = power + v * SkillPowerConfig[k].powerPerLevel
        end
    end
    return power
end

function Skill:UpdateSort(skills)
    if not skills then skills = self.skillSort end
    if #skills ~= 8 then return end

    local job = self.player.cache.job
    for i,v in ipairs(skills) do
        self.skillSort[i] = v
    end
    
    local skillidsort = {}

    for _, num in ipairs(self.skillSort) do
        local level = self.skillLevel[num]
        if level > 0 then
            local config = server.configCenter.SkillsOpenConfig[num]
            if config then
                table.insert(skillidsort, config.id[job])
            end
        end
    end

    self.role:SetRunSkillSort(skillidsort)


end

server.playerCenter:SetEvent(Skill, "role.skill")

return Skill