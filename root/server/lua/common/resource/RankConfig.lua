local server = require "server"
local RankConfig = {}

RankConfig.RankType = {}
RankConfig.RankType.POWER = 1			-- 总战力
RankConfig.RankType.LEVEL = 2			-- 等级
RankConfig.RankType.PET = 3				-- 宠物
RankConfig.RankType.XIANLV = 4			-- 仙侣
RankConfig.RankType.RIDE = 5			-- 坐骑
RankConfig.RankType.WING = 6			-- 翅膀
RankConfig.RankType.FAIRY = 7			-- 天仙
RankConfig.RankType.WEAPON = 8			-- 神兵
RankConfig.RankType.TIANNV = 9			-- 天女
RankConfig.RankType.TIANSHEN = 10		-- 天神
RankConfig.RankType.CIRCLE = 11			-- 法阵
RankConfig.RankType.POSITION = 12		-- 仙位
RankConfig.RankType.PSYCHIC = 13		-- 通灵
RankConfig.RankType.SOUL = 14			-- 兽魂
RankConfig.RankType.FLOWER = 15			-- 花辇
RankConfig.RankType.NIMBUS = 16			-- 灵气
RankConfig.RankType.CHAPTER = 17		-- 关卡
RankConfig.RankType.WILDGEESE = 18		-- 玲珑宝塔
RankConfig.RankType.HEAVEN = 19			-- 勇闯天庭
-- RankConfig.RankType.LADDER = 11		-- 王者
RankConfig.RankType.BABY = 20			-- 灵童

RankConfig.DynRankType = {}		-- 与RankConfig.RankType表id不能相同
RankConfig.DynRankType.StoneLevel = 101	-- 宝石等级

-- 仅跨服
RankConfig.DynRankType.KfPayYuanbao	= 162		-- 跨服消费排行

-- 开启的排行榜表
RankConfig.LocalOpenType = {
	[RankConfig.RankType.POWER] = true,
	[RankConfig.RankType.LEVEL] = true,
	[RankConfig.RankType.PET] = true,
	[RankConfig.RankType.XIANLV] = true,
	[RankConfig.RankType.RIDE] = true,
	[RankConfig.RankType.WING] = true,
	[RankConfig.RankType.FAIRY] = true,
	[RankConfig.RankType.WEAPON] = true,
	[RankConfig.RankType.TIANNV] = true,
	[RankConfig.RankType.TIANSHEN] = true,
	[RankConfig.RankType.CIRCLE] = true,
	[RankConfig.RankType.POSITION] = true,
	[RankConfig.RankType.PSYCHIC] = true,
	[RankConfig.RankType.SOUL] = true,
	[RankConfig.RankType.FLOWER] = true,
	[RankConfig.RankType.NIMBUS] = true,
	[RankConfig.RankType.CHAPTER] = true,
	[RankConfig.RankType.WILDGEESE] = true,
	[RankConfig.RankType.HEAVEN] = true,
	[RankConfig.RankType.BABY] = true,
}
RankConfig.CrossOpenType = {
}

RankConfig.CompareData = {
	[RankConfig.RankType.POWER]			= "power",
	[RankConfig.RankType.LEVEL]			= "level",
	[RankConfig.RankType.PET]			= "power",
	[RankConfig.RankType.XIANLV]		= "power",
	[RankConfig.RankType.RIDE]			= "power",
	[RankConfig.RankType.WING]			= "power",
	[RankConfig.RankType.FAIRY]			= "power",
	[RankConfig.RankType.WEAPON]		= "power",
	[RankConfig.RankType.TIANNV]		= "power",
	[RankConfig.RankType.TIANSHEN]		= "power",
	[RankConfig.RankType.CIRCLE]		= "power",
	[RankConfig.RankType.POSITION]		= "power",
	[RankConfig.RankType.PSYCHIC]		= "power",
	[RankConfig.RankType.SOUL]			= "power",
	[RankConfig.RankType.FLOWER]		= "power",
	[RankConfig.RankType.NIMBUS]		= "power",
	[RankConfig.RankType.CHAPTER] 		= "chapterlevel",
	[RankConfig.RankType.WILDGEESE]		= "chapterlevel",
	[RankConfig.RankType.HEAVEN]		= "chapterlevel",
	[RankConfig.RankType.BABY]			= "power",
	-- [RankConfig.RankType.LADDER]		= RankConfig.RankType.LADDER,

	[RankConfig.DynRankType.StoneLevel]			= "count",

	[RankConfig.DynRankType.KfPayYuanbao]		= "count",
}

RankConfig.KeyValue = {
	[RankConfig.RankType.POWER]			= {"power"},
	[RankConfig.RankType.LEVEL]			= {"level"},
	[RankConfig.RankType.PET]			= {"power"},
	[RankConfig.RankType.XIANLV]		= {"power"},
	[RankConfig.RankType.RIDE]			= {"power"},
	[RankConfig.RankType.WING]			= {"power"},
	[RankConfig.RankType.FAIRY]			= {"power"},
	[RankConfig.RankType.WEAPON]		= {"power"},
	[RankConfig.RankType.TIANNV]		= {"power"},
	[RankConfig.RankType.TIANSHEN]		= {"power"},
	[RankConfig.RankType.CIRCLE]		= {"power"},
	[RankConfig.RankType.POSITION]		= {"power"},
	[RankConfig.RankType.PSYCHIC]		= {"power"},
	[RankConfig.RankType.SOUL]			= {"power"},
	[RankConfig.RankType.FLOWER]		= {"power"},
	[RankConfig.RankType.NIMBUS]		= {"power"},
	[RankConfig.RankType.CHAPTER]		= {"chapterlevel"},
	[RankConfig.RankType.WILDGEESE]		= {"chapterlevel"},
	[RankConfig.RankType.HEAVEN]		= {"chapterlevel"},
	[RankConfig.RankType.BABY]			= {"power"},
	-- [RankConfig.RankType.LADDER]	= {"challgeLevel", "challgeId", "winNum"},

	[RankConfig.DynRankType.StoneLevel]			= {"count"},

	[RankConfig.DynRankType.KfPayYuanbao]		= {"count"},
}

RankConfig.RealtimeUpdates = {
	[RankConfig.RankType.POWER]			= false,
	[RankConfig.RankType.LEVEL]			= false,
	[RankConfig.RankType.PET]			= false,
	[RankConfig.RankType.XIANLV]		= false,
	[RankConfig.RankType.RIDE]			= false,
	[RankConfig.RankType.WING]			= false,
	[RankConfig.RankType.FAIRY]			= false,
	[RankConfig.RankType.WEAPON]		= false,
	[RankConfig.RankType.TIANNV]		= false,
	[RankConfig.RankType.TIANSHEN]		= false,
	[RankConfig.RankType.CIRCLE]		= false,
	[RankConfig.RankType.POSITION]		= false,
	[RankConfig.RankType.PSYCHIC]		= false,
	[RankConfig.RankType.SOUL]			= false,
	[RankConfig.RankType.FLOWER]		= false,
	[RankConfig.RankType.NIMBUS]		= false,
	[RankConfig.RankType.CHAPTER]		= false,
	[RankConfig.RankType.WILDGEESE]		= false,
	[RankConfig.RankType.HEAVEN]		= false,
	[RankConfig.RankType.BABY]			= false,
	-- [RankConfig.RankType.LADDER]	= true,

	[RankConfig.DynRankType.StoneLevel]			= false,

	[RankConfig.DynRankType.KfPayYuanbao]		= false,
}

RankConfig.MaxRank = {
	[RankConfig.RankType.POWER]			= 1000,
	[RankConfig.RankType.LEVEL]			= 1000,
	[RankConfig.RankType.PET]			= 1000,
	[RankConfig.RankType.XIANLV]		= 1000,
	[RankConfig.RankType.RIDE]			= 1000,
	[RankConfig.RankType.WING]			= 1000,
	[RankConfig.RankType.FAIRY]			= 1000,
	[RankConfig.RankType.WEAPON]		= 1000,
	[RankConfig.RankType.TIANNV]		= 1000,
	[RankConfig.RankType.TIANSHEN]		= 1000,
	[RankConfig.RankType.CIRCLE]		= 1000,
	[RankConfig.RankType.POSITION]		= 1000,
	[RankConfig.RankType.PSYCHIC]		= 1000,
	[RankConfig.RankType.SOUL]			= 1000,
	[RankConfig.RankType.FLOWER]		= 1000,
	[RankConfig.RankType.NIMBUS]		= 1000,
	[RankConfig.RankType.CHAPTER]		= 100,
	[RankConfig.RankType.WILDGEESE]		= 100,
	[RankConfig.RankType.HEAVEN]		= 100,
	[RankConfig.RankType.BABY]			= 1000,
	-- [RankConfig.RankType.LADDER]	= 20,

	[RankConfig.DynRankType.StoneLevel]			= 20,

	[RankConfig.DynRankType.KfPayYuanbao]		= 100,
}
RankConfig.MaxShowRank = {
	[RankConfig.RankType.POWER]			= 200,
	[RankConfig.RankType.LEVEL]			= 200,
	[RankConfig.RankType.PET]			= 200,
	[RankConfig.RankType.XIANLV]		= 200,
	[RankConfig.RankType.RIDE]			= 200,
	[RankConfig.RankType.WING]			= 200,
	[RankConfig.RankType.FAIRY]			= 200,
	[RankConfig.RankType.WEAPON]		= 200,
	[RankConfig.RankType.TIANNV]		= 200,
	[RankConfig.RankType.TIANSHEN]		= 200,
	[RankConfig.RankType.CIRCLE]		= 200,
	[RankConfig.RankType.POSITION]		= 200,
	[RankConfig.RankType.PSYCHIC]		= 200,
	[RankConfig.RankType.SOUL]			= 200,
	[RankConfig.RankType.FLOWER]		= 200,
	[RankConfig.RankType.NIMBUS]		= 200,
	[RankConfig.RankType.CHAPTER]		= 20,
	[RankConfig.RankType.WILDGEESE]		= 20,
	[RankConfig.RankType.HEAVEN]		= 20,
	[RankConfig.RankType.BABY]			= 200,
	-- [RankConfig.RankType.LADDER]	= 20,

	[RankConfig.DynRankType.StoneLevel]			= 0,

	[RankConfig.DynRankType.KfPayYuanbao]		= 0,
}
RankConfig.MaxSendRank = {
	[RankConfig.RankType.POWER]			= 200,
	[RankConfig.RankType.LEVEL]			= 200,
	[RankConfig.RankType.PET]			= 200,
	[RankConfig.RankType.XIANLV]		= 200,
	[RankConfig.RankType.RIDE]			= 200,
	[RankConfig.RankType.WING]			= 200,
	[RankConfig.RankType.FAIRY]			= 200,
	[RankConfig.RankType.WEAPON]		= 200,
	[RankConfig.RankType.TIANNV]		= 200,
	[RankConfig.RankType.TIANSHEN]		= 200,
	[RankConfig.RankType.CIRCLE]		= 200,
	[RankConfig.RankType.POSITION]		= 200,
	[RankConfig.RankType.PSYCHIC]		= 200,
	[RankConfig.RankType.SOUL]			= 200,
	[RankConfig.RankType.FLOWER]		= 200,
	[RankConfig.RankType.NIMBUS]		= 200,
	[RankConfig.RankType.CHAPTER]		= 20,
	[RankConfig.RankType.WILDGEESE]		= 20,
	[RankConfig.RankType.HEAVEN]		= 20,
	[RankConfig.RankType.BABY]			= 20,
	-- [RankConfig.RankType.LADDER]	= 20,

	[RankConfig.DynRankType.StoneLevel]			= 0,

	[RankConfig.DynRankType.KfPayYuanbao]		= 20,
}

RankConfig.RankDatas = {}
RankConfig.RankDatas[RankConfig.RankType.POWER] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "totalpower",
	skin		= "roles-skin_data.wearid",
	outride		= "roles-ride_data.useClothes",
	outwing		= "roles-wing_data.useClothes",
	outweapon	= "roles-weapon_data.useClothes",
	outfairy	= "roles-fairy_data.useClothes",
}
RankConfig.RankDatas[RankConfig.RankType.LEVEL] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "totalpower",
	skin		= "roles-skin_data.wearid",
	outride		= "roles-ride_data.useClothes",
	outwing		= "roles-wing_data.useClothes",
	outweapon	= "roles-weapon_data.useClothes",
	outfairy	= "roles-fairy_data.useClothes",
}
RankConfig.RankDatas[RankConfig.RankType.PET] = {
	level		= "level",
	vip			= "vip",
	power		= "pet.totalpower",
	outpet		= "pet.outbound.&1",
}
RankConfig.RankDatas[RankConfig.RankType.XIANLV] = {
	level		= "level",
	vip			= "vip",
	power		= "xianlv.totalpower",
	outxianlv	= "xianlv.outbound.&1",
}
RankConfig.RankDatas[RankConfig.RankType.RIDE] = {
	level		= "level",
	vip			= "vip",
	power		= "roles-ride_data.totalpower",
	outride		= "roles-ride_data.useClothes",
	lv			= "roles-ride_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.WING] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "roles-wing_data.totalpower",
	outwing		= "roles-wing_data.useClothes",
	skin		= "roles-skin_data.wearid",
	outride		= "roles-ride_data.useClothes",
	lv			= "roles-wing_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.FAIRY] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "roles-fairy_data.totalpower",
	outfairy	= "roles-fairy_data.useClothes",
	skin		= "roles-skin_data.wearid",
	outride		= "roles-ride_data.useClothes",
	lv			= "roles-fairy_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.WEAPON] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "roles-weapon_data.totalpower",
	outweapon	= "roles-weapon_data.useClothes",
	skin		= "roles-skin_data.wearid",
	outride		= "roles-ride_data.useClothes",
	lv			= "roles-weapon_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.TIANNV] = {
	level		= "level",
	vip			= "vip",
	power		= "tiannv.totalpower",
	outtiannv	= "tiannv.tiannv_data.useClothes",
	lv			= "tiannv.tiannv_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.TIANSHEN] = {
	level		= "level",
	vip			= "vip",
	power		= "tianshen.totalpower",
	outtianshen	= "tianshen.use",
}
RankConfig.RankDatas[RankConfig.RankType.CIRCLE] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "xianlv.xianlv_circle_data.totalpower",
	outxianlv	= "xianlv.outbound.&1",
	outcircle	= "xianlv.xianlv_circle_data.useClothes",
	lv			= "xianlv.xianlv_circle_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.POSITION] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "xianlv.xianlv_position_data.totalpower",
	outposition	= "xianlv.xianlv_position_data.useClothes",
	lv			= "xianlv.xianlv_position_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.PSYCHIC] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "pet.pet_psychic_data.totalpower",
	outpsychic	= "pet.pet_psychic_data.useClothes",
	outpet		= "pet.outbound.&1",
	lv			= "pet.pet_psychic_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.SOUL] = {
	job			= "job",
	sex			= "sex",
	level		= "level",
	vip			= "vip",
	power		= "pet.pet_soul_data.totalpower",
	outsoul		= "pet.pet_soul_data.useClothes",
	outpet		= "pet.outbound.&1",
	lv			= "pet.pet_soul_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.FLOWER] = {
	level		= "level",
	vip			= "vip",
	power		= "tiannv.tiannv_flower_data.totalpower",
	outflower	= "tiannv.tiannv_flower_data.useClothes",
	lv			= "tiannv.tiannv_flower_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.NIMBUS] = {
	level		= "level",
	vip			= "vip",
	power		= "tiannv.tiannv_nimbus_data.totalpower",
	outnimbus	= "tiannv.tiannv_nimbus_data.useClothes",
	lv			= "tiannv.tiannv_nimbus_data.lv",
}
RankConfig.RankDatas[RankConfig.RankType.CHAPTER] = {
	level		= "level",
	vip			= "vip",
	power		= "totalpower",
	chapterlevel= "chapter.chapterlevel",
}
RankConfig.RankDatas[RankConfig.RankType.WILDGEESE] = {
	level		= "level",
	vip			= "vip",
	power		= "totalpower",
	chapterlevel= "wildgeeseFb.layer",
}
RankConfig.RankDatas[RankConfig.RankType.HEAVEN] = {
	level		= "level",
	vip			= "vip",
	power		= "totalpower",
	chapterlevel= "heavenFb.layer",
}
RankConfig.RankDatas[RankConfig.RankType.BABY] = {
	level		= "level",
	vip			= "vip",
	power		= "baby.totalpower",
	outbaby		= "baby.baby_data.useClothes",
	outbabysex	= "baby.sex",
	lv			= "baby.baby_data.lv",
}
-- RankConfig.RankDatas[RankConfig.RankType.LADDER] = {
-- 	id				= "dbid",
-- 	name			= "name",
-- 	challgeLevel	= "tianti_level",
-- 	challgeId		= "tianti_dan",
-- 	winNum			= "tianti_win_count",
-- 	job				= "job",
-- 	sex				= "sex",
-- }

RankConfig.RankDatas[RankConfig.DynRankType.StoneLevel] = {
	count		= "total_stone_level",
}

RankConfig.RankDatas[RankConfig.DynRankType.KfPayYuanbao] = {
	count 		= "kf_payyuanbao_value",
	job			= "job",
	sex			= "sex",
}

local _TbnameToModname = {
	roles		= "role",
}
local _RankDataParse = {}
function RankConfig:ParseRankData(data)
	local ret = _RankDataParse[data]
	if ret then
		return ret.sp, ret.modname, ret.tbname
	end
	local sp = string.find(data, "-")
	local function _Split(str, sep)
		local fields = {}
		local pattern = string.format("([^%s]+)", sep)
		str:gsub(pattern, function (c)
			if string.sub(c, 1, 1) == "&" then
				c = tonumber(string.sub(c, 2))
			end
			fields[#fields + 1] = c
		end)
		return fields
	end
	if sp then
		local tbname = string.sub(data, 1, sp - 1)
		ret = {
			sp = _Split(string.sub(data, sp + 1), "."),
			modname = _TbnameToModname[tbname],
			tbname = server.GetSqlName(tbname),
		}
	else
		ret = {
			sp = _Split(data, "."),
			modname = "player",
			tbname = "players",
		}
	end
	_RankDataParse[data] = ret
	return ret.sp, ret.modname, ret.tbname
end

local _LocalRankSqlDatas = {}
for t, datas in pairs(RankConfig.RankDatas) do
	datas.id = "dbid"
	datas.name = "name"
	if RankConfig.LocalOpenType[t] then
		for _, v in pairs(datas) do
			_LocalRankSqlDatas[v] = true
		end
	end
end
local _CrossRankSqlDatas = {}
for t, datas in pairs(RankConfig.RankDatas) do
	datas.serverid = "serverid"				-- 跨服会获取serverid，本服没有
	if RankConfig.CrossOpenType[t] then
		for _, v in pairs(datas) do
			_CrossRankSqlDatas[v] = true
		end
	end
end
if server.index == 0 then
	RankConfig.ActiveRankTypes = RankConfig.LocalOpenType
	RankConfig.AllRankSqlDatas = _LocalRankSqlDatas
else
	RankConfig.ActiveRankTypes = RankConfig.CrossOpenType
	RankConfig.AllRankSqlDatas = _CrossRankSqlDatas
end

function RankConfig:GetRankSqlDatas(ranktype)
	-- if self.LocalOpenType[ranktype] then
	-- 	return _LocalRankSqlDatas
	-- elseif self.CrossOpenType[ranktype] then
	-- 	return _CrossRankSqlDatas
	-- else
	-- 	assert(false)
	-- end
	return self.LocalOpenType[ranktype] and _LocalRankSqlDatas, self.CrossOpenType[ranktype] and _CrossRankSqlDatas
end

return RankConfig
