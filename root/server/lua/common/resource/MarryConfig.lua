local server = require "server"
local MarryConfig = {}

MarryConfig.spouse = {
	Husband			= 1,	--夫君
	Wife			= 2,	--妻子
}

server.SetCenter(MarryConfig, "marryConfig")
return MarryConfig