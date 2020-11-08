local server = require "server"
local lua_app = require "lua_app"

local ChatConfig = {}

ChatConfig.ChatType = {
	System = 0, 	--系统
	WorldChat = 1, 	--世界聊天
	PrivateChat = 2, --私聊
	SysChat = 3,	--系统消息
}

ChatConfig.CollectType = {
	Player = 0,	--玩家
	Pet = 1, 	--宠物
	Treasure = 2, --法宝
	Ride = 3, 	--坐骑
	Fb = 4, 	--副本
	Item = 5, 	--装备
	Xianlv = 6, --仙侣
}

--分享链接ID
ChatConfig.LinkId = {
	AssistPkBoss = 20, 	--关卡协助
}

ChatConfig.LinkTips = {
	[ChatConfig.LinkId.AssistPkBoss] = "已发送求助信息到世界聊天"
}

--缺省CD
ChatConfig.LinkDefaultInterval = 5

ChatConfig.LinkInterval = setmetatable({}, {__index = function()
	return server.chatConfig.LinkDefaultInterval
end})
ChatConfig.LinkInterval[20] = 5

ChatConfig.intervalrecord = {}
function ChatConfig:GetWaitInterval(flag, interval)
	local nowtime = lua_app.now()
	local waittime = self.intervalrecord[flag] or nowtime
	if waittime <= nowtime then
		self.intervalrecord[flag] = (interval or self.LinkInterval[flag]) + nowtime
	end
	return waittime - nowtime
end

local _CollectData = {}
_CollectData[ChatConfig.CollectType.Player] = function(chatdata, value)
	local player = server.playerCenter:GetPlayerByDBID(value)
	table.insert(chatdata.player, {
			name = player.cache.name,
			id = player.dbid,
			vip = player.cache.vip,
			guildid = player.cache.guildid,
			guildName = player.guild:GetGuildName(),
		})
end

local _Additional = {}
--客户端分享id，需要拼接的内容
_Additional[20] = function(datas, dbid)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	datas.contexts = {}
	datas.params = {}
	local chapterlv = player.cache.chapter.chapterlevel
	local ChaptersConfig = server.configCenter.ChaptersConfig[chapterlv]
	table.insert(datas.contexts, player.cache.name)
	table.insert(datas.contexts, ChaptersConfig.desc)
	table.insert(datas.params, {
			type = ChatConfig.CollectType.Fb,
			value = chapterlv,
		})
end

--生成内容
function ChatConfig:GenContext(id, ...)
	local ChatTipsConfig = server.configCenter.ChatTipsConfig[id]
	local args = {...}
	local str
	if args[1] then
		str = string.format(ChatTipsConfig.chatTips, ...)
	else
		str = ChatTipsConfig.chatTips
	end
	return str, ChatTipsConfig.type
end

function ChatConfig:PackSender(sender)
	if type(sender) == "number" then
		sender = server.playerCenter:GetPlayerByDBID(sender)
	end
	return sender:BaseInfo()
end

function ChatConfig:PackLinkData(id, sender, ...)
	local chatdata = {}
	if sender then
		sender = self:PackSender(sender)
		chatdata = {
			id = sender.dbid,
			name = sender.name,
			vip = sender.vip,
			job = sender.job,
			sex = sender.sex,
		}
	end
	local arg = {...}
	local datas = {
		params = {},
		contexts = {},
	}

	for __, element in ipairs(arg) do
		if type(element) == "table" then
			table.insert(datas.params, {
					type = element[1] or element.type,
					value = element[2] or element.value,
					valueEx = element[3] or element.valueEx,
					strvalue = element[4] or element.strvalue,
				})
		else
			table.insert(datas.contexts, element)
		end
	end
	if _Additional[id] then
		_Additional[id](datas, sender.dbid)
	end
	--生成分享文本
	local str, channel = self:GenContext(id, table.unpack(datas.contexts))
	chatdata.str = str
	chatdata.type = channel
	chatdata.time = lua_app.now()

	--分享需要的数据
	chatdata.share = {
		shareId = id,
		player = {},
		showInfo = {},
	}
	if datas.params then
		for __, param in ipairs(datas.params) do
			if _CollectData[param.type] then
				_CollectData[param.type](chatdata.share, param.value)
			else
				table.insert(chatdata.share.showInfo, table.wcopy(param))
			end
		end
	end

	return chatdata
end

server.SetCenter(ChatConfig, "chatConfig")
return ChatConfig