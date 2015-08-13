local timer = require("timer")
local core = require("core")

local closure = {}

local function gen_closure(n)
        return function ()
                print("clouser", n)
        end
end

function tm(c)
        c()
end

for i = 1, 30 do
        closure[i] = gen_closure(i)
        timer.add(10, tm, closure[i])
end

function tm1(c)
        print("tm1", c)
end

timer.add(10, tm1)

core.start(function()
        print("hello")
        core.sleep(5000)
        print("world")
end)

