local socket = require "socket"
local json = require "json"

local function read_varint(socket)
  local value = 0
  local shift = 0
  local byte = 0x80
  while byte >= 0x80 do
    byte = socket:receive(1):byte()
    value = value + bit32.lshift(bit32.band(byte, 0x7f), shift)
    shift = shift + 7
  end
  return value
end

local function ping()
  local sock = socket.tcp()

  sock:settimeout(1)
  sock:connect("localhost", 25565)

  -- minecraft handshake
  local handshake = {
    string.char(0x10), -- size
    string.char(0x00), -- packet id
    string.char(0xf7), string.char(0x05), -- protocol version
    string.char(0x09), "localhost", -- server address
    string.char(0x63), string.char(0xdd), -- server port
    string.char(0x01), -- next state
  }

  sock:send(table.concat(handshake))
  sock:send(string.char(0x01, 0x00)) -- status request

  local size = read_varint(sock)
  local data = sock:receive(size):sub(4) -- remove packet id, str length

  sock:close()

  return json.decode(data)
end

ping()
