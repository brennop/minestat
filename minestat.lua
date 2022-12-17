#!/usr/bin/env lua

local socket = require "socket"
local http = require "http.server"
local json = require "json"

local bit = bit32 or require "bit"

local format = [[
Server is up and running!
Version: %s
MOTD: %s
Players: %d/%d
%s
]]

local function read_varint(client)
  local value = 0
  local shift = 0
  local byte = 0x80
  while byte >= 0x80 do
    byte = client:receive(1):byte()
    value = value + bit.lshift(bit.band(byte, 0x7F), shift)
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
    string.char(0xf7, 0x05), -- protocol version
    string.char(0x09), "localhost", -- server address
    string.char(0x63, 0xdd), -- server port
    string.char(0x01), -- next state
  }

  sock:send(table.concat(handshake))
  sock:send(string.char(0x01, 0x00)) -- status request

  local ok, size = pcall(read_varint, sock)
  if not ok then return end

  local data = sock:receive(size):sub(4) -- remove packet id, str length

  sock:close()

  return json.decode(data)
end

http.get("/", function()
  local status = ping()

  if status then
    local players = {}

    if status.players.sample then
      for _, player in ipairs(status.players.sample) do
        table.insert(players, "  - " .. player.name)
      end
    end

    return format:format(
      status.version.name,
      status.description.text,
      status.players.online,
      status.players.max,
      table.concat(players, "\n")
    )
  else
    return "Server is offline!"
  end
end)

http.listen(3000)
