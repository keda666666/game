--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#签到
cs_welfare_signin_req 31001 {
	request {
		rewardType 			0 : integer 	#1=每日普通，2=每日vip，3=每日首充, 4=累计登入
	}
	response {
		ret 				0 : boolean
		rewardType 			1 : integer
	}
}
]]
function server.cs_welfare_signin_req(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return {
    	ret = player.signIn:GetReward(msg.rewardType),
    	rewardType = msg.rewardType,
	}
end

--[[
#系统红包
cs_welfare_bonus_open 31006 {
	request {
		id 			0 : integer #红包id
	}
	response {
		ret 				0 : boolean
		bybNum 				1 : integer 	#绑元数量
	}
}
]]
function server.cs_welfare_bonus_open(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local ret, bybNum = server.bonusMgr:OpenBonus(player.dbid, msg.id)
    return {
    	ret = ret,
    	bybNum = bybNum,
	}
end

--[[
#领取等级礼包
cs_welfare_lv_reward 31051 {
	request {
		no 				0 : integer #第几个等级奖励
	}
	response {
		ret 			0 : boolean #
		lvReward 		1 : integer #位运算
	}
}
]]
function server.cs_welfare_lv_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.welfare:LvReward(msg.no)
end

--[[
#领取福利
cs_welfare_reward 31052 {
	request {
		no 				0 : integer #领第几个福利1,2,3
	}
	response {
		ret 			0 : boolean #
		welfareReward 	1 : integer #位运算
	}
}
]]
function server.cs_welfare_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return player.welfare:WelfareReward(msg.no)
end

--[[
#使用兑换码
cs_welfare_redeemcode 31053 {
	request {
		redeemcode	0 : string
	}
	response {
		ret 		0 : integer
	}
}
]]
function server.cs_welfare_redeemcode(socketid, msg)
	local player = server.playerCenter:GetPlayerBySocket(socketid)
	if player.cache.redeemcode[msg.redeemcode] then
		return { ret = 4 }
	end
	local singlegift
	for _, v in pairs(server.configCenter.GiftCodeConfig) do
		if v.code == msg.redeemcode then
			singlegift = v
		end
	end
	if singlegift then
		player.cache.redeemcode[msg.redeemcode] = true
		server.mailCenter:SendMail(player.dbid, singlegift.mailTitle, singlegift.mailContent, singlegift.gift, server.baseConfig.YuanbaoRecordType.Redeemcode)
		return { ret = 0 }
	end


	local ret, giftid = server.serverCenter:CallTagMod(msg.redeemcode, "httpr", "recordDatas", "UseRedeemcode", msg.redeemcode,
		player.cache.serverid, player.dbid, player.cache.account, player.cache.name, player.ip)
	if ret ~= 0 then return { ret = ret or -1 } end
	local gift = server.configCenter.GiftCodeConfig[giftid]
	if not gift then return { ret = 2 } end
	server.mailCenter:SendMail(player.dbid, gift.mailTitle, gift.mailContent, gift.gift, server.baseConfig.YuanbaoRecordType.Redeemcode)
	return { ret = 0 }
end

--[[
#登入领取奖励
cs_welfare_get_loginreward 31011 {
	request {
		indexDay 			0 : integer #领取奖励索引
	}
}
]]
function server.cs_welfare_get_loginreward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    player.loginGift:GetReward(msg.indexDay)
end
