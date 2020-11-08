local server = require "server"
local lua_app = require "lua_app"

local UpdateVersion = {}

-- 更新每行的值需要有主键
UpdateVersion[1] = {
	players = {
		heavenFb = function(self, conn, oldoneline)
		local data = {}
		for i=1,50 do
			if oldoneline.rewardNo &(1 << i) ~= 0 then
				data[i] = 1
			end
		end
		oldoneline.rewardNo = data
		return oldoneline
		end,
	}
}
UpdateVersion[2] = {
	players = {
		baby = function(self, conn, oldoneline)
			oldoneline.baby_star = {
				data = {},
				star = 1,
				isBuy = 0,
			}
			return oldoneline
		end,
	}
}
UpdateVersion[3] = {
	players = {
		luck = function(self, conn, oldoneline)
			oldoneline.tianshen = {
				num = 0,
				tenNum = 0,
				allNum = 0,
				reward = 0,
			}
			return oldoneline
		end,
	}
}
UpdateVersion[4] = {
	guild = {
		records = function(self, conn, oldoneline)
			local ChatConstConfig = server.configCenter.ChatConstConfig
			local datas = {}
			datas[1] = {
				records = {},
				maxsize = ChatConstConfig.saveChatListSize,
				nextindex = 1,
			}
			datas[2] = {
				records = {},
				maxsize = ChatConstConfig.saveChatListSize,
				nextindex = 1,
			}

			datas[3] = {
				records = {},
				maxsize = ChatConstConfig.saveGuildChatcount,
				nextindex = 1,
			}
			for __, data in pairs(oldoneline) do
				local record = datas[data.type]
				table.insert(record.records, data)
				record.nextindex = record.nextindex % record.maxsize + 1
			end
			oldoneline = datas
			return oldoneline
		end,
	}
}

UpdateVersion[5] = {
	roles = {
		equips_data = function(self, conn, oldoneline)
			for __, data in pairs(oldoneline.equipList) do
				data.injectcount = 0
				data.injectstage = 0
			end
			return oldoneline
		end,
	}
}

UpdateVersion[6] = {
	players = {
		welfare_data = function(self, conn, oldoneline)
			oldoneline.logingift = {
				receivemark = 0
			}
			return oldoneline
		end,
	}
}

UpdateVersion[7] = {
	players = {
		welfare_data = function(self, conn, oldoneline)
			oldoneline.logingift = {
				receivemark = 0xffff
			}
			return oldoneline
		end,
	}
}

UpdateVersion[8] = {
	players = {
		catchpet = function(self, conn, oldoneline)
			oldoneline = {}
			oldoneline.state = 2
			return oldoneline
		end,
	}
}
UpdateVersion[9] = {
	datalist = {
		eightyonehard = function(self, conn, oldoneline)
			oldoneline.firstReward = {}
			return oldoneline
		end,
	}
}

UpdateVersion[10] = {
	players = {
		luck = function(self, conn, oldoneline)
			oldoneline.daylist = {}
			oldoneline.equiplist = {} --神装抽奖数据
			oldoneline.equipdaylist = {}
			oldoneline.equiplucky = 0
			oldoneline.equiplastlucky = 0
			oldoneline.equipround = 1

			if not oldoneline.list then
				oldoneline.list = {}
			end
			if not oldoneline.lastlucky then
				oldoneline.lastlucky = 0
			end
			if not oldoneline.round then
				oldoneline.round = 1
			end
			return oldoneline
		end,
	}
}

UpdateVersion[11] = {
	datalist = {
		kfboss = function(self, conn, oldoneline)
			oldoneline.firstopen = true
			return oldoneline
		end,
	}
}

UpdateVersion[12] = {
	datalist = {
		guildwar = function(self, conn, oldoneline)
			oldoneline.open = 1
			return oldoneline
		end,
	}
}

UpdateVersion[13] = {
	datalist = {
		guildwar = function(self, conn, oldoneline)
			oldoneline.openinterval = 0
			return oldoneline
		end,
		climb = function(self, conn, oldoneline)
			oldoneline.openinterval = 0
			return oldoneline
		end,
	}
}

UpdateVersion[14] = {
	players = {
		shop = function(self, conn, oldoneline)
			oldoneline.mystical = {
				refreshcount = 0,
				refreshtime = -1,
				datas = {},
			}
			return oldoneline
		end,
	}
}

UpdateVersion[15] = {
	players = {
		recharger_data = function(self, conn, oldoneline)
		local data = {}
		for i=1,30 do
			if oldoneline.firstReward &(1 << i) ~= 0 then
				data[i] = 1
			end
		end
		oldoneline.firstRewardList = data

		local data2 = {}
		for i=1,30 do
			if oldoneline.doubleCharger &(1 << i) ~= 0 then
				data2[i] = 1
			end
		end
		oldoneline.doubleChargerList = data2
		return oldoneline
		end,
	}
}

UpdateVersion[16] = {
	players = {
		recharger_data = function(self, conn, oldoneline)
		local data = {}
		for k,v in pairs(oldoneline.firstRewardList) do
			data[k] = v
		end
		oldoneline.finishList = data
		return oldoneline
		end,
	}
}

UpdateVersion[17] = {
	roles = {
		skin_data = function(self, conn, oldoneline)
		oldoneline.termlist = {}
		return oldoneline
		end,
	}
}

UpdateVersion[18] = {
	players = {
		luck = function(self, conn, oldoneline)
			oldoneline.totemslist = {} --神装抽奖数据
			oldoneline.totemsdaylist = {}
			oldoneline.totemslucky = 0
			oldoneline.totemslastlucky = 0
			oldoneline.totemsround = 1

			return oldoneline
		end,
	}
}

UpdateVersion[19] = {
	datalist = {
		holyPetData = function(self, conn, oldoneline)
			oldoneline.luckLog = {}
			return oldoneline
		end,
	}
}

UpdateVersion[20] = {
	players = {
		recharger_data = function(self, conn, oldoneline)
		if oldoneline.firstRewardList[4] then
			oldoneline.firstRewardList[4] = nil
			oldoneline.firstRewardList[5] = 1
		end
		return oldoneline
		end,
	}
}

UpdateVersion[21] = {
	players = {
		Xianjun = function(self, conn, oldoneline)
		oldoneline.list = {}
		oldoneline.outbound = {0,0,0,0}
		oldoneline.totalpower = 0
		oldoneline.exchangeCount = 0
		return oldoneline
		end,
	}
}

--[[UpdateVersion[22] = {
	roles = {
		fly_data = function(self, conn, oldoneline)
		oldoneline.totalpower = 0,
		oldoneline.xiuWei = 0,
		oldoneline.lv = 0,
		oldoneline.skillList = {},
		oldoneline.equipList = {},
		return oldoneline
		end,
	}
}--]]

-- 	mails = {
-- 		sendtime = function(self, conn, oldonedata)
-- 			return lua_app.now()
-- 		end,
-- 		award = function(self, conn, oldonedata)
-- 			oldonedata[1] = { type=0, id=2, count=485 }
-- 			-- oldonedata = {}
-- 			return oldonedata
-- 		end,
-- 	},

-- 跨服的表名需要修正： tbname = self:GetCorrectTb(tbname)
-- UpdateVersion[1] = function(self, conn)
-- 	print(conn:call_execute("select * from version;"))
-- end

return UpdateVersion