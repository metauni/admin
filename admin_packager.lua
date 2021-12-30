local args = {...}
local input = args[1] or "build.rbxlx"
local output = args[2] or "metaadmin.rbxmx"

local game = remodel.readPlaceFile(input)
remodel.writeModelFile(game.Chat.ChatModules, output)