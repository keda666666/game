local oo = require "class"
local server = require "server"
local lua_app = require "lua_app"
local lua_timer = require "lua_timer"

local Head = oo.class()

function Head:ctor(player)
	self.player = player
end

function Head:onCreate()
	self:onLoad()
end

function Head:onLoad()
	self.cache = self.player.cache.head
end

function Head:ActiveFrame(id, term)
	self.cache.frame = id
	self.cache.term = term and term+lua_app.now() or -1
end

function Head:GetFrame()
	local term = self.cache.term  
	local invalid = 0 < term and term < lua_app.now()
	if invalid then
		self.cache.frame = 0
	end
	return self.cache.frame
end

server.playerCenter:SetEvent(Head, "head")
return Head