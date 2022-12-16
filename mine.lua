local socket = require "socket"
local json = require "json"

local format = [[
Server is up and running!
Version: %s
MOTD: %s
Players: %d/%d
%s
]]

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
    string.char(0xf7, 0x05), -- protocol version
    string.char(0x09), "localhost", -- server address
    string.char(0x63, 0xdd), -- server port
    string.char(0x01), -- next state
  }

  sock:send(table.concat(handshake))
  sock:send(string.char(0x01, 0x00)) -- status request

  local size = read_varint(sock)
  local data = sock:receive(size):sub(4) -- remove packet id, str length

  sock:close()

  return json.decode(data)
end

local function handle_client(client)
  client:settimeout(1)

  local method, uri, version = client:receive():match("(%u+)%s([%p%w]+)%s(HTTP/1.1)")

  -- ignore headers
  for line in function() client:receive() end do end

  if method == "GET" and uri == "/" then
    local status = ping()

    local players = {}

    if status.players.sample then
      for _, player in ipairs(status.players.sample) do
        table.insert(players, "  - " .. player.name)
      end
    end

    local body = format:format(
      status.version.name,
      status.description.text,
      status.players.online,
      status.players.max,
      table.concat(players, "\n")
    )

    local response = {
      "HTTP/1.1 200 OK",
      "Content-Type: text/plain",
      "Content-Length: " .. #body,
      "",
      body,
      "",
    }

    client:send(table.concat(response, "\r\n"))
  end

  client:close()
end

local server = socket.bind("*", 3000)
while true do
  local client = server:accept()
  if client then
    handle_client(client)
  end
end

ping()
