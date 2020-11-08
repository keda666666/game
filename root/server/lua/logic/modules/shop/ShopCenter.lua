local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"
local ShopConfig = require "resource.ShopConfig"
local ItemConfig = require "resource.ItemConfig"
local ShopCenter = {}

function ShopCenter:Init()
	self.dispatch = {}
	self:SecondTimer()
end

function ShopCenter:RefreshStore(shopType)
end

function ShopCenter:SecondTimer()
	if self.sectimer then
		lua_app.del_timer(self.sectimer)
		self.sectimer = nil
	end

	local function _DoSecond()
		self.sectimer = lua_app.add_timer(1000, _DoSecond)
		self:ScheduleDispatch()
	end
	self.sectimer = lua_app.add_timer(1000, _DoSecond)
end

function ShopCenter:ScheduleDispatch()
	local nowtime = lua_app.now()
	for dbid, info in pairs(table.wcopy(self.dispatch)) do
		if info.refreshtime <= nowtime then
			self.dispatch[dbid] = nil
			ShopCenter[info.controlfunc](self, dbid, info.dispatchfunc)
		end
	end
end

function ShopCenter:RegisterDispatch(dbid, refreshdata)
	self.dispatch[dbid] = refreshdata
end

function ShopCenter:RefreshMysticalShop(dbid, dispatchfunc)
	local player = server.playerCenter:GetPlayerByDBID(dbid)
	if player then
		player.shop[dispatchfunc](player.shop)
	end
end

--返回为true时成功
function ShopCenter:CheckPayment(player, goodsList, buyType)
	buyType = buyType or 0
	local paymentlist = {}
	local result = true

	--计算购买
	local function _CalculateBuy(buyCfg, neednum)
		local buycount = {}
		local total = 0
		for id, cfg in ipairs(buyCfg) do
			local cost = cfg.currency
			if cost ~= nil then
				buycount[id] = 0
				while player:CheckReward(cost.type, cost.id, cost.count * (buycount[id] + 1)) do
					buycount[id] = buycount[id] + 1
					total = total + 1
					if total == neednum then break end
				end
			end
			if total == neednum then break end
		end
		return (total == neednum), buycount
	end

	for __, goods in pairs(table.wcopy(goodsList)) do
		if goods.type == ItemConfig.AwardType.Item then
			local bagItemCount = player.bag:GetItemCount(goods.id)
			local needBuyCount = goods.count - bagItemCount
			if bagItemCount > 0 then
				goods.count = math.min(goods.count, bagItemCount)
				table.insert(paymentlist, goods)
			end

			--自动购买
			if needBuyCount > 0 and buyType > 0 then
				local buyCfg = {}
				buyCfg[#buyCfg + 1] = ShopConfig:GetBybItemById(goods.id)
				if buyType == 2 then
					buyCfg[#buyCfg + 1] = ShopConfig:GetYuanBaoItemById(goods.id)
				end
				local ret, buytab = _CalculateBuy(buyCfg, needBuyCount)
				if ret then
					for id, val in pairs(buytab) do
						if val ~= 0 then
							table.insert(paymentlist, {
									type = buyCfg[id].currency.type,
									id = buyCfg[id].currency.id,
									count = buyCfg[id].currency.count * val,
								})
						end
					end
					needBuyCount = 0
				end
			end

			if needBuyCount > 0 then
				result = false
				break
			end
		else
			table.insert(paymentlist, goods)
		end
	end
	return result ,paymentlist
end

function ShopCenter:Release()

end

function ShopCenter:Test()
	table.ptable(self.dispatch, 3)
end

server.SetCenter(ShopCenter, "shopCenter")
return ShopCenter
