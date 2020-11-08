local server = require "server"

local ServerConfig = {}

ServerConfig.svrNameToNodeName = {
	world		= "cross",
	war			= "cross",
	httpp		= "plat",
	mainplat	= "plat",
	httpr		= "record",
	mainrecord	= "record",
}

server.SetCenter(ServerConfig, "serverConfig")
return ServerConfig
