local labels = require "sys.metrics.labels"
local helper = require "sys.metrics.helper"

local mt
local label_mt

mt = {
	__index = nil,
	new = nil,
	collect = helper.collect,
	add = helper.add,
	inc = helper.inc,
	sub = helper.sub,
	dec = helper.dec,
	set = helper.set,
}

label_mt = {
	__index = nil,
	new = nil,
	collect = helper.collect,
	labels = labels({__index = {
		add = helper.add,
		inc = helper.inc,
		sub = helper.sub,
		dec = helper.dec,
		set = helper.set,
	}})
}

local new = helper.new("gauge", {__index = mt}, {__index = label_mt})

mt.new = new
label_mt.new = new

mt.__index = mt
label_mt.__index = label_mt

return new
