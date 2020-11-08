local server = require "server"
local lua_app = require "lua_app"
local ActivityConfig = {}


ActivityConfig.ActivityUpgrade = 1			--冲级奖励
ActivityConfig.PackageDiscount = 2			--特价限购
ActivityConfig.RechargeContinue = 3			--连续充值
ActivityConfig.ActivityReach = 4				--达标排行
ActivityConfig.ActivityWeekLogin = 5			--开服登录
ActivityConfig.SpendWheel = 6				--消费转盘
ActivityConfig.ActivityRechargeTotal = 7		--累计充值
ActivityConfig.ActivityInvest = 8			--投资计划
ActivityConfig.ActivityLoop = 9				--循环限购
ActivityConfig.ActivityMergeWing = 10		--羽翼暴击
ActivityConfig.ActivityMergeBag = 11			--合服礼包
ActivityConfig.ActivityMergeRecharge = 12	--合服累计充值
ActivityConfig.CumulativeRecharge = 13		--累充活动
ActivityConfig.ActivityResetDouble = 14		--充值重置
ActivityConfig.ActivitySingleRecharge = 15	--单笔充值
ActivityConfig.ActivityDayLogin = 16		--开服每日登陆
ActivityConfig.ActivityArenaTarget = 17		--每日竞技目标
ActivityConfig.ActivityDayRecharge = 18		--每日充值
ActivityConfig.ActivityCashGift = 19		--人民币礼包
ActivityConfig.ActivityPowerTarget = 20 	--战力目标
ActivityConfig.ActivityRechargeGroupon = 21 	--首充团购
ActivityConfig.ActivityOrangePetTarget = 22 	--橙宠目标
ActivityConfig.ActivityOadvance = 23 --直升一阶
ActivityConfig.ActivityGrowFund = 24 	--成长基金
ActivityConfig.ActivitySpendGift = 25 	--消费有礼
ActivityConfig.ActivityDiscountShop = 26 --折扣商店
ActivityConfig.ActivityRebate = 27 --充值返利
ActivityConfig.DailyRecharge = 28 --每日壕充

ActivityConfig.RechargeDaily = 9000
ActivityConfig.RechargeTotal = 9100
ActivityConfig.RechargeMonth = 9200
ActivityConfig.RechargeGift = 9300

-- 1 名额已满 2 名额未满未达成 3 已达成可领取未领取 4 已领取
ActivityConfig.LevelStatus = {}
ActivityConfig.LevelStatus.NoChance = 1
ActivityConfig.LevelStatus.NoReach = 2
ActivityConfig.LevelStatus.ReachNoReward = 3
ActivityConfig.LevelStatus.Reward = 4

local RankCfg = require "common.resource.RankConfig"

ActivityConfig.Activity2Rank = {}
ActivityConfig.Activity2Rank[1001] = RankCfg.DynRankType.StoneLevel
ActivityConfig.Activity2Rank[1002] = RankCfg.RankType.WING
ActivityConfig.Activity2Rank[1003] = RankCfg.DynRankType.OrangeJinglian
ActivityConfig.Activity2Rank[1004] = RankCfg.DynRankType.OrangePower
ActivityConfig.Activity2Rank[1005] = RankCfg.RankType.LEVEL
ActivityConfig.Activity2Rank[1006] = RankCfg.DynRankType.ExringPower
ActivityConfig.Activity2Rank[1007] = RankCfg.RankType.POWER
ActivityConfig.Activity2Rank[1008] = RankCfg.DynRankType.HefuPayYuanbao
ActivityConfig.Activity2Rank[1009] = RankCfg.DynRankType.DabiaoRecharge
ActivityConfig.Activity2Rank[1010] = RankCfg.DynRankType.DabiaoPayYuanbao
ActivityConfig.Activity2Rank[1011] = RankCfg.RankType.JOB_PET

ActivityConfig.ActivityID = {}
ActivityConfig.ActivityID.PackageSpecial = 8


ActivityConfig.NoticeID = {}
ActivityConfig.NoticeID.FirstRecharge = 100
ActivityConfig.NoticeID.PackageSpecial = 101
ActivityConfig.NoticeID.PackageDiscount = 102
ActivityConfig.NoticeID.ReachID = 103

ActivityConfig.MonthCard = {}
ActivityConfig.MonthCard.NoReach = 0
ActivityConfig.MonthCard.ReachNoReward = 1
ActivityConfig.MonthCard.RewardOver = 2

function ActivityConfig:GetRankData(data,rankType)
	local value = 0
	if rankType == RankCfg.DynRankType.StoneLevel then
		value = data.count
	elseif rankType == RankCfg.RankType.WING then
		value = data.power
	elseif rankType == RankCfg.DynRankType.OrangeJinglian then
		value = data.count
	elseif rankType == RankCfg.DynRankType.OrangePower then
		value = data.power
	elseif rankType == RankCfg.RankType.LEVEL then
		value = data.zhuan*1000+data.level
	elseif rankType == RankCfg.DynRankType.ExringPower then
		value = data.power
	elseif rankType == RankCfg.RankType.POWER then
		value = data.power
	elseif rankType == RankCfg.DynRankType.HefuPayYuanbao then
		value = data.count
	elseif rankType == RankCfg.DynRankType.DabiaoPayYuanbao then
		value = data.count
	elseif rankType == RankCfg.DynRankType.DabiaoRecharge then
		value = data.count
	elseif rankType == RankCfg.RankType.JOB_PET then
		value = data.power
	elseif rankType == RankCfg.RankType.HUASHEN then
		value = data.power
	end
	return value
end

function ActivityConfig:GetRankDataTips(data,rankType)
	local value = ""
	if rankType == RankCfg.DynRankType.StoneLevel then
		value = data.count.."宝石等级"
	elseif rankType == RankCfg.RankType.WING then
		value = data.power.."翅膀战力"
	elseif rankType == RankCfg.DynRankType.OrangeJinglian then
		value = data.count.."橙装精炼"
	elseif rankType == RankCfg.DynRankType.OrangePower then
		value = data.power.."橙装战力"
	elseif rankType == RankCfg.RankType.LEVEL then
		value = data.zhuan.."转"..data.level.."级"
	elseif rankType == RankCfg.DynRankType.ExringPower then
		value = data.power.."特戒战力"
	elseif rankType == RankCfg.RankType.POWER then
		value = data.power.."战力"
	elseif rankType == RankCfg.DynRankType.HefuPayYuanbao then
		value = data.count.."元宝消耗"
	elseif rankType == RankCfg.DynRankType.DabiaoPayYuanbao then
		value = data.count.."元宝消耗 "
	elseif rankType == RankCfg.DynRankType.DabiaoRecharge then
		value = data.count.."充值排行"
	elseif rankType == RankCfg.RankType.JOB_PET then
		value = data.power.."灵兽战力"
	elseif rankType == RankCfg.RankType.HUASHEN then
		value = data.power.."化神战力"
	end
	return value
end

local _PlatCheckCfg = false
local function _GetPlatCheckCfg(activityid)
	if _PlatCheckCfg and _PlatCheckCfg[activityid] then return _PlatCheckCfg[activityid] end
	_PlatCheckCfg = {}
	local function _SetCfg(activityConfig)
		for id, cfg in pairs(activityConfig) do
			local data = {}
			for i = 2, #cfg.qudao do
				data[cfg.qudao[i]] = true
			end
			_PlatCheckCfg[id] = { isUsed = cfg.qudao[1], list = data }
		end
	end
	-- _SetCfg(server.configCenter.ActivitySumConfig)
	_SetCfg(server.configCenter.ActivityConfig)
	-- _SetCfg(server.configCenter.CsActivitySumConfig)
	return _PlatCheckCfg[activityid]
end

function ActivityConfig:CheckPlat(activityid)
	local _CheckCfg = _GetPlatCheckCfg(activityid)
	if not _CheckCfg then return true end
	local plat = server.platformid >= 10000 and server.platformid%10 or server.platformid
	if _CheckCfg.list[plat] then
		return _CheckCfg.isUsed
	else
		return not _CheckCfg.isUsed
	end
end

local _ActivityConfig = false
function ActivityConfig:GetAllActConfig()
	if not _ActivityConfig then
		_ActivityConfig = {}
		for k,v in pairs(server.activityMgr.recordCache.list) do
			_ActivityConfig[k] = v
		end
		for k,v in pairs(server.configCenter.ActivityConfig) do
			_ActivityConfig[k] = v
		end
	end
	return _ActivityConfig
end

function ActivityConfig:ResetActConfig()
	_ActivityConfig = false
end

function ActivityConfig:GetActTypeConfig(id)
	return self:GetAllActConfig()[id]
end

function ActivityConfig:GetActConfig(type, activityid)
	local act = server.activityMgr.recordCache.list[activityid]
	if act then
	 	return act.config
	end
	local cfg = server.configCenter[type]
	if cfg then
		return cfg[activityid]
	end
end

return ActivityConfig
