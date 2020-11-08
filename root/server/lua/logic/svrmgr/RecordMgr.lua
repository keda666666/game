local lua_app = require "lua_app"
local server = require "server"
local ItemConfig = require "resource.ItemConfig"
local paytbname = server.GetSqlName("pay")
local gmcmdtbname = server.GetSqlName("gmcmd")
local globalusertbname = server.GetSqlName("globaluser")
local logtbname = server.GetSqlName("log")

local RecordMgr = {}

--这里可能要初始化一个定时器，然后进行后台命令的处理 add wupeng
function RecordMgr:Init()
	self.timerID = lua_app.add_update_timer(1000, self, "RunTime")	
	self.gmtimerID = lua_app.add_update_timer(1000, self, "RunGmCmd")

	--创建pay充值表，gmcmd 
	server.mysqlBlob:CreateDmg(paytbname)
	server.mysqlBlob:CreateDmg(gmcmdtbname)
	server.mysqlBlob:CreateDmg(globalusertbname)
	server.mysqlBlob:CreateDmg(logtbname)

	self.logTimerID = lua_app.add_update_timer(1000 * 60, self, "RunLogTime")
end

function RecordMgr:RunLogTime()
	self.logTimerID = lua_app.add_update_timer(1000 * 60, self, "RunLogTime")

	local playerlist = server.playerCenter:GetOnlinePlayers()
	local num = 0
	for __, player in pairs(playerlist) do
		num = num + 1
	end

	--上报在线人数
	local data = {
		log_time = lua_app.now(),
		serverid = server.serverid,
		type = "Online",
		value1 = num,
	}
	server.mysqlCenter:insert(logtbname,data)
end

function RecordMgr:RunTime()
	self.timerID = lua_app.add_update_timer(1000, self, "RunTime")
	--定时检查玩家充值数据
        local paycaches = server.mysqlCenter:query(paytbname, { serverid = server.serverid }, { dbid=true, playerid = true, serverid=true, goodsid=true })
        for i,caches in ipairs(paycaches) do
                self:Recharge(tonumber(caches.playerid), tonumber(caches.goodsid))

                server.mysqlCenter:delete(paytbname, { dbid = caches.dbid, serverid = caches.serverid })
        end
end


function RecordMgr:RunGmCmd()
	self.gmtimerID = lua_app.add_update_timer(1000, self, "RunGmCmd")	

        local gmcaches = server.mysqlCenter:query(gmcmdtbname, { serverid = server.serverid }, { dbid=true, serverid=true, cmd=true, param1=true, param2=true, param3=true, param4=true, param5=true, param6=true, param7=true })
        for i,caches in pairs(gmcaches) do
                local cmd = caches.cmd
                local param1 = caches.param1
                local param2 = caches.param2
                local param3 = caches.param3
                local param4 = caches.param4
                local param5 = caches.param5
                local param6 = caches.param6
                local param7 = caches.param7
                self:GmCmd(cmd, param1, param2, param3, param4, param5, param6, param7)

                server.mysqlCenter:delete(gmcmdtbname, { dbid = caches.dbid, serverid = caches.serverid })
        end
end

--处理后台GM命令
function RecordMgr:GmCmd(cmd, param1, param2, param3, param4, param5, param6, param7)

	if cmd == "Silent"then --禁言
		--[[local playerlist = server.playerCenter:GetOnlinePlayers()
		for __, player in pairs(playerlist) do
    			if player.cache.name == param1 then
    				self:SilentPlayer(player.dbid, tonumber(param2))
    				break
    			end
		end]]		
		self:SilentPlayer(tonumber(param1), tonumber(param2))
		server.kingArenaMgr:Open()
	elseif cmd == "Sealed" then --封玩家，并且踢下线
		--[[local playerlist = server.playerCenter:GetOnlinePlayers()
                for __, player in pairs(playerlist) do
                        if player.cache.name == param1 then
				self:SealedPlayer(player.dbid, tonumber(param2))
                                break
                        end
                end]]
		self:SealedPlayer(tonumber(param1), tonumber(param2))
	elseif cmd == "Kick" then  --踢玩家下线
		self:KickOffPlayer(tonumber(param1))
	elseif cmd == "Recharge" then --给指定玩家充值
		self:Recharge(tonumber(param1), tonumber(param2))
	elseif cmd == "DelActivity" then --关闭指定活动
		self:DelActivity(tonumber(param1))
	elseif cmd == "Item" then --发物品
		self:Toitem(tonumber(param1), param2, tonumber(param3))
	elseif cmd == "RunCMD" then
		self:RunCMD(tonumber(param1),param2)
	elseif cmd == "Allmail" then
		local mailcaches = server.mysqlCenter:query("players", { serverid = server.serverid }, { dbid=true})
		local rewardwin = {
			{type = tonumber(param1), id = tonumber(param2), count = tonumber(param3)}
		}
		for k,v in pairs(mailcaches) do
			server.mailCenter:SendMail(v.dbid, "补偿奖励", "亲爱的玩家，这是这次游戏异常的全服补偿礼包，祝您游戏愉快", rewardwin, 101)
		end	
	elseif cmd == "mail" then
		local rewardwin = {
			{type = tonumber(param2), id = tonumber(param3), count = tonumber(param4)}
		}
		server.mailCenter:SendMail(tonumber(param1), "补偿奖励", "亲爱的玩家，这是GM美眉给您提供的礼包，祝您游戏愉快", rewardwin, 101)
	elseif cmd == "clearitem" then
		self:Clearitem(tonumber(param1))
		server.serverRunDay = server.serverRunDay + 1
		print(server.serverRunDay.."-----------------")
		server.onevent(server.event.daytimer, server.serverRunDay)
		server.dataPack:BroadcastDtbAndLocal("onrecvevent", server.event.daytimer, server.serverRunDay)
	end
end

function RecordMgr:SilentPlayer(playerid, endtime)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("RecordMgr:SilentPlayer:: not exist account:", playerid)
		return false
	end
	player.cache.silent = endtime or 0
	server.chatCenter:SetFilter(endtime or 0, playerid)
	return true
end

function RecordMgr:SealedPlayer(playerid, endtime)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("RecordMgr:SealedPlayer:: not exist account:", playerid)
		return false
	end
	player.cache.sealed = endtime or 0
	if endtime == -1 or endtime > lua_app.now() then
		local player = server.playerCenter:GetPlayerByDBID(playerid)
		-- 踢玩家下线
		if player then
			server.playerCenter:KickOff(player)
		end
	end
	return true
end

function RecordMgr:KickOffPlayer(playerid)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("RecordMgr:SealedPlayer:: not exist account:", playerid)
		return false
	end
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	-- 踢玩家下线
	if player then
		server.playerCenter:KickOff(player)
	end

	return true
end

function RecordMgr:Toitem(playerid, name, count)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end

	for id, cfg in pairs(server.configCenter.ItemConfig) do
		if cfg.name == name then
			player:GiveReward(ItemConfig.AwardType.Item, id, count, 1, server.baseConfig.YuanbaoRecordType.GMCMD)
			return true
		end
	end
end

function RecordMgr:Clearitem(playerid)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end
	player:ClearItem()
	return true
end

function RecordMgr:RunCMD(playerid,str)
	local player = server.playerCenter:GetPlayerByDBID(playerid)
	if not player then return end

	player.gm:BRunCMD(str)
end

function RecordMgr:GetRankDatas(rankType, beginrank, endrank)
	return server.serverCenter:CallLocalMod("world", "rankCenter", "GetRankDatas", rankType, beginrank, endrank)
end

function RecordMgr:Recharge(playerid, goodsid)
	lua_app.log_info("------------- RecordMgr:Recharge:", playerid, goodsid)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then
		lua_app.log_error("RecordMgr:Recharge: no account:", playerid, goodsid)
		return false
	end
	local needrecharge = player.recharge:GetRechargeInfo(goodsid)
	local yuanbao = player.recharge:Recharge(goodsid)
	if not yuanbao then
		lua_app.log_error("RecordMgr:Recharge: error recharge:", player.cache.account, player.cache.name,
			playerid, goodsid, needrecharge, yuanbao)
		return false
	end
	return true, player.cache.name, yuanbao, player.ip
end

function RecordMgr:SetResetServer(serverid)
	if server.serverid ~= serverid then
		lua_app.log_error("RecordMgr:ResetServer::server.serverid ~= serverid", server.serverid, serverid)
		return false
	end
	server.timerCenter:SetResetServer()
	return true
end

function RecordMgr:AddActivity(config)
	server.serverCenter:SendLocalMod("world", "activityMgr", "AddActivityRecord", config)
end

function RecordMgr:DelActivity(id)
	server.serverCenter:SendLocalMod("world", "activityMgr", "DelActivityRecord", id)
end

function RecordMgr:GetPlayerDetail(playerid)
	local player = server.playerCenter:DoGetPlayerByDBID(playerid)
	if not player then return false end
	-- 角色
	local roledata = {}
	roledata.name = player.cache.name
	roledata.level = player.cache.level
	roledata.exp = player.cache.exp
	roledata.gold = player.cache.gold
	roledata.yuanbao = player.cache.yuanbao
	roledata.byb = player.cache.byb
	roledata.contrib = player.cache.contrib
	roledata.totalpower = player.cache.totalpower
	roledata.equips = {}
	local equipforge = {}
	for i = 0, ItemConfig.EquipSlotType.MAX-1 do
		local equip = player.role.equip.equipList[i]
		local data = { id = equip.cache.item.id }
		if data.id ~= 0 then
			local cfg = server.configCenter.ItemConfig[data.id]
			data.name = cfg.name
			data.quality = cfg.quality
			data.level = cfg.level
			data.power = ItemConfig:GetEquipPower(equip.cache.item)
		end
		table.insert(roledata.equips, data)
		for _, forgetype in pairs(ItemConfig.ForgeType) do
			equipforge[forgetype] = equipforge[forgetype] or { level = 0, power = 0 }
			equipforge[forgetype].suitlevel = player.role.equip:GetTupoSuitLevel(forgetype)
			local suitcfg = ItemConfig:GetForgeSuitConfig(forgetype)[equipforge[forgetype].suitlevel]
			equipforge[forgetype].suitpower = suitcfg and ItemConfig:GetAttrsPower(suitcfg.attrs) or 0
			local level = equip:GetForgeLevel(forgetype)
			if level > 0 then
				equipforge[forgetype].level = equipforge[forgetype].level + level
	    		local forgecfg = ItemConfig:GetForgeAttrConfig(forgetype)[equip.slot * 200 + level]
	    		if forgecfg then
					equipforge[forgetype].power = equipforge[forgetype].power + ItemConfig:GetAttrsPower(forgecfg.attr)
				end
			end
		end
	end
	roledata.equipforge = equipforge
	-- 进阶系统
	local function _GetTemplateData(tpl)
		local data = {}
		data.lv = tpl.cache.lv
		data.upNum = tpl.cache.upNum
		data.totalpower = tpl.cache.totalpower
		data.drugNum = tpl.cache.drugNum
		data.drugpower = ItemConfig:GetAttrsPower(tpl:AddDrugNumAttr())
		data.skinpower = ItemConfig:GetAttrsPower(tpl:AddSkinAttr())
		data.skins = {}
		for clothesNo, _ in pairs(tpl.cache.clothesList) do
			table.insert(data.skins, clothesNo)
		end
		data.skilllist = tpl.cache.skillList
		data.skillpower = ItemConfig:GetAttrsPower(tpl:AddSkillAttr())
		data.equiplist = {}
		for num, item in pairs(tpl.cache.equipList) do
			data.equiplist[num] = item.id
		end
		data.equippower = ItemConfig:GetAttrsPower(tpl:AddEquipAttr())
		return data
	end
	local templatedatas = {
		ride = _GetTemplateData(player.role.ride),
		wing = _GetTemplateData(player.role.wing),
		weapon = _GetTemplateData(player.role.weapon),
		fairy = _GetTemplateData(player.role.fairy),

		circle = _GetTemplateData(player.xianlv.circle),
		position = _GetTemplateData(player.xianlv.position),
		psychic = _GetTemplateData(player.pet.psychic),
		soul = _GetTemplateData(player.pet.soul),
		flower = _GetTemplateData(player.tiannv.flower),
		nimbus = _GetTemplateData(player.tiannv.nimbus),
	}
	-- 宠物
	local petlist = {}
	local EffectsConfig = server.configCenter.EffectsConfig
	for _, info in pairs(player.pet.cache.list) do
		local pBCfg = server.configCenter.petBiographyConfig[info.petid]
		local skills = {}
		for _, buffid in ipairs(info.buffs) do
			table.insert(skills, EffectsConfig[buffid].skinName)
		end
		table.insert(petlist, {
			id = info.petid,
			rarity = pBCfg.rarity,
			quality = pBCfg.quality,
			level = info.level,
			exp = info.exp,
			giftlv = info.giftlv,
			giftexp = info.giftexp,
			name = info.name,
			xilian = info.xilian,
			power = ItemConfig:GetAttrsPower(pBCfg.attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.petLvproConfig[pBCfg.rarity][info.level].attrs),
			skills = skills,
		})
	end
	local petinfo = {
		count = table.length(player.pet.cache.list),
		totalpower = player.pet.cache.totalpower,
		list = petlist,
	}
	-- 仙侣
	local xianlvlist = {}
	for _, info in pairs(player.xianlv.cache.list) do
		local pBCfg = server.configCenter.partnerBiographyConfig[info.id]
		table.insert(xianlvlist, {
			id = info.id,
			name = pBCfg.name,
			quality = pBCfg.quality,
			level = info.level,
			exp = info.exp,
			star = info.star,
			power = ItemConfig:GetAttrsPower(pBCfg.attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerLvproConfig[pBCfg.quality][info.level].attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerGiftConfig[pBCfg.quality][info.level].attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerAttrsConfig[info.id][info.star].attrs),
		})
	end
	local xianlvinfo = {
		count = table.length(player.xianlv.cache.list),
		totalpower = player.xianlv.cache.totalpower,
		list = xianlvlist,
	}
	-- 仙君
	local xianjunlist = {}
	for _, info in pairs(player.xianjun.cache.list) do
		local pBCfg = server.configCenter.partnerBiographyConfig[info.id]
		table.insert(xianjunlist, {
			id = info.id,
			name = pBCfg.name,
			quality = pBCfg.quality,
			level = info.level,
			exp = info.exp,
			star = info.star,
			power = ItemConfig:GetAttrsPower(pBCfg.attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerLvproConfig[pBCfg.quality][info.level].attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerGiftConfig[pBCfg.quality][info.level].attrs) +
				ItemConfig:GetAttrsPower(server.configCenter.partnerAttrsConfig[info.id][info.star].attrs),
		})
	end
	local xianjuninfo = {
		count = table.length(player.xianjun.cache.list),
		totalpower = player.xianjun.cache.totalpower,
		list = xianjunlist,
	}
	
	-- 玄女
	local SkillsConfig = server.configCenter.SkillsConfig
	local FemaleDevaBaseConfig = server.configCenter.FemaleDevaBaseConfig
	local tiannvinfo = {
		lv = player.tiannv.cache.tiannv_data.lv,
		upNum = player.tiannv.cache.tiannv_data.upNum,
		drugNum = player.tiannv.cache.tiannv_data.drugNum,
		totalpower = player.tiannv.cache.totalpower,
		faqis = table.wcopy(player.tiannv.cache.attrdatas.attrs),
		skills = { SkillsConfig[FemaleDevaBaseConfig.skill].skinName, SkillsConfig[FemaleDevaBaseConfig.hskill].skinName },
		faqipower = 0,
		faqiwashnum = 0,
	}
	local attrsConfig = server.configCenter.FemaleDevaSkillAttrsConfig
	for pos, faqi in pairs(tiannvinfo.faqis) do
		local attrs, skillno = player.tiannv:ProcessingAttr(faqi.attrs)
		if skillno and SkillsConfig[skillno] then
			table.insert(tiannvinfo.skills, SkillsConfig[skillno].skinName)
		end
		tiannvinfo.faqiwashnum = tiannvinfo.faqiwashnum + faqi.washNum
		faqi.power = ItemConfig:GetAttrsPower(attrs)
		tiannvinfo.faqipower = tiannvinfo.faqipower + faqi.power
		for _, v in pairs(faqi.attrs) do
			if v.type == 1 then
				if attrsConfig[v.attrs] then
					v.attrs = attrsConfig[v.attrs].attrs
				end
			else
				v.skillname = SkillsConfig[v.skillNo] and SkillsConfig[v.skillNo].skinName
			end
		end
	end
	-- 灵童
	local ActCfg = server.configCenter.BabyActivationConfig[player.baby.cache.sex]
	local babyinfo = {}
	if ActCfg then
		babyinfo = {
			lv = player.baby.cache.baby_data.lv,
			upNum = player.baby.cache.baby_data.upNum,
			drugNum = player.baby.cache.baby_data.drugNum,
			totalpower = player.baby.cache.totalpower,
			giftlv = player.baby.cache.giftlv,
			giftexp = player.baby.cache.giftexp,
			useskills = {},
			buffs = {},
		}
		for _, v in ipairs(ActCfg.skill) do
			table.insert(babyinfo.useskills, SkillsConfig[v].skinName)
		end
		for _, v in ipairs(player.baby.cache.buffs) do
			table.insert(babyinfo.buffs, EffectsConfig[v].skinName)
		end
	end
	-- 法宝
	local fabao = { totalpower = 0, list = {} }
	local SpellsResListConfig = server.configCenter.SpellsResListConfig
	for _, v in ipairs(player.role.spellsRes.cache.useSpells) do
		if not v.spellsNo or v.spellsNo == 0 then
			table.insert(fabao.list, {})
		else
			local SpellsResLvproConfig = server.configCenter.SpellsResLvproConfig[v.spellsNo][v.lv]
			local totalpower = ItemConfig:GetAttrsPower(SpellsResLvproConfig.attrs)
			table.insert(fabao.list, {
					id = v.spellsNo,
					lv = v.lv,
					name = SpellsResListConfig[v.spellsNo].name,
					quality = SpellsResListConfig[v.spellsNo].quality,
					skillname = SpellsResLvproConfig.skillid and SpellsResLvproConfig.skillid > 0 and
						server.configCenter.SkillsConfig[SpellsResLvproConfig.skillid].skinName,
					totalpower = totalpower,
				})
			fabao.totalpower = fabao.totalpower + totalpower
		end
	end
	-- 丹药
	local panacea = {
		attrs = player.role.panacea.cache.allattrs,
		lvlist = player.role.panacea.lvlist,
	}
	return {
		roledata = roledata,
		templatedatas = templatedatas,
		petinfo = petinfo,
		xianlvinfo = xianlvinfo,
		tiannvinfo = tiannvinfo,
		babyinfo = babyinfo,
		fabao = fabao,
		panacea = panacea,
		eightyone = player.eightyOneHard.clear,
		treasuremap = player.treasuremap:MaxClear(),
		wildgeese = player.cache.wildgeeseFb.layer,
		heaven = player.cache.heavenFb.layer,
	}
end

function RecordMgr:Heavengifts(cfg, playerids)
	if cfg.close then
		lua_app.log_info("-- RecordMgr:Heavengifts close", cfg.payType, cfg.gid)
	else
		lua_app.log_info("-- RecordMgr:Heavengifts open", cfg.payType, cfg.gid, cfg.gtype, cfg.endTime, cfg.headtext)
	end
	if cfg.payType == 102 then
		if cfg.close then
			server.heavenGifts.rechargeGodLike:CloseConfig(cfg.gid)
		else
			server.heavenGifts.rechargeGodLike:AddConfig(cfg)
		end
	elseif cfg.payType == 101 then
		if cfg.close then
			for _, playerid in pairs(playerids) do
				local player = server.playerCenter:DoGetPlayerByDBID(playerid)
				if player then
					server.heavenGifts.rechargeHolyShit:CloseConfig(cfg.gid, player)
				else
					lua_app.log_error("RecordMgr:Heavengifts: no player: dbid", playerid)
				end
			end
		else
			for _, playerid in pairs(playerids) do
				local player = server.playerCenter:DoGetPlayerByDBID(playerid)
				if player then
					server.heavenGifts.rechargeHolyShit:AddConfig(cfg, player)
				else
					lua_app.log_error("RecordMgr:Heavengifts: no player: dbid", playerid)
				end
			end
		end
	else
		lua_app.log_error("RecordMgr:Heavengifts: no payType", cfg.payType)
	end
end

server.SetCenter(RecordMgr, "recordMgr")
return RecordMgr
