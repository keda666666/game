local EntityConfig = {}

EntityConfig.EntityType = {
	Role			= 1,
	Pet 			= 2,
	Xianlv			= 3,
	Tiannv			= 4,
	Tianshen		= 5,
	Monster			= 6,
	Boss			= 7,
	Baby			= 8,
	Xianjun			= 9,
}

EntityConfig.Attr = {
	atHP					= 0,	-- 
	atMaxHP					= 1,	-- 生命
	atAttack				= 2,	-- 攻击力
	atDef					= 3,	-- 防御
	atSpeed					= 4,	-- 速度
	atCrit					= 5,	-- 暴击
	atTough					= 6,	-- 抗暴
	atHitRate				= 7,	-- 命中
	atEvade					= 8,	-- 闪避
	atDefy					= 9,	-- 无视防御
	atDefyReduction			= 10,	-- 减免无视防御
	atDamageEnhance			= 11,	-- 伤害加深值
	atDamageReduction		= 12,	-- 伤害减少值
	atDamageEnhancePerc		= 13,	-- 伤害加深万分比
	atDamageReductionPerc	= 14,	-- 伤害减少万分比
	atCritEnhance			= 15,	-- 暴击加成看配置分比
	atCritReduction			= 16,	-- 暴击减少看配置分比
	atPVPEnhance			= 17,	-- PVP伤害加深万分比
	atPVPReduction			= 18,	-- PVP伤害减少万分比
	atPVEEnhance			= 19,	-- PVE伤害加深万分比
	atPVEReduction			= 20,	-- PVE伤害减少万分比
	atBossEnhance			= 21,	-- BOSS伤害加深万分比
	atBossReduction			= 22,	-- BOSS伤害减少万分比
	atSoulEnhance           = 23,   -- 魂击
    atSoulReduction         = 24,   -- 抗魂
    atShieldHP              = 25,   -- 
    atShieldMax             = 26,   -- 
    atSoulAttack            = 27,   -- 仙魂
    atSoulDef               = 28,   -- 仙抗
    atSoulHitEnhance        = 29,   -- 魂击加深
    atSoulHitReduction      = 30,   -- 抗魂加深
    atPursuedEff            = 31,   -- 追击效率加成
    atCureEff               = 32,   -- 治疗效率加成
    atConfineEff            = 33,   -- 禁魔加成
    atConfineResistEff      = 34,   -- 抗魔加成
    atCureReduceEff         = 35,   -- 治疗效率减少
    atRestoreEff            = 36,   -- 回血效率加成（主动技能加血）
    atPursuedResistEff      = 37,   -- 追击抵抗效率5000分比
    atOutbloodEff           = 38,   -- 破血效率加成5000分比
    atOutbloodResistEff     = 39,   -- 破血抵抗加成5000分比
    atRageDrainEff          = 40,   -- 怒气消耗减少5000分比
    atRageAddEff            = 41,   -- 怒气增加加成5000分比
    atSpecialConfine        = 42,   -- 特殊封印加成
    atPvPCritEnhance        = 43,   -- PVP暴伤加成
    atPvPCritReduction      = 44,   -- PVP暴伤减免
	atCount					= 45
}

EntityConfig.ExAttr = {
	eatHPPerc				= 1,	-- 生命万分比
	eatAtkPerc				= 2,	-- 攻击力万分比
	eatDefPerc				= 3,	-- 防御万分比
	eatSpeedPerc			= 4,	-- 速度万分比
	eatCount				= 5
}

-- 特殊属性
EntityConfig.SpecAttr = {
	satShield				= 1,	-- 护盾
	satMaxShield			= 2,	-- 最大护盾
	satCount				= 3
}

EntityConfig.ExAttrToAttr = {
	[EntityConfig.Attr.atMaxHP]		= EntityConfig.ExAttr.eatHPPerc,
	[EntityConfig.Attr.atAttack]	= EntityConfig.ExAttr.eatAtkPerc,
	[EntityConfig.Attr.atDef]		= EntityConfig.ExAttr.eatDefPerc,
	[EntityConfig.Attr.atSpeed]		= EntityConfig.ExAttr.eatSpeedPerc,
}

EntityConfig.EntityConfigAttr = {
	[EntityConfig.Attr.atMaxHP]		= "hp",
	[EntityConfig.Attr.atAttack]	= "atk",
	[EntityConfig.Attr.atDef]		= "def",
	[EntityConfig.Attr.atSpeed]		= "speed",
	[EntityConfig.Attr.atCrit]		= "crit",
	[EntityConfig.Attr.atTough]		= "tough",
	[EntityConfig.Attr.atHitRate]	= "hitrate",
	[EntityConfig.Attr.atEvade]		= "evade",
}

function EntityConfig:GetZeroAttr(count)
	local attrs = {}
	for i = 0, count - 1 do
		attrs[i] = 0
	end
	return attrs
end

function EntityConfig:GetRealAttr(attrs, exattrs)
	local realattrs = {}
	for i = 1, self.Attr.atCount - 1 do
		local percAttr = self.ExAttrToAttr[i]
		if percAttr then
			realattrs[i] = math.floor(attrs[i] * (1 + exattrs[percAttr]/10000))
		else
			realattrs[i] = attrs[i]
		end
	end
	realattrs[self.Attr.atHP] = realattrs[self.Attr.atMaxHP]
	return realattrs
end

function EntityConfig:MultAttr(attrtvs, mult)
	local tmp = table.wcopy(attrtvs)
	for _, v in ipairs(tmp) do
		v.value = v.value * mult
	end
	return tmp
end

return EntityConfig