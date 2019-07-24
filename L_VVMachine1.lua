module("L_VVMachine1", package.seeall)

--[[
L_VVMachine1.lua
Vera plug-in for Vallox MV ventilation machines 
Developed by Vpow 2019
--]]

MYSID = "urn:vpow-com:serviceId:VVMachine1"

local socket = require("socket")
local bit = require('bit')
local sv = { CLOSED = 0, OPEN = 1, IS_CLOSING = 2, ERROR = -1 }
local socketstate = sv.CLOSED
local VVM_ip = ""
local VVM_pollrate = 60
local pluginDevice = nil


vt = { INT = 0, FLO1 = 1, FLO2 = 2, TEMP = 3 }

vtaction = {
	[vt.INT]  = function (x) return x end,
	[vt.FLO1] = function (x) return x*0.1 end,
	[vt.FLO2] = function (x) return x*0.01 end,
	[vt.TEMP] = function (x) return x*0.01-273.15 end,
}

Extract   = {value=0, name='Extract', offset=66, valuetype=vt.TEMP}
Exhaust   = {value=0, name='Exhaust', offset=67, valuetype=vt.TEMP}
Outdoor   = {value=0, name='Outdoor', offset=68, valuetype=vt.TEMP}
Supply    = {value=0, name='Supply', offset=70, valuetype=vt.TEMP}
Fanspeed  = {value=0, name='Fanspeed', offset=65, valuetype=vt.INT}
Humidity  = {value=0, name='Humidity', offset=75, valuetype=vt.INT}
State     = {value=0, name='State', offset=108, valuetype=vt.INT}


Vallox_signals = {Extract, Exhaust, Outdoor, Supply, Fanspeed, Humidity, State}

------------------------------------------------
-- Debug --
------------------------------------------------
function log(text, level)
  luup.log(string.format("%s: %s", "VVMACHINE", text), (level or 50))
end

------------------------------------------------
-- Helper functions --
------------------------------------------------

-- Set variable, only if value has changed.
local function setVar(name, val, dev, sid)
	local s = luup.variable_get(sid, name, dev)
	if s ~= val then
		luup.variable_set(sid, name, val, dev)
	end
	return s -- return old value
end

------------------------------------------------
-- Vallox ventilation unit control --
------------------------------------------------

function VVM_wsconnect(host, port)

	sock = socket.tcp()

	local _,err = sock:connect(host,port)
	if err then
		sock:close()
		return nil,err
	end

	sock:settimeout(30)

	local key = "IVEs+XMFJmzMFU/4qqJEqw=="

	-- upgrade header
	local req = 'GET / HTTP/1.1' .. '\r\n' ..
	'Host: ' .. host .. '\r\n' ..
	'Sec-WebSocket-Version: 13' .. '\r\n' ..
	'Sec-WebSocket-Key: ' .. key .. '\r\n' ..
	'Connection: Upgrade' .. '\r\n' ..
	'Upgrade: websocket' .. '\r\n' ..
	'\r\n' --add empty line last!

	local _,err = sock:send(req)
	if err then
		sock:close()
		return nil,err
	end

	local hdr_ok = false

	--check response
	repeat
		local line,err = sock:receive('*l')
		if err then
			return nil,err
		end

		if line == "HTTP/1.1 101 Switching Protocols" then
			hdr_ok = true
		end
	until line == ''

	if not hdr_ok then
		return nil,'Websocket Handshake failed'
	end

	socketstate = sv.OPEN

	return true
end




local xor_mask = function(encoded,mask,payload)
	local transformed,transformed_arr = {},{}

	for p=1,payload,2000 do
		local last = math.min(p+1999,payload)
		local original = {string.byte(encoded,p,last)}

		for i=1,#original do
			local j = (i-1) % 4 + 1
			transformed[i] = bit.bxor(original[i],mask[j])
		end
		local xored = string.char(unpack(transformed,1,#original))

		table.insert(transformed_arr,xored)
	end

	return table.concat(transformed_arr)
end


local encode = function(data,opcode)
	local header = (opcode or 1) + 128 -- TEXT is default opcode, we always send with FIN bit set
	local payload = 128  -- We always send with mask bit set.
	local len = #data
	local chunks = {}

	payload = bit.bor(payload,len)
	table.insert(chunks,string.char(header,payload))

	local m1 = math.random(0,0xff)
	local m2 = math.random(0,0xff)
	local m3 = math.random(0,0xff)
	local m4 = math.random(0,0xff)
	local mask = {m1,m2,m3,m4}

	table.insert(chunks,string.char(m1,m2,m3,m4))
	table.insert(chunks,xor_mask(data,mask,#data))

	return table.concat(chunks)
end


function VVM_wssend()
	if socketstate ~= sv.OPEN then
		return nil,'wrong socketstate'
	end

	-- WS_WEB_UI_COMMAND_READ_TABLES = 246
	local data = string.char(0x03, 0x00, 0xf6, 0x00, 0x00, 0x00, 0xf9, 0x00)

	local encoded = encode(data,2)

	local n,err = sock:send(encoded)
	if err then
		return nil,err
	end

	return true
end


function VVM_wsreceive()
	if socketstate ~= sv.OPEN and socketstate ~= sv.IS_CLOSING then
		return nil,'wrong socketstate'
	end

	local chunk,err = sock:receive(2)

	local opcode,pllen = chunk:byte(1,2)

	-- Fin bit always set, so just substract 128 to get opcode. Mask bit never set.
	opcode = opcode - 128

	local decoded,err = "",nil

	if opcode ==2 and pllen == 126 then --Vallox response uses this size, no need to check bigger ones
		local chunk,err = sock:receive(2)
		if err then
			return nil,err
		end

		local lb2,lb1 = chunk:byte(1,2)
		pllen = lb2*0x100 + lb1

		decoded,err = sock:receive(pllen)
		if err then
			return nil,err
		end
	else
		return nil,'Bad response'
	end

	return true, decoded
end


-- run continuously by user given interval
function VVM_run()
	local a, b = VVM_wsconnect(VVM_ip,80)

	if a ~= nil then
		local a, b = VVM_wssend()
		if a ~= nil then
			local decoded
			a, decoded = VVM_wsreceive()
			if a ~= nil then
				--take selected signals from message, convert and store to table
				for i=1, #Vallox_signals do
					local t=tonumber(string.byte(decoded, Vallox_signals[i].offset*2-1),10)*256 + tonumber(string.byte(decoded, Vallox_signals[i].offset*2),10)
					Vallox_signals[i].value = vtaction[Vallox_signals[i].valuetype](t)
				end

				--UI handling
                local row2 = string.format("%.1f °C     ", Extract.value) .. string.format("%.1f °C     ", Exhaust.value) .. string.format("%d %%", Fanspeed.value)
                local row4 = string.format("%.1f °C     ", Supply.value)  .. string.format("%.1f °C     ", Outdoor.value) .. string.format("%d %%", Humidity.value)
                setVar("UI_row2", row2, pluginDevice, MYSID)
                setVar("UI_row4", row4, pluginDevice, MYSID)
                log(row2)
                log(row4)
			end
		end
	end

    luup.call_delay("pluginRun", VVM_pollrate, "")
end

--run once at start
function start(dev)
	log("VVMachine plug-in starting")

	pluginDevice = dev

	--read IP address given by user
	local s = luup.variable_get(MYSID, "ValloxIP", pluginDevice)

	if s ~= nil then
		VVM_ip = s --if IP is not valid, socket will fail anyways
	else
		--if there is no such variable, create it with default value
		luup.variable_set(MYSID, "ValloxIP", "0.0.0.0", pluginDevice)
		VVM_ip = ""
	end

	--read pollrate given by user
	s = luup.variable_get(MYSID, "ValloxPollRate", pluginDevice)

	if s ~= nil then
		s = tonumber(s)
		local limited = false
		if s<10 then
			s = 10
			limited = true
		end
		if s>600 then
			s = 600
			limited = true
		end

		VVM_pollrate = s

		if limited then
			luup.variable_set(MYSID, "ValloxPollRate", VVM_pollrate, pluginDevice)
		end
	else
		--if there is no such variable, create it with default value
		luup.variable_set(MYSID, "ValloxPollRate", "60", pluginDevice)
		VVM_pollrate = 60
	end

	log(string.format("IP: %s", VVM_ip))
	log(string.format("Pollrate: %s", VVM_pollrate))

    --UI init
    setVar("UI_row1","<span style = \"color:blue;font-size: 8pt\">Indoor    ►    Exhaust         Fan    </span>", pluginDevice, MYSID)
    --setVar("UI_row1","Indoor ► Exhaust    Fan    ", pluginDevice, MYSID)
    setVar("UI_row2","-", pluginDevice, MYSID)
    setVar("UI_row3"," ", pluginDevice, MYSID)
    --setVar("UI_row3","<span style = \"color:green;; font-size: 8pt\">WARNING</span>", pluginDevice, MYSID)
    
    setVar("UI_row4","-", pluginDevice, MYSID)
    
    setVar("UI_row5","<span style = \"color:blue;font-size: 8pt\">Supply    ◄    Outdoor         RH    </span>", pluginDevice, MYSID)
    --setVar("UI_row5","Supply ◄ Outdoor    RH    ", pluginDevice, MYSID)

	setVar("ModeStatus","Home", pluginDevice, MYSID)

    luup.call_delay("pluginRun", VVM_pollrate, "")

	return true, "ok", "L_VVMachine1"
end


function actionExample(dev, arguments )
	setVar("ModeStatus",arguments.newValue, dev, MYSID)
	
	log(string.format("ACTION: %s %s", dev, arguments))
end


-- do not delete, last line must be a CR according to MCV wiki page

