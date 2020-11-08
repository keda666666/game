local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local tbname = server.GetSqlName("datalist")
local tbcolumn = "eightyonehard"
local EightyOneHardCenter = {}

function EightyOneHardCenter:Init()
	self.cache = server.mysqlBlob:LoadUniqueDmg(tbname, tbcolumn)
end

function EightyOneHardCenter:Release()
	if self.cache then
		self.cache(true)
		-- self.cache = nil
	end
end

function EightyOneHardCenter:SetData(id, data)
	if not self.cache.first[id] then
		self.cache.first[id] = data
		self:FirstClear(id, data)
	end
	local fastData = self.cache.fast[id]
	if not fastData or fastData.round < data.round then
		self.cache.fast[id] = data
	end
end
function EightyOneHardCenter:FirstClear(id, data)
	--全服发首通奖励
	local players = server.playerCenter:GetOnlinePlayers()
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	local fbConfig = server.configCenter.DisasterFbConfig
	local title = baseConfig.mailtittle
	local name = data.name1
	if data.name2 then
		name = name.."、"..data.name2
		if data.name3 then
			name = name.."、"..data.name3
		end
	end

	local str = string.format( "第%s章第%s关", fbConfig[id].chapterid, fbConfig[id].sectionid)
	local msg = string.format(baseConfig.maildes, name, str)

	for _,player in pairs(players) do
		if player.cache.level >= baseConfig.serverrewardlv then
			self.cache.firstReward[player.dbid][id] = 1
			server.mailCenter:SendMail(player.dbid, title, msg, fbConfig[id].serverreward, server.baseConfig.YuanbaoRecordType.EightyOneHard, "八十一难全服首通")
		end
	end
end

function EightyOneHardCenter:GetData(id)
	return self.cache.first[id], self.cache.fast[id]
end

function EightyOneHardCenter:GetFirstReward(dbid)
	if not self.cache.firstReward[dbid] then
		self.cache.firstReward[dbid] = {}
	end
	local data = table.wcopy(self.cache.firstReward[dbid]) 
	local baseConfig = server.configCenter.DisasterFbBaseConfig
	local fbConfig = server.configCenter.DisasterFbConfig
	local title = baseConfig.mailtittle

	for k,v in pairs(self.cache.first) do
		if not data[k] then
			self.cache.firstReward[dbid][k] = 1
			local name = v.name1
			if v.name2 then
				name = name.."、"..v.name2
				if v.name3 then
					name = name.."、"..v.name3
				end
			end

			local str = string.format( "第%s章第%s关", fbConfig[k].chapterid, fbConfig[k].sectionid)
			local msg = string.format(baseConfig.maildes, name, str)
			server.mailCenter:SendMail(dbid, title, msg, fbConfig[k].serverreward, server.baseConfig.YuanbaoRecordType.EightyOneHard, "八十一难全服首通")
		end
	end
end

server.SetCenter(EightyOneHardCenter, "eightyOneHardCenter")
return EightyOneHardCenter
