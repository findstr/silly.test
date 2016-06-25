local core = require "silly.core"
local gate = require "gate"
local crypt = require "crypt"
local zproto = require "zproto"

local logic = zproto:parse [[
test 0xff {
        .name:string 1
        .age:integer 2
        .rand:string 3
}
]]

local function quit()
        core.sleep(10000)
        core.quit()
end

gate.listen {
        port = "@9999",
        mode = "rpc",
        proto = logic,
        pack = function(data)
                return crypt.aesencode("hello", data)
        end,
        unpack = function(data)
                return crypt.aesdecode("hello", data)
        end,
        accept = function(fd, addr)
                print("accept", fd, addr)
        end,

        close = function(fd, errno)
                print("close", fd, errno)
        end,

        rpc = function(fd, cookie, msg)
                print("rpc recive", msg.name, msg.age, msg.rand)
                gate.rpcret(fd, cookie, "test", msg)
                print("port1 data finish")
                core.fork(quit)
        end
}
