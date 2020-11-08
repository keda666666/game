local FightConfig = {}

FightConfig.Side = {
	Def			= 1,
	Attack 		= 2,
}
FightConfig.OtherSide = {
	[FightConfig.Side.Def] = FightConfig.Side.Attack,
	[FightConfig.Side.Attack] = FightConfig.Side.Def,
}

FightConfig.FightStatus = {
	Ready		= 1,	-- 战斗开始前
	Start		= 2,	-- 回合开始前
	Running		= 3,	-- 攻击时
	End			= 4,	-- 回合结束后
	Over		= 5,	-- 战斗结束后
	Before		= 6,	-- 攻击开始前
	After		= 7,	-- 攻击开始后
	Damage 		= 8,	-- 受到攻击时
}

FightConfig.ActionType = {
	DAMAGE		= 1,	-- 造成伤害
	ADDBUFF		= 2,	-- 增加BUFF
}


FightConfig.ManuallyMode = {
	TARGET		= 1,	-- 支持手动选择目标
	SKILL		= 2,	-- 支持手动选择技能和选择目标
}

FightConfig.BuffStatus = {
	COMA		= 1,		-- 昏迷
	SEAL		= 2,		-- 封印
	FROZEN		= 3,		-- 冰冻
	SLEEP		= 4,		-- 沉睡
	BEATBACK	= 5,		-- 反击
	THORNS		= 6,		-- 反伤
	RELIVE		= 7,		-- 复活
	SUCKBLOOD	= 8,		-- 吸血
	ABSORB		= 9,		-- 吸收伤害
	DOUBLE		= 10,		-- 连击
	RESTORE		= 11,		-- 回血
	POISON		= 12,		-- 中毒
	CLEAN		= 13,		-- 净化
	REVENGE		= 14,		-- 复仇
	DEBUFF		= 15,		-- 给敌人加buff
	GAINBUFF	= 16,		-- 给队友加buff
	BREAK		= 17,		-- 给予敌人伤害并给他加buff
}

FightConfig.FightMsgType = {
	Round			= 0,		-- 下一回合
	UseSkill		= 1,		-- 使用技能
	UseAction		= 2,		-- 技能行为
	ActionHP		= 3,		-- 行为改变血量
	ActionBuff		= 4,		-- 行为添加buff
	BuffHP			= 5,		-- buff改变血量
	Dead			= 6,		-- 死亡
	OutBound		= 7,		-- 出战
	BuffStatusHP	= 8,		-- buff状态改变血量
	BuffStatusAct	= 9,		-- buff状态生效
	Relive			= 10,		-- 复活
	RemoveBuff		= 11,		-- 移除buff
}

return FightConfig