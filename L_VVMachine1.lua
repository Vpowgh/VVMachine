--[[
L_VVMachine1.lua
Vera plug-in for Vallox MV ventilation machines 
Developed by Vpow 2019
--]]

module("L_VVMachine1", package.seeall)

MYSID = "urn:vpow-com:serviceId:VVMachine1"

local socket = require("socket")
local bit = require('bit')
local sv = { CLOSED = 0, OPEN = 1, IS_CLOSING = 2, ERROR = -1 }
local socketstate = sv.CLOSED
local VVM_ip = ""
local VVM_pollrate = 10 --poll Vallox unit every 10s
local isconnected = false
local pluginDevice = nil
local wsheader = ""

local CellStatusNames = { [0] = 'HEAT RECOVERY', [1] = 'COOL RECOVERY', [2] = 'BYPASS', [3] = 'DEFROST'}

--conversion functions for signals
local vt = {INT = 0, FLO1 = 1, FLO2 = 2, TEMPC = 3, TEMPF = 4}
local vtaction = {
	[vt.INT]  = function (x) return x end,
	[vt.FLO1] = function (x) return x*0.1 end,
	[vt.FLO2] = function (x) return x*0.01 end,
	[vt.TEMPC] = function (x) return tonumber(string.format("%.1f", (x-27315)*0.01)) end, --0.1 precision is enough for temperatures
	[vt.TEMPF] = function (x) return tonumber(string.format("%.1f", (x-27315)*0.018 + 32.0)) end
}

--selected signals from Vallox machine, offset is location in table received by reading metrics
local Extract				= {value=0, name='ExtractTemperature', offset=66, valuetype=vt.TEMPC}
local Exhaust				= {value=0, name='ExhaustTemperature', offset=67, valuetype=vt.TEMPC}
local Outdoor				= {value=0, name='OutdoorTemperature', offset=68, valuetype=vt.TEMPC}
local Supply				= {value=0, name='SupplyTemperature', offset=70, valuetype=vt.TEMPC}
local Fanspeed				= {value=0, name='FanSpeed', offset=65, valuetype=vt.INT}
local Humidity				= {value=0, name='Humidity', offset=75, valuetype=vt.INT}
local State					= {value=0, name='State', offset=108, valuetype=vt.INT}
local CellState				= {value=0, name='CellState', offset=115, valuetype=vt.INT}

local BoostTimer			= {value=0, name='BoostTimer', offset=111, valuetype=vt.INT}
local BoostTime				= {value=0, name='BoostTime', offset=247, valuetype=vt.INT}
local BoostTimerEnabled		= {value=0, name='BoostTimerEnabled', offset=265, valuetype=vt.INT}

local FireplaceTimer	 	= {value=0, name='FireplaceTimer', offset=112, valuetype=vt.INT}
local FireplaceTime			= {value=0, name='FireplaceTime', offset=248, valuetype=vt.INT}
local FireplaceTimerEnabled	= {value=0, name='FireplaceTimerEnabled', offset=266, valuetype=vt.INT}

local ExtraTimer			= {value=0, name='ExtraTimer', offset=113, valuetype=vt.INT}
local ExtraTime				= {value=0, name='ExtraTime', offset=198, valuetype=vt.INT}
local ExtraTimerEnabled		= {value=0, name='ExtraTimerEnabled', offset=271, valuetype=vt.INT}

local Fault					= {value=0, name='Fault', offset=120, valuetype=vt.INT}

local Vallox_signals = {Extract, Exhaust, Outdoor, Supply, Fanspeed, Humidity, State, BoostTimer, BoostTime, BoostTimerEnabled, FireplaceTimer, FireplaceTime, FireplaceTimerEnabled, ExtraTimer, ExtraTime, ExtraTimerEnabled, CellState, Fault}

------------------------------------------------
-- Debug --
------------------------------------------------
local function log(text, level)
  luup.log(string.format("%s: %s", "VVMACHINE", text), (level or 50))
end

------------------------------------------------
-- Helper functions --
------------------------------------------------

local bool_to_number={ [true]=1, [false]=0 }

-- Set variable, only if value has changed.
local function setVar(name, val, dev, sid)
	local s = luup.variable_get(sid, name, dev)

	if s ~= tostring(val) then --since variable get returns string, need to convert val to string also
		luup.variable_set(sid, name, val, dev)
	end
	
	return s -- return old value
end


------------------------------------------------------------------------------------------------------------
-- Vallox ventilation unit control via websockets --
-- websocket implementation originally from reneboer https://github.com/reneboer/vera-Harmony-Hub
------------------------------------------------------------------------------------------------------------

local function VVM_wsconnect(host, port)

	if socketstate ~= sv.CLOSED then
		socketstate = sv.CLOSED
		sock:close()
		log("socket force closed")
	end

	sock = socket.tcp()

	local _,err = sock:connect(host,port)
	if err then
		socketstate = sv.CLOSED
		sock:close()
		log("connection failed")
		return nil,err
	end

	socketstate = sv.OPEN
	sock:settimeout(30)

	local _,err = sock:send(wsheader)
	if err then
		socketstate = sv.CLOSED
		sock:close()
		log("websocket connection failed")
		return nil,err
	end

	local hdr_ok = false

	--check response
	repeat
		local line,err = sock:receive('*l')
		if err then
			socketstate = sv.CLOSED
			sock:close()
			log("websocket reply failed")
			return nil,err
		end

		if line == "HTTP/1.1 101 Switching Protocols" then
			hdr_ok = true
		end
	until line == ''

	if not hdr_ok then
			socketstate = sv.CLOSED
			sock:close()
			log("websocket handshake failed")
		return nil,'websocket handshake failed'
	end

	return true,'websocket connection ok'
end


local function xor_mask(encoded,mask,payload)
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


local function encode(data,opcode)
	local header = (opcode or 1) + 128 -- FIN bit set always
	local payload = 128  -- MASK bit set always
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

local function checksum_16(data)
	local c = 0

	for i=1, (#data-1)/2 do
		local j = i*2
		local x = tonumber(string.byte(data:sub(j,j)))
		j = i*2-1
		local y = tonumber(string.byte(data:sub(j,j)))
		c = c + x*256 + y
	end
	return bit.band(c,0xffff)
end

local function VVM_wssend(cmd)
	--[[
	message structure
	WORD1: number of words in message excluding checksum word
	WORD2: command
		249	0xf9	COMMAND_WRITE_DATA
		246	0xf6	COMMAND_READ_TABLES
	WORD3: address
	WORD4: value
	...
	WORDN-2: address
	WORDN-1: value
	WORDN: checksum
	--]]

	local data
	if cmd == "metrics" then
		data = string.char(0x03, 0x00, 0xf6, 0x00, 0x00, 0x00, 0xf9, 0x00)
	elseif cmd == "Home" then
		data = string.char(0x0a, 0x00, 0xf9, 0x00, 0x01, 0x12, 0x00, 0x00, 0x04, 0x12, 0x00, 0x00, 0x05, 0x12, 0x00, 0x00, 0x06, 0x12, 0x00, 0x00, 0x13, 0x49)
	elseif cmd == "Away" then
		data = string.char(0x0a, 0x00, 0xf9, 0x00, 0x01, 0x12, 0x01, 0x00, 0x04, 0x12, 0x00, 0x00, 0x05, 0x12, 0x00, 0x00, 0x06, 0x12, 0x00, 0x00, 0x14, 0x49)
	elseif cmd == "Boost" then
		data = string.char(0x08, 0x00, 0xf9, 0x00, 0x04, 0x12)
		data = data .. string.char(bit.band(BoostTime.value,0xff),bit.rshift(BoostTime.value,8))
		data = data .. string.char(0x05, 0x12, 0x00, 0x00, 0x06, 0x12, 0x00, 0x00)
		local csum = checksum_16(data)
		data = data .. string.char(bit.band(csum,0xff),bit.rshift(csum,8))
	elseif cmd == "Fireplace" then
		data = string.char(0x08, 0x00, 0xf9, 0x00, 0x04, 0x12, 0x00, 0x00, 0x05, 0x12)
		data = data .. string.char(bit.band(FireplaceTime.value,0xff),bit.rshift(FireplaceTime.value,8))
		data = data .. string.char(0x06, 0x12, 0x00, 0x00)
		local csum = checksum_16(data)
		data = data .. string.char(bit.band(csum,0xff),bit.rshift(csum,8))
	else
		return nil,'no command'
	end

	local encoded = encode(data,2)

	local n,err = sock:send(encoded)
	if err then
		log("sending message failed")
		return nil,err
	end

	return true
end


local function VVM_wsreceive()
	local chunk,err = sock:receive(2)

	local opcode,pllen = chunk:byte(1,2)

	-- FIN bit always set, so just substract 128 to get opcode. Mask bit never set.
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
		socketstate = sv.CLOSED
		sock:close()
		return nil,'Bad response'
	end
	
	--all done, socket can be closed
	socketstate = sv.CLOSED
	sock:close()
	return true, decoded
end


local function VVM_ReadMetrics()
	local a, b = VVM_wsconnect(VVM_ip,80)
	isconnected = false

	if a ~= nil then
		local a, b = VVM_wssend("metrics")
		if a ~= nil then
			local decoded
			a, decoded = VVM_wsreceive()
			if a ~= nil then
				--take selected signals from message, convert and store to table
				for i=1, #Vallox_signals do
					local t=tonumber(string.byte(decoded, Vallox_signals[i].offset*2-1),10)*256 + tonumber(string.byte(decoded, Vallox_signals[i].offset*2),10)
					Vallox_signals[i].value = vtaction[Vallox_signals[i].valuetype](t)
					setVar(Vallox_signals[i].name, Vallox_signals[i].value, pluginDevice, MYSID)
				end
				
				--decrypt machine active profile, checking must be done in priority order!
				local st = nil
				if ExtraTimer.value > 0 then
					st = "Extra"
				elseif FireplaceTimer.value > 0 then
					st = "Fireplace"
				elseif BoostTimer.value > 0 then
					st = "Boost"
				elseif State.value == 0 then
					st = "Home"
				elseif State.value == 1 then
					st = "Away"
				end
				if st ~=nil then
					setVar("Profile",st, dev, MYSID)
				end

				setVar("Fault",Fault.value, dev, MYSID)

				--UI update
				--Vera UI is truncating spaces, so in order to keep string lengths as wanted spaces are replaced with empty chars. max. temperature string length is 5 (-xx.x)
				local row2,_ = string.gsub(string.format("% 5.1f°C % 5.1f°C  %3d%%", Extract.value, Exhaust.value, Fanspeed.value),' ',' ')
				row2 = "<span style = \"font-size: 11pt;font-family:monospace;font-weight:bold\">" .. row2 .. "</span>"
				local row3,_ = string.gsub(string.format("% 5.1f°C % 5.1f°C  %3d%%", Supply.value, Outdoor.value, Humidity.value),' ',' ')
				row3 = "<span style = \"font-size: 11pt;font-family:monospace;font-weight:bold\">" .. row3 .. "</span>"

				if Fault.value == 1 then
					st = 'FAULTED'
				else
					st = CellStatusNames[CellState.value]
				end
				local row5 = string.format("<span style = \"font-size: 11pt;font-family:monospace;font-weight:bold\">  %s</span>",st)

				setVar("UI_row2", row2, pluginDevice, MYSID)
				setVar("UI_row3", row3, pluginDevice, MYSID)
				setVar("UI_row5", row5, pluginDevice, MYSID)

				isconnected = true
			else
				log("receiving metrics failed")
			end
		end
	end

	setVar("Connected", bool_to_number[isconnected], pluginDevice, MYSID) --change logo according connection status
	if not isconnected then --clear display to make sure user sees there is no connection
		setVar("UI_row2","<span style = \"font-size: 11pt;font-family:monospace;font-weight:bold\"> </span>", pluginDevice, MYSID)
		setVar("UI_row3","<span style = \"font-size: 11pt;font-family:monospace;font-weight:bold\"> </span>", pluginDevice, MYSID)
		setVar("UI_row5","", pluginDevice, MYSID)
		setVar("Profile","none", dev, MYSID) --deselect all buttons
	end
end


local function VVM_SetProfile(p)
	setVar("Profile",p, dev, MYSID)

	local a, b = VVM_wsconnect(VVM_ip,80)

	if a ~= nil then
		local a, b = VVM_wssend(p)
		if a ~= nil then
			VVM_wsreceive()
		end
	end
end

--must be global
function updateUserParams(dev, ser, var, vold, vnew)
	--read IP address given by user
	local s = luup.variable_get(MYSID, "ValloxIP", pluginDevice)

	if s ~= nil then
		VVM_ip = s --if IP is not valid, socket will fail anyways
	else
		--if there is no such variable, create it with default value
		luup.variable_set(MYSID, "ValloxIP", "0.0.0.0", pluginDevice)
		VVM_ip = ""
	end

	-- upgrade tp websocket header, use fixed key, need to have one empty line last!
	wsheader = 'GET / HTTP/1.1\r\nHost: ' .. VVM_ip .. '\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: 3K4M5P7Q8RATBUCVEXFYG2J3\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\n'

	log(string.format("IP: %s", VVM_ip))
end


--run once at start, must be global function
function VVM_start(dev)
	log("VVMachine plug-in starting")

	pluginDevice = dev

	updateUserParams()

	--in case user changes parameters, have to update internal variables
	luup.variable_watch("pluginUpdateParams",MYSID,"ValloxIP", pluginDevice)
	luup.variable_watch("pluginUpdateParams",MYSID,"ValloxPollRate", pluginDevice)

	--check internal variables, create them if not existing
	for i=1, #Vallox_signals do
		s = luup.variable_get(MYSID, Vallox_signals[i].name, pluginDevice)

		if s ~= nil then
			Vallox_signals[i].value = tonumber(s)
		else
			--if there is no such variable, create it with default value
			Vallox_signals[i].value = 0
			setVar(Vallox_signals[i].name, Vallox_signals[i].value, pluginDevice, MYSID)
		end
	end

	--UI init
	setVar("UI_row1","<span style = \"color:rgb(0,113,184);font-size: 9pt;font-family:monospace;font-weight:bold\"> Indoor  ►  Exhaust    Fan   </span>", pluginDevice, MYSID)
	setVar("UI_row2","", pluginDevice, MYSID)
	setVar("UI_row3","", pluginDevice, MYSID)
	setVar("UI_row4","<span style = \"color:rgb(0,113,184);font-size: 9pt;font-family:monospace;font-weight:bold\"> Supply  ◄  Outdoor    RH    </span>", pluginDevice, MYSID)
	setVar("UI_row5","", pluginDevice, MYSID)

	--all init done, start running the program
	luup.call_delay("pluginRun", 0, "")

	return true, "ok", "L_VVMachine1"
end

-- run continuously by user given interval, must be global function
function VVM_run()
	VVM_ReadMetrics()

	luup.call_delay("pluginRun", VVM_pollrate, "")
end


------------------------------------------------
-- Actions -- --must be global functions!
------------------------------------------------

function actionSetProfileHome(dev)
	if isconnected then
		VVM_SetProfile("Home")
		log("set Home")
	end
end

function actionSetProfileAway(dev)
	if isconnected then
		VVM_SetProfile("Away")
		log("set Away")
	end
end

function actionSetProfileBoost(dev)
	if isconnected then
		VVM_SetProfile("Boost")
		log("set Boost")
	end
end

function actionSetProfileFireplace(dev)
	if isconnected then
		VVM_SetProfile("Fireplace")
		log("set Fireplace")
	end
end


-- END_OF_FILE

