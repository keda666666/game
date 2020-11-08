--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#客户端->服务端
#答题
cs_answer_answer 5801 {
	request {
	no			0 : integer #第几题
	answer		1 : integer #第几个选项
	}
}
]]
function server.cs_answer_answer(socketid, msg)

    local player = server.playerCenter:GetPlayerBySocket(socketid)
    local baseConfig = server.configCenter.AnswerBaseConfig
    local openConfig = server.configCenter.FuncOpenConfig
    local minLv = openConfig[baseConfig.open].conditionnum
    if minLv > player.cache.level then return end
    server.answerCenter:Answer(player.dbid, player.cache.name, msg.no, msg.answer)
    player.answer:AddAnswer()
end

--[[
#获取界面
cs_answer_answer_ui 5802 {
	request {
	}
	response {
		ret			0 : boolean #活动是否开启
	}
}
]]
function server.cs_answer_answer_ui(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.answerCenter:Ui(player.dbid)
end

--[[
#获取排行榜
cs_answer_answer_rank 5803 {
	request {
	}
}
]]
function server.cs_answer_answer_rank(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
     server.answerCenter:Rank(player.dbid)
end
