---
icon: lock
category:
  - 使用指南
tag:
  - 回显服务器
---

# 高并发回显服务器

```lua
local tcp = require "core.net.tcp"
local listenfd = tcp.listen("127.0.0.1:8888", function(fd, addr)
	while true do
		local l = tcp.readline(fd, "\n")
		if not l then
				print("disconnected", fd)
				break
		end
		tcp.write(fd, l)
	end
end)
```


