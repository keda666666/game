local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ItemConfig = require "common.resource.ItemConfig"
local TaskConfig = require "resource.TaskConfig"
local _ConditionType = TaskConfig.ConditionType

local TaskEvent = {}

local _CheckCondition = {}

_CheckCondition[_ConditionType.EquipWearCount] = function(player, config, taskdata)
	local count = 0
	local equiplist = player.role.equip.equipList
	for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
		local equip = equiplist[i]
		local itemId = equip:GetItemId()
		if itemId ~= 0 then
			count = count + 1
		end
	end
	taskdata.value = count
	if count >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.EquipWearAssign] = function(player, config, taskdata)
	local equiplist = player.role.equip.equipList
	for i = 0, ItemConfig.EquipSlotType.MAX - 1 do
		local equip = equiplist[i]
		local itemId = equip:GetItemId()
		if itemId == config.condition.value then
			return true
		end
	end
	return false
end

_CheckCondition[_ConditionType.EquipEnhanceAll] = function(player, config, taskdata)
	local alllevel = player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Enhance)
	taskdata.value = alllevel
	if alllevel >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.EquipRefineAll] = function(player, config, taskdata)
	local alllevel = player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Refine)
	taskdata.value = alllevel
	if alllevel >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.EquipAnnealAll] = function(player, config, taskdata)
	local alllevel = player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Anneal)
	taskdata.value = alllevel
	if alllevel >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.EquipGemAll] = function(player, config, taskdata)
	local alllevel = player.role.equip:GetForgeLevels(ItemConfig.ForgeType.Gem)
	taskdata.value = alllevel
	if alllevel >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.SkillUpgrade] = function(player, config, taskdata)
	local alllevel = 0
	local levellist = player.role.skill.skillLevel
	for _, level in ipairs(levellist) do
		alllevel = alllevel + level
	end
	taskdata.value = alllevel
	if alllevel >= config.condition.value then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.ChapterClear] = function(player, config, taskdata)
	return (player.cache.chapter.chapterlevel > config.condition.value) or 
			(player.cache.chapter.chapterlevel == config.condition.value and player.cache.chapter.nextmap)
end

_CheckCondition[_ConditionType.ChapterGoto] = function(player, config, taskdata)
	return player.cache.chapter.chapterlevel >= config.condition.value
end

_CheckCondition[_ConditionType.PetActive] = function(player, config, taskdata)
	if player.pet.cache.list[config.condition.value] then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.XianlvActive] = function(player, config, taskdata)
	if player.xianlv.cache.list[config.condition.value] then
		return true
	else
		return false
	end
end

_CheckCondition[_ConditionType.RoleLevelup] = function(player, config, taskdata)
	taskdata.value = player.cache.level
	return player.cache.level >= config.condition.value
end

_CheckCondition[_ConditionType.AutoPK] = function(player, config, taskdata)
	return player.chapter.cache.autopk
end

_CheckCondition[_ConditionType.WildgeeseFbLayer] = function(player, config, taskdata)
	return player.cache.wildgeeseFb.layer >= config.condition.value
end



function TaskEvent:CheckCondition(conditiontype, player, config, taskdata)
	if _CheckCondition[conditiontype] then
		return _CheckCondition[conditiontype](player, config, taskdata)
	else
		return taskdata.value >= config.condition.value
	end
end

return TaskEvent