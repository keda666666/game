--*******************head
local server = require "server"
local lua_app = require "lua_app"
local lua_util = require "lua_util"

--[[
#广播招师
cs_teachers_message 29001 {
	request {
	}
	response {
		ret 				0 : boolean #
	}
}
]]
function server.cs_teachers_message(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teachersCenter:Message(player.dbid, player.cache.name, player.cache.level)
end

--[[
#获取徒弟列表
cs_teachers_get_message 29002 {
	request {
	}
	response {
		data 				0 : *teachers_student_data #
	}
}
]]
function server.cs_teachers_get_message(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.teachersCenter:GetMessage(player.dbid, player.cache.level)
end

--[[
#师傅招收徒弟
cs_teachers_apply_teacher 29003 {
	request {
		sDbid 				0 : integer #学生dbid
	}
	response {
		ret 				0 : integer #1徒弟不存在2师傅已发过邀请了3等级不符4道具不足5成功
	}
}
]]
function server.cs_teachers_apply_teacher(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.teachersCenter:ApplyTeacher(msg.sDbid, player.dbid, player.cache.level)
end

--[[
#徒弟答应
cs_teachers_apply_confirm 29004 {
	request {
		tDbid 				0 : integer #师傅dbid
		res 				1 : boolean
	}
}
]]
function server.cs_teachers_apply_confirm(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teachersCenter:ApplyConfirm(player.dbid, msg.tDbid, msg.res)
end

--[[
#师傅传功
cs_teachers_teach_exp 29005 {
	request {
		no 				0 : integer #师徒编号
	}
}
]]
function server.cs_teachers_teach_exp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teachersCenter:TeachExp(player.dbid, msg.no)
end

--[[
#徒弟领取
cs_teachers_get_exp 29006 {
	request {
		no 				0 : integer #师徒编号
	}
}
]]
function server.cs_teachers_get_exp(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teachersCenter:GetExp(player.dbid, msg.no)
end

--[[
#出师
cs_teachers_graduation 29007 {
	request {
		no 				0 : integer #师徒编号
		typ 			1 : integer #出师类型1,2
	}
}
]]
function server.cs_teachers_graduation(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    server.teachersCenter:Graduation(player.dbid, msg.no, msg.typ)
end

--[[
#领取任务奖励(经验)
cs_teachers_force_get_reward 29009 {
	request {
		no 				0 : integer #师徒编号
		act 			1 : integer #活动编号
	}
	response {
		ret 			0 : boolean #
		rewards 		1 : integer #奖励领取情况,位运算
	}
}
]]
function server.cs_teachers_force_get_reward(socketid, msg)
    local player = server.playerCenter:GetPlayerBySocket(socketid)
    return server.teachersCenter:GetReward(player.dbid, msg.no, msg.act)
end
