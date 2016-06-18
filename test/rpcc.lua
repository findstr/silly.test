local core = require "silly.core"
local gate = require "gate"
local zproto = require "zproto"

local logic = zproto:parse [[
test 0xff {
        .name:string 1
        .age:integer 2
}
]]

local function request(fd, index)
        return function()
                local test = {
                        name = "hello",
                        age = index,
                }
                local res = gate.rpccall(fd, "test", test)
                if not res then
                        print("rpc call fail", res)
                        return
                end
                print("rpc call", index, "ret:", res.name, res.age)
        end
end

core.start(function()
        print("connect 8989 start")
        local fd = gate.connect {
                ip = "127.0.0.1",
                port = 9999,
                mode = "rpc",
                proto = logic,
                close = function(fd, errno)
                        print("close", fd, errno)
                end,
                rpc = function(fd, cookie, msg)

                end
        }

        for i = 1, 5 do
                core.fork(request(fd, i))
        end
        core.sleep(10000)
        gate.close(fd)
        core.quit()
end)


