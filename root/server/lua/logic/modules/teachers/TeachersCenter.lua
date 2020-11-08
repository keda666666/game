local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "teachers"
local TeachersCenter = {}

function TeachersCenter:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
	self.YuanbaoRecordType = server.baseConfig.YuanbaoRecordType.Teachers
end

function TeachersCenter:Release()
	if self.cache then
		self.cache(true)
		-- self.cache = nil
	end
end

function TeachersCenter:onDayTimer()
	local day = server.serverRunDay
	local clearList = {}
	for k,v in pairs(self.cache.msessage) do
		--消息只保留3天
		if (v.day + 3) <= day then
			table.insert(clearList, k)
		end
	end
	for _,v in ipairs(clearList) do
		self.cache.msessage[v] = nil
	end
	local baseConfig = server.configCenter.MasterBaseConfig
	local title = baseConfig.mailtitletask0
	local msg = baseConfig.maildestask0
	local taskConfig = server.configCenter.MasterTaskConfig

	local timeoutList = {}
	for k,v in pairs(self.cache.data) do
		if baseConfig.autograduate <= ((day - v.day) + 1) then
			table.insert(timeoutList, {dbid = v.student, no = k})
		else
			v.exp = 0
			for no,num in pairs(v.data) do
				if taskConfig[no].condition <= num then
					-- local rewards = taskConfig[no].pupilreward
					local rewards = self:GetExpReward(v.sLv, "pupilreward")
					server.mailCenter:SendMail(v.student, title, msg, rewards, self.YuanbaoRecordType, "师门每日")

				end
			end
			v.data = {}
			v.rewards = 0
			
			if server.playerCenter:IsOnline(v.teacher) then
				local tPlayer = server.playerCenter:GetPlayerByDBID(v.teacher)
				self:updateMsg(v.teacher, "studentData", k, "exp", "data", "rewards")
			end
			
			if server.playerCenter:IsOnline(v.student) then
				local sPlayer = server.playerCenter:GetPlayerByDBID(v.student)
				self:AddNum(v.student, 1)
				self:updateMsg(v.student, "teacherData", k, "exp", "data", "rewards")
			end
		end
	end
	for _,v in pairs(timeoutList) do
		self:Graduation(v.dbid, v.no, 1)
	end
end

--广播找师傅
function TeachersCenter:Message(dbid, name, lv)
	--如果在data那有则不能再发消息了
	local data = self.cache.dataKey[dbid]
	if data and data.teacher then return {ret = false} end
	local msgData = self.cache.msessage[dbid]
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if msgData and (lua_app.now() - msgData.msgTime) < 180 then
		server.sendErr(player, "必须间隔3分钟才能发送寻求名师的广播")
		return {ret = false}
	end
	if msgData then
		msgData.msgTime = lua_app.now()
	else
		local msgData = {
			day = server.serverRunDay,
			msgTime = lua_app.now(),
			name = name,
			lv = lv,
			teacherList = {}
		}
		self.cache.msessage[dbid] = msgData
	end
	server.chatCenter:ChatLink(25, player, nil, player.cache.name)
	return {ret = true}
end

function TeachersCenter:GetMessage(dbid)
	local msgData = self.cache.msessage
	local msg = {data={}}
	for k,v in pairs(msgData) do
		if k ~= dbid then
			table.insert(msg.data, {
					dbid = k,
					name = v.name,
					lv = v.lv,
					tag = (v.teacherList[dbid] ~= nil),
				})
		end
	end
	return msg
end

--师傅回应
function TeachersCenter:ApplyTeacher(sDbid, tDbid, lv)
	local msgData = self.cache.msessage[sDbid]
	local baseConfig = server.configCenter.MasterBaseConfig
	if not msgData then return {ret = 1} end
	if msgData.teacherList[tDbid] then return {ret = 2} end
	if (msgData.lv + baseConfig.lvlimit) >= lv then
		local player = server.playerCenter:GetPlayerByDBID(tDbid)
		server.sendErr(player, "师傅必须比徒弟等级≥3级方可收徒")
		return {ret = 3}
	end
	local tPlayer = server.playerCenter:GetPlayerByDBID(tDbid)
	local cost = baseConfig.cost[1]
	if not tPlayer:CheckReward(cost.type, cost.id, cost.count) then return {ret = 4} end
	local data = {
		name = tPlayer.cache.name,
		lv = tPlayer.cache.level,
		dbid = tDbid,
	}
	msgData.teacherList[tDbid] = data
	
	
	if server.playerCenter:IsOnline(sDbid) then
		local sPlayer = server.playerCenter:GetPlayerByDBID(sDbid)
		server.sendReq(sPlayer, "sc_teachers_message_add", data)
	end
	return {ret = 5}
end

--收徒处理
function TeachersCenter:ApplyConfirm(sDbid, tDbid, res)
	local msgData = self.cache.msessage[sDbid]
	if not msgData then return end

	if not msgData.teacherList[tDbid] then end
	local sPlayer = server.playerCenter:GetPlayerByDBID(sDbid)
	if not res then
		msgData.teacherList[tDbid] = nil
		if server.playerCenter:IsOnline(tDbid) then
			local tPlayer = server.playerCenter:GetPlayerByDBID(tDbid)
			server.sendErr(tPlayer, string.format("%s拒绝了您的拜师邀请", sPlayer.cache.name))
		end
		return
	end

	local sDataKey = self.cache.dataKey[sDbid] or {studentKey={}}
	local baseConfig = server.configCenter.MasterBaseConfig
	if sDataKey.teacherKey then return end

	local tDataKey = self.cache.dataKey[tDbid] or {studentKey={}}
	
	if tDataKey.studentNum and tDataKey.studentNum >= baseConfig.pupilnum then
		msgData.teacherList[tDbid] = nil
		server.sendErr(sPlayer, "很遗憾，该名师已经找到得意弟子了")
		return
	end

	if not server.playerCenter:IsOnline(tDbid) then
		msgData.teacherList[tDbid] = nil
		server.sendErr(sPlayer, "师傅必须在线方可拜师")
		return
	end
	local tPlayer = server.playerCenter:GetPlayerByDBID(tDbid)
	local baseConfig = server.configCenter.MasterBaseConfig
	if not tPlayer:PayRewards(baseConfig.cost, self.YuanbaoRecordType) then
		msgData.teacherList[tDbid] = nil
		server.sendErr(sPlayer, "很遗憾，该名师已经找到得意弟子了")
		return
	end

	local teachersData = {
		teacher = tDbid,
		tName = tPlayer.cache.name,
		tLv = tPlayer.cache.level,
		tShows = tPlayer.role:GetEntityShows(),
		student = sDbid,
		sName = sPlayer.cache.name,
		sLv = sPlayer.cache.level,
		sShows = sPlayer.role:GetEntityShows(),
		day = server.serverRunDay,
		exp = 0,
		data = {},
		rewards = 0,
	}
	self.cache.msessage[sDbid] = nil
	self.cache.data[self.cache.no] = teachersData
	sDataKey.teacherKey = self.cache.no
	tDataKey.studentKey[self.cache.no] = 1
	tDataKey.studentNum = (tDataKey.studentNum or 0) + 1

	self.cache.no = self.cache.no + 1
	self.cache.dataKey[sDbid] = sDataKey
	self.cache.dataKey[tDbid] = tDataKey

	self:SendMsg(sDbid)
	self:SendMsg(tDbid)

	server.sendErr(sPlayer, "恭喜您拜师成功")
	server.sendErr(tPlayer, string.format("恭喜收到一名高徒：%s", sPlayer.cache.name))
end

--师傅传功
function TeachersCenter:TeachExp(tDbid, no)
	local data = self.cache.data[no]
	if not data then return end
	if data.teacher ~= tDbid then return end
	if data.exp ~= 0 then return end
	local baseConfig = server.configCenter.MasterBaseConfig
	local day = server.serverRunDay
	if ((day - data.day) + 1) >= baseConfig.graduate then return end
	data.exp = 1
	
	local expConfig = server.configCenter.ImpartExpConfig
	local tPlayer = server.playerCenter:GetPlayerByDBID(tDbid)
	for _,v in pairs(expConfig[2]) do
		if v.level[1] <= tPlayer.cache.level and (not v.level[2] or v.level[2] > tPlayer.cache.level) then
			tPlayer:GiveRewardAsFullMailDefault(v.exp, "传功", self.YuanbaoRecordType, "师傅传功"..no)
			break
		end
	end
	tPlayer.enhance:AddPoint(18, 1)
	if server.playerCenter:IsOnline(data.student) then
		self:updateMsg(data.student, "teacherData", no, "exp")
	end
	self:updateMsg(data.teacher, "studentData", no, "exp")
end

--学生领取经验
function TeachersCenter:GetExp(sDbid, no)
	local data = self.cache.data[no]
	if not data then return end
	if data.student ~= sDbid then return end
	if data.exp ~= 1 then return end
	data.exp = 2

	local expConfig = server.configCenter.ImpartExpConfig
	local sPlayer = server.playerCenter:GetPlayerByDBID(sDbid)
	for _,v in pairs(expConfig[1]) do
		if v.level[1] <= sPlayer.cache.level and (not v.level[2] or v.level[2] > sPlayer.cache.level) then
			sPlayer:GiveRewardAsFullMailDefault(v.exp, "传功", self.YuanbaoRecordType, "徒弟传功"..no)
			break
		end
	end
	sPlayer.enhance:AddPoint(18, 1)
	self:updateMsg(data.student, "teacherData", no, "exp")
end

--学生出师
function TeachersCenter:Graduation(sDbid, no, typ)
	print("TeachersCenter:Graduation", no, typ)
	local data = self.cache.data[no]
	if not data then
		print("TeachersCenter:Graduation----- no data", no)
		return 
	end
	if data.student ~= sDbid then 
		print("TeachersCenter:Graduation----- data.student ~= sDbid", data.student, sDbid)
		return 
	end
	local baseConfig = server.configCenter.MasterBaseConfig
	local day = server.serverRunDay
	if ((day - data.day) + 1) < baseConfig.graduate then 
		print("TeachersCenter:Graduation----- day", day, data.day, baseConfig.graduate)
		return 
	end
	local graduateConfig = server.configCenter.GraduateConfig
	if not graduateConfig[typ] then 
		print("TeachersCenter:Graduation----- graduateConfig", typ)
		return 
	end
	local cost = graduateConfig[typ].cost
	local sPlayer = server.playerCenter:GetPlayerByDBID(data.student)
	if cost then
		if not sPlayer:PayRewards(cost, self.YuanbaoRecordType, "graduation") then 
			print("TeachersCenter:Graduation----- cost")
			return
		end
	end
	local title = baseConfig.mailtitlepupil
	local msg = baseConfig.maildespupil
	local rewards = graduateConfig[typ].pupilreward
	server.mailCenter:SendMail(data.student, title, msg, rewards, self.YuanbaoRecordType, "徒弟师门出师")

	title = baseConfig.mailtitlemaster
	msg = string.format(baseConfig.maildesmaster, data.sName)
	rewards = graduateConfig[typ].masterreward
	server.mailCenter:SendMail(data.teacher, title, msg, rewards, self.YuanbaoRecordType, "师门师门出师")

	local msg = {no = no}
	local keyData = self.cache.dataKey[data.student]
	keyData.teacherKey = nil
	if server.playerCenter:IsOnline(data.student) then
		server.sendReq(sPlayer, "sc_teachers_graduation", msg)
	end

	local keyData = self.cache.dataKey[data.teacher]
	keyData.studentKey[no] = nil
	keyData.studentNum = keyData.studentNum - 1
	if server.playerCenter:IsOnline(data.teacher) then
		local tPlayer = server.playerCenter:GetPlayerByDBID(data.teacher)
		server.sendReq(tPlayer, "sc_teachers_graduation", msg)
	end
	self.cache.data[no] = nil
end

--强制出师
-- function TeachersCenter:ForceGraduation(tDbid, no)
-- 	local data = self.cache.data[no]
-- 	if not data then return end
-- 	if data.teacher ~= tDbid then return end
-- 	local baseConfig = server.configCenter.MasterBaseConfig
-- 	local day = server.serverRunDay
-- 	if ((day - data.day) + 1) <= baseConfig.autograduate then return end
-- 	self:Graduation(data.student, no, 1)
-- end

--增加次数
function TeachersCenter:AddNum(sDbid, act, num)
	local data = self.cache.dataKey[sDbid]
	if data and data.teacherKey then
		self:_AddNum(sDbid, data.teacherKey, act, num)
	end
end

function TeachersCenter:_AddNum(sDbid, no, act, num)
	num = num or 1
	local data = self.cache.data[no]
	if not data then return end
	if data.student ~= sDbid then return end

	local baseConfig = server.configCenter.MasterBaseConfig
	local day = server.serverRunDay
	if ((day - data.day) + 1) > baseConfig.graduate then return end
	local taskConfig = server.configCenter.MasterTaskConfig
	local actNum = data.data[act] or 0
	if actNum >= taskConfig[act].condition then return end
	if (data.data[act] or 0) >= taskConfig[act].condition then return end
	data.data[act] = (data.data[act] or 0) + num
	if data.data[act] >= taskConfig[act].condition then
		data.data[act] = taskConfig[act].condition

		local title = baseConfig.mailtitletask1
		local msg = string.format(baseConfig.maildestask1, data.sName)
		-- local rewards = taskConfig[act].masterreward
		local rewards = self:GetExpReward(data.tLv, "masterreward")
		server.mailCenter:SendMail(data.teacher, title, msg, rewards, self.YuanbaoRecordType, "师门每日")
	end

	self:updateMsg(data.student, "teacherData", no, "data")
	if server.playerCenter:IsOnline(data.teacher) then
		self:updateMsg(data.teacher, "studentData", no, "data")
	end
end

--徒弟领取任务奖励
function TeachersCenter:GetReward(sDbid, no, act)
	local data = self.cache.data[no]
	if not data then
		print("TeachersCenter:GetReward---- not data", sDbid, no, act)
		return {ret = false}
	end
	if data.student ~= sDbid then
		print("TeachersCenter:GetReward---- data.student ~= sDbid", data.student, sDbid, no, act)
		return {ret = false}
	end

	local taskConfig = server.configCenter.MasterTaskConfig
	if data.rewards & (2 ^ act) ~= 0  then
		print("TeachersCenter:GetReward---- data.rewards & (2 ^ act) ~= 0", sDbid, no, act)
		return {ret = false}
	end
	if (data.data[act] or 0) < taskConfig[act].condition then
		print("TeachersCenter:GetReward---- (data.data[act] or 0) < taskConfig[act].condition", sDbid, no, act)
		return {ret = false}
	end
	data.rewards = data.rewards | (2 ^ act)

	-- local rewards = taskConfig[act].pupilreward
	local rewards = self:GetExpReward(data.sLv, "pupilreward")
	local sPlayer = server.playerCenter:GetPlayerByDBID(data.student)
	sPlayer:GiveRewardAsFullMailDefault(rewards, "师徒奖励", self.YuanbaoRecordType, "师徒奖励"..act)

	return {ret = true, rewards = data.rewards}
end

function TeachersCenter:SendMsg(dbid)
	local msg = self:packInfo(dbid)
	server.sendReqByDBID(dbid, "sc_teachers_info", msg)
	self:AddNum(dbid, 1)
end

function TeachersCenter:UpdateData(dbid, level)
	local msgData = self.cache.msessage[dbid]
	if msgData then
		msgData.lv = level
	end

	local dataKey = self.cache.dataKey[dbid]
	
	if dataKey and dataKey.teacherKey then
		local data = self.cache.data[dataKey.teacherKey]
		data.sLv = level

		if server.playerCenter:IsOnline(data.teacher) then
			local tPlayer = server.playerCenter:GetPlayerByDBID(data.teacher)
			local msg = {studentData = {no = dataKey.teacherKey, sLv = level}}
			server.sendReq(tPlayer, "sc_teachers_update", msg)
		end
	end

	if dataKey and dataKey.studentKey then
		for k,v in pairs(dataKey.studentKey) do
			local data = self.cache.data[k]
			data.tLv = level
			if server.playerCenter:IsOnline(data.student) then
				local sPlayer = server.playerCenter:GetPlayerByDBID(data.student)
				local msg = {teacherData = {no = v, tLv = level}}
				server.sendReq(sPlayer, "sc_teachers_update", msg)
			end
		end
	end
end

function TeachersCenter:UpdateOnLine(dbid, isOnLine)
	local dataKey = self.cache.dataKey[dbid]
	if dataKey and dataKey.teacherKey then
		local data = self.cache.data[dataKey.teacherKey]

		if server.playerCenter:IsOnline(data.teacher) then
			local tPlayer = server.playerCenter:GetPlayerByDBID(data.teacher)
			local msg = {studentData = {no = dataKey.teacherKey, sLogin = isOnLine}}

			server.sendReq(tPlayer, "sc_teachers_update", msg)
		end
	end
	if dataKey and dataKey.studentKey then
		for k,v in pairs(dataKey.studentKey) do
			local data = self.cache.data[k]

			if server.playerCenter:IsOnline(data.student) then
				local sPlayer = server.playerCenter:GetPlayerByDBID(data.student)
				local msg = {teacherData = {no = v, tLogin = isOnLine}}

				server.sendReq(sPlayer, "sc_teachers_update", msg)
			end
		end
	end
end

function TeachersCenter:updateMsg(dbid, dataTyp, no, ...)
	local msg = {}

	msg[dataTyp] = self:packUpInfo(no, ...)
	server.sendReqByDBID(dbid, "sc_teachers_update", msg)
end

function TeachersCenter:packInfo(dbid)
	local msg = {teacherData = {}, studentData = {}, messageData = {}}
	local data = self.cache.dataKey[dbid]
	
	if data and data.teacherKey then
		msg.teacherData = self:packTeachersMsg(data.teacherKey)
	end
	
	if data and data.studentKey then
		for k,v in pairs(data.studentKey) do
			table.insert(msg.studentData, self:packTeachersMsg(k))
		end
	end
	
	local msgData = self.cache.msessage[dbid]
	if msgData then

		for k,v in pairs(msgData.teacherList) do

			table.insert(msg.messageData, {
					dbid = v.dbid,
					name = v.name,
					lv = v.lv,
				})
		end
	end

	return msg
end

function TeachersCenter:packTeachersMsg(no)
	local data = self.cache.data[no]
	if not data then return {} end
	local msg = table.wcopy(data)
	msg.data = {}
	msg.no = no
	for k,v in pairs(data.data) do
		local actMsg = {
			actNo = k,
			num = v,
		}
		table.insert(msg.data, actMsg)
	end
	local day = server.serverRunDay
	msg.day = (day - data.day) + 1

	msg.tLogin = server.playerCenter:IsOnline(data.teacher) ~= false

	msg.sLogin = server.playerCenter:IsOnline(data.student) ~= false

	return msg
end

function TeachersCenter:packUpInfo(no, ...)
	local args = {...}
	local msg = {}
	local data = self.cache.data[no]
	msg.no = no
	for k,v in pairs(args) do
		if v == "data" then
			msg.data = {}
			for k,v in pairs(data.data) do
			local actMsg = {
				actNo = k,
				num = v,
			}
			table.insert(msg.data, actMsg)
			end
		elseif v == "tLogin" then
			msg.tLogin = server.playerCenter:IsOnline(data.teacher) ~= false
		elseif v == "sLogin" then
			msg.sLogin = server.playerCenter:IsOnline(data.student) ~= false
		else
			msg[v] = data[v]
		end
	end
	return msg
end

function TeachersCenter:GetExpReward(lv, reward)
	local rewardConfig = server.configCenter.MasterTaskRewardConfig
	for _,v in ipairs(rewardConfig) do
		if lv >= v.level[1] and (not v.level[2] or lv <= v.level[2]) then
			return v[reward]
		end
	end
	return {}
end

function TeachersCenter:show()
	print("=show=",self.cache.no)
	print("msessage=====")
	table.ptable(self.cache.msessage,5)
	print("dataKey=====")
	table.ptable(self.cache.dataKey,5)
	print("data=====")
	table.ptable(self.cache.data, 5)
	print("=show=")
end

function TeachersCenter:clear()
	self.cache.no=1
	self.cache.msessage = {}
	self.cache.dataKey={}
	self.cache.data = {}
	-- self.cache.data[1].rewards=0
end

function TeachersCenter:SetDay(dbid, day)
	local data = self.cache.dataKey[dbid]
	-- print("SetDay--",data,data.teacherKey)
	if not data or not data.teacherKey then return end
	local data1 = self.cache.data[data.teacherKey]
	data1.day = data1.day - day
end

server.SetCenter(TeachersCenter, "teachersCenter")
return TeachersCenter
