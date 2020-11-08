local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local TaskConfig = require "resource.TaskConfig"
local TaskEvent = require "player.task.TaskEvent"

local Task = oo.class()
local _FirstTaskId = 1001

function Task:ctor(player)
    self.player = player
end

function Task:onCreate()
    self:onLoad()
    self:ReceiveTask(_FirstTaskId)
end

function Task:onInitClient()
    self:onEventAdd(server.taskConfig.ConditionType.DayLogin)
    self:SendTaskInfo(TaskConfig.TaskType.Main)
end

function Task:onLoad()
    self.cache = self.player.cache.task
end

-- 接受任务
function Task:ReceiveTask(taskid)
    local taskconfig = server.configCenter.TaskConfig[taskid]
    if taskconfig then
        self.cache.tasks[taskconfig.type] = self.cache.tasks[taskconfig.type] or {}
        local tasks = self.cache.tasks[taskconfig.type]
        if not tasks[taskid] then
            local value = self.cache.record[taskconfig.condition.type] or 0
            tasks[taskid] = {
                status = TaskConfig.TaskStatus.Received,
                data = {value = value},
            }
            if taskconfig.aheadtime == 1 then
                self:onEventCheck(taskconfig.condition.type)
            end
        end
        self:SendTaskInfo(TaskConfig.TaskType.Main)
    end
end

-- 完成任务
function Task:TaskComplete(taskid)
    local taskconfig = server.configCenter.TaskConfig[taskid]
    if taskconfig then
        self.cache.tasks[taskconfig.type] = self.cache.tasks[taskconfig.type] or {}
        local tasks = self.cache.tasks[taskconfig.type]
        if tasks[taskid] then
            tasks[taskid].status = TaskConfig.TaskStatus.Completed
            self.player:CheckOpenFunc({type = server.funcOpen.CondType.Task, value = taskid})
            self.player:OnTaskComplete(taskid)
        end
    end
end

-- 发送任务数据
function Task:SendTaskInfo(type)
    self.cache.tasks[type] = self.cache.tasks[type] or {}
    local tasks = {}
    for id, task in pairs(self.cache.tasks[type]) do
        local taskmsg = {
            id = id,
            status = task.status,
            progress = table.wcopy(task.data),
        }
        table.insert(tasks, taskmsg)
    end
    local taskinfo = {
        type = type,
        tasks = tasks,
    }
    if #tasks > 0 then
        server.sendReqByDBID(self.player.dbid, "sc_task_info", taskinfo)
    end
end

function Task:SendTaskUpdate(taskid)
    local taskconfig = server.configCenter.TaskConfig[taskid]
    if taskconfig then
        self.cache.tasks[taskconfig.type] = self.cache.tasks[taskconfig.type] or {}
        local tasks = self.cache.tasks[taskconfig.type]
        if tasks[taskid] then
            local task = {
                id = taskid,
                status = tasks[taskid].status,
                progress = table.wcopy(tasks[taskid].data),
            }
            local taskupdate = {
                type = taskconfig.type,
                data = task
            }
            server.sendReqByDBID(self.player.dbid, "sc_task_update", taskupdate)
        end
    end
end

-- 领取奖励
function Task:GetReward(taskid)
    local taskconfig = server.configCenter.TaskConfig[taskid]
    if taskconfig then
        self.cache.tasks[taskconfig.type] = self.cache.tasks[taskconfig.type] or {}
        local tasks = self.cache.tasks[taskconfig.type]
        if tasks[taskid] then
            if tasks[taskid].status == TaskConfig.TaskStatus.Completed then
                local rewards = server.dropCenter:DropGroup(taskconfig.reward)
                if rewards then
                    self.player:GiveRewardAsFullMailDefault(rewards, "任务奖励", server.baseConfig.YuanbaoRecordType.Task)
                    tasks[taskid] = nil
                    self:ReceiveTask(taskconfig.nextid)
                end
            end
        end
    end
end

-- 触发任务条件检查
function Task:onEventCheck(conditiontype)
    for type, tasks in pairs(self.cache.tasks) do
        for taskid, task in pairs(tasks) do
            local status = task.status
            local data = task.data
            local taskconfig = server.configCenter.TaskConfig[taskid]
            if taskconfig then
                local condition = taskconfig.condition
                if status == TaskConfig.TaskStatus.Received and conditiontype == condition.type then
                    local complete = TaskEvent:CheckCondition(conditiontype, self.player, taskconfig, data)
                    if complete then
                        self:TaskComplete(taskid)
                    end
                    self:SendTaskUpdate(taskid)
                end
            end
        end
    end
end

-- 任务累积
function Task:onEventAdd(conditiontype)
    if not self:IsSmelt(conditiontype) then
        self:AddRecord(conditiontype)
    end
    for type, tasks in pairs(self.cache.tasks) do
        for taskid, task in pairs(tasks) do
            local status = task.status
            local data = task.data
            local taskconfig = server.configCenter.TaskConfig[taskid]
            if taskconfig then
                local condition = taskconfig.condition
                if status == TaskConfig.TaskStatus.Received and conditiontype == condition.type then
                    if self:IsSmelt(conditiontype) then
                        self:AddRecord(conditiontype)
                    end
                    data.value = self.cache.record[conditiontype] or 0
                    local complete = TaskEvent:CheckCondition(conditiontype, self.player, taskconfig, data)
                    if complete then
                        self:TaskComplete(taskid)
                        if self:IsSmelt(conditiontype) then
                            self.cache.record[conditiontype] = 0
                        end
                    end
                    self:SendTaskUpdate(taskid)
                end
            end
        end
    end
end

function Task:IsSmelt(conditiontype)
    return (server.taskConfig.ConditionType.EquipSmelt == conditiontype)
end

function Task:AddRecord(conditiontype)
    self.cache.record[conditiontype] = self.cache.record[conditiontype] or 0
    self.cache.record[conditiontype] = self.cache.record[conditiontype] + 1
end

function Task:onLevelUp(oldlevel, newlevel)
    self:onEventCheck(server.taskConfig.ConditionType.RoleLevelup)
end

-- 立马完成
function Task:TestComplete()
	local mytasks = table.wcopy(self.cache.tasks)
    for type, tasks in pairs(mytasks) do
        for taskid, task in pairs(tasks) do
            local status = task.status
            local data = task.data
            local taskconfig = server.configCenter.TaskConfig[taskid]
            if taskconfig then
                self:TaskComplete(taskid)
                self:GetReward(taskid)
            end
        end
    end
end

server.playerCenter:SetEvent(Task, "task")
return Task