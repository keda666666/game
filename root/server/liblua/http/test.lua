socket = require "socket"
print(socket._VERSION)

local address = "127.0.0.1"
local port = 8989
local client = assert (socket.connect(address, port))

local chunkPacket = [[
GET /img/add.png HTTP/1.1
Host: 192.168.1.1

ffffff0
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
]]


if nil ~= client then
    local num = client:send(chunkPacket)
    print ("send after")
    if nil ~= num then
        print ("send index="..num)
    end
    client:send("YYYYYYYYYYYYYYYYYYYYY")
    local r = client:receive("*a")
    client:send("ZZZZZZZZZZZZZZZZZZZZZ")

    
    --print("r="..r)
    client:close()
end