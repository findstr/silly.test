local tcp = require "core.net.tcp"
local tls = require "core.net.tls"
local h2 = require "core.http.h2stream"
local code = require "core.grpc.code"
local codename = require "core.grpc.codename"
local transport = require "core.http.transport"
local pb = require "pb"
local pack = string.pack
local format = string.format
local tonumber = tonumber
local setmetatable = setmetatable
local M = {}

local HDR_SIZE<const> = 5
local MAX_LEN<const> = 4*1024*1024

local function dispatch(registrar)
	local input_name = registrar.input_name
	local output_name = registrar.output_name
	local handlers = registrar.handlers
	--use closure for less hash
	return function(stream)
		local status, header = stream:readheader()
		if status ~= 200 then
			stream:respond(200, {
				['content-type'] = 'application/grpc',
				['grpc-status'] = code.Unknown,
				['grpc-message'] = "grpc: invalid header"
			}, true)
			return
		end
		local method = header[':path']
		local itype = input_name[method]
		local otype = output_name[method]
		local data = ""
		--read header
		for i = 1, 4 do
			local d, _ = stream:read()
			if not d or d == "" then
				stream:close()
				return
			end
			data = data .. d
			if #data >= HDR_SIZE then
				break
			end
		end
		local _, len = string.unpack(">I1I4", data)
		if len > MAX_LEN then
			stream:respond(200, {
				['content-type'] = 'application/grpc',
				['grpc-status'] = code.ResourceExhausted,
				['grpc-message'] = format("grpc: received message larger than max (%s vs. %s)", len, MAX_LEN),
			}, true)
			return
		end
		if #data < (len + HDR_SIZE) then
			local d, reason = stream:readall()
			if not d then
				stream:respond(200, {
					['content-type'] = 'application/grpc',
					['grpc-status'] = code.Unknown,
					['grpc-message'] = reason,
				}, true)
				return
			end
			data = data .. d
		end
		local input = pb.decode(itype, data:sub(HDR_SIZE+1))
		local output = assert(handlers[method], method)(input)
		local outdata = pb.encode(otype, output)
		--payloadFormat, length, data
		outdata = pack(">I1I4", 0, #outdata) .. outdata
		stream:respond(200, {
			['content-type'] = 'application/grpc',
		})
		stream:close(outdata, {
			['grpc-status'] = code.OK,
		})
	end
end

function M.listen(conf)
	local listen, scheme_mt
	local http2d = h2.httpd(dispatch(conf.registrar))
	if conf.tls then
		listen = tls.listen
	 	scheme_mt = transport.scheme_io["https"]
	else
		listen = tcp.listen
	 	scheme_mt = transport.scheme_io["http"]
	end
	local fd = listen(conf.addr, function(fd, addr)
		local socket = setmetatable({fd}, scheme_mt)
		http2d(socket, addr)
	end)
	return setmetatable({fd}, scheme_mt)
end

local function find_service(proto, name)
	for _, v in pairs(proto['service']) do
		if v.name == name then
			return v
		end
	end
	return nil
end

local alpn_protos = {"h2"}

function M.newclient(conf)
	local service_name = conf.service
	local endpoints = {}
	for i, addr in pairs(conf.endpoints) do
		local host, port = addr:match("([^:]+):(%d+)")
		if not host or not port then
			return nil, "invalid addr"
		end
		endpoints[i] = {host, port}
	end
	local proto = conf.proto
	local scheme = conf.tls and "https" or "http"
	local package = proto.package
	local input_name = {}
	local output_name = {}
	local service = find_service(proto, service_name)
	if not service then
		return nil, "grpc: service not found"
	end
	for _, method in pairs(service['method']) do
		local name = method.name
		local input_type = method.input_type
		local output_type = method.output_type
		input_name[name] = input_type
		output_name[name] = output_type
	end
	local timeout = conf.timeout
	local round_robin = 0
	local endpoint_count = #endpoints
	local mt = {
		__index = function(t, k)
			local full_name = format("/%s.%s/%s", package, service_name, k)
			local itype = input_name[k]
			local otype = output_name[k]
			local fn = function(req)
				local endpoint = endpoints[round_robin]
				round_robin = (round_robin % endpoint_count) + 1
				local host, port = endpoint[1], endpoint[2]
				local socket, err = transport.connect(scheme, host, port, alpn_protos, true)
				if not socket then
					return nil, err
				end
				local stream<close>, err = h2.new(scheme, socket)
				if not stream then
					return nil, err
				end
				local ok, err = stream:request("POST", full_name, {
					[":authority"] = host,
					["content-type"] = "application/grpc",
				}, false)
				if not ok then
					return nil, err
				end
				local reqdat = pb.encode(itype, req)
				reqdat = pack(">I1I4", 0, #reqdat) .. reqdat
				stream:write(reqdat)
				local status, header = stream:readheader(timeout)
				if not status then
					return nil, header
				end
				local body
				local grpc_message
				local grpc_status = header['grpc-status']
				if not grpc_status then	--normal header
					local reason
					body, reason = stream:readall(timeout)
					if not body then
						return nil, reason
					end
					if #body < HDR_SIZE then
						return nil, "grpc: invalid body"
					end
					local trailer, reason = stream:readtrailer(timeout)
					if not trailer then
						return nil, reason
					end
					grpc_status = trailer['grpc-status']
					grpc_message = trailer['grpc-message']
				else
					grpc_message = header['grpc-message']
				end
				grpc_status = tonumber(grpc_status)
				if grpc_status ~= code.OK then
					return nil, format("code = %s desc = %s",
						codename[grpc_status], grpc_message)
				end
				local resp = pb.decode(otype, body:sub(HDR_SIZE+1))
				if not resp then
					return nil, "decode error"
				end
				return resp, nil
			end
			t[k] = fn
			return fn
		end,
	}
	return setmetatable({}, mt)
end

return M
