--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"
local ItemConfig = require "resource.ItemConfig"
local TEMPLATE = require "player.template.Template"
--[[
#升阶
cs_template_up_level 5001 {
request {
		templateType	0 : integer
		autoBuy			1 : integer  #0不自动购买道具1使用绑元宝2使用绑元宝和元宝
	}
}
]]
function server.cs_template_up_level(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:AddExp(msg.autoBuy)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
        if templateType.type2 == "ride" then
            player.task:onEventAdd(server.taskConfig.ConditionType.RideUpgrade)
        elseif templateType.type2 == "fairy" then
            player.task:onEventAdd(server.taskConfig.ConditionType.FairyUpgrade)
        end
    else
        lua_app.log_info("cs_template_up_level:",errNo, "type:", msg.templateType, "msg.autoBuy:", msg.autoBuy)
    end
end

--[[
#升级技能
cs_template_up_skill 5002 {
	request {
		templateType	0 : integer
		skillNo			1 : integer
	}
}
]]
function server.cs_template_up_skill(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:SkillUpLv(msg.skillNo)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_up_skill:", errNo, "type:", msg.templateType, "msg.skillNo:", msg.autoBuy)
    end
end

--[[
#穿戴装备
cs_template_equip 5003 {
	request {
		templateType	0 : integer
		itemNo			1 : integer
	}
}
]]
function server.cs_template_equip(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:ChangeEquip(msg.itemNo)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_equip:", errNo, "type:", msg.templateType, "msg.itemNo:", msg.itemNo)
    end
end

--[[
#幻化
cs_template_clothes 5004 {
	request {
		templateType	0 : integer
		clothesNo 		1 : integer			#装扮编号
	}
}
]]
function server.cs_template_clothes(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:changeClothes(msg.clothesNo)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_clothes:", errNo, "type:", msg.templateType, "msg.clothesNo:", msg.clothesNo)
    end
end

--[[
#使用属性丹
cs_template_drug 5006 {
	request {
		templateType	0 : integer
		drugNum 		1 : integer			#属性丹数量
	}
}
]]
function server.cs_template_drug(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:UseDrug(msg.drugNum)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_drug:", errNo, "type:", msg.templateType, "msg.drugNum:", msg.drugNum)
    end
end

--[[
#购买服装
cs_template_buy_clothes 5005 {
	request {
		templateType	0 : integer
		clothesNo 		1 : integer			#装扮编号
	}
}
]]
function server.cs_template_buy_clothes(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:BuyClothes(msg.clothesNo)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_buy_clothes:", errNo, "type:", msg.templateType, "msg.clothesNo:", msg.clothesNo)
    end
end

--[[
#领取进阶奖励
cs_template_reward 5007 {
	request {
		templateType	0 : integer
		no 				1 : integer			#哪阶的奖励
	}
}
]]
function server.cs_template_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local templateType = TEMPLATE:GetType(msg.templateType)
    if not templateType then return end
    local upMsg, errNo = player[templateType.type1][templateType.type2]:GetReward(msg.no)
    if upMsg then
        upMsg.templateType = msg.templateType
        server.sendReq(player, "sc_template_update_data", upMsg)
    else
        lua_app.log_info("cs_template_reward:", errNo, "type:", msg.templateType, "msg.no:", msg.no)
    end
end

--[[
#直升丹升阶
cs_template_up_stage 5008 {
	request {
		drugId 			0 : integer 	#丹药id
	}
}
]]
function server.cs_template_up_stage(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local AdvanceItemConfig = server.configCenter.AdvanceItemConfig[msg.drugId]
    if not AdvanceItemConfig then
        lua_app.log_info(">> AdvanceItemConfig Use drug up stage not config. drugId", msg.drugId)
        return
    end
    if not player:PayReward(ItemConfig.AwardType.Item, msg.drugId, 1, server.baseConfig.YuanbaoRecordType.Activity, "直升丹升阶") then
        lua_app.log_info(">>AdvanceItemConfig pay failed. drug not exist")
        return 
    end
    local templateType = TEMPLATE:GetType(AdvanceItemConfig.type)
    player[templateType.type1][templateType.type2]:AddSExp(AdvanceItemConfig.value, AdvanceItemConfig.maxlv)
end
