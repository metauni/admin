-- ADAPTED FROM https://devforum.roblox.com/t/making-chat-admin-commands-using-the-chat-service/871157

local Settings = {
	Prefix = "/"; -- Symbol that lets the script know the message is a command
	DebugMode = false; -- Set to true when making new commands so it's easier to identify errors
	Admins = {
		-- Dictionary of user ids and the rank the player with that user id will be receiving (rank must be a number)
		-- These entries overwrite whatever is saved in the permissions DataStore everytime the server is started (see game:BindToClose)
		[tostring(game.CreatorId)] = math.huge; -- The creator gets infinity permission level
		-- Hard code more roles here, which will overwrite any changes when the server restarts
		-- e.g. To make player with user ID 1234 a permanent admin, add this (make sure the ID is a string)
		-- ["1234"] = 10;
        ["2211421151"] = 10;
	};
	DefaultPerm = 0;
	ScribePerm = 5;
	AdminPerm = 10;
	BanKickMessage = "You have been banned by an admin.";
	BanOnJoinMessage = "You are banned."
}

-- [[ Services ]] --
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayersService = game:GetService("Players")
local DataStore = game:GetService("DataStoreService")

-- [[ Data Stores]]
local permissionsDataStore = DataStore:GetDataStore("permissionsDataStore")
local permissions = permissionsDataStore:GetAsync("permissions") or {}
local scribeOnlyMode = permissionsDataStore:GetAsync("scribeOnlyMode") or false

local remoteFunctions = {}
local remoteEvents = {}

function LoadStoredInfo()
	if scribeOnlyMode then
		print("Whiteboards deactivated for guests on startup")
	else
		print("Whiteboards activated for guests on startup")
	end

	for userIdStr, level in pairs(Settings.Admins) do
		SetPermLevel(userIdStr, level)
	end

	local countAdmin = 0
	local countGuest = 0
	local countBanned = 0
	for userIdStr, level in pairs(permissions) do
		if level >= Settings.AdminPerm then
			countAdmin += 1
		elseif isBanned(userIdStr) then
			countBanned += 1
		else
			countGuest += 1
		end
	end

	print("Loaded permissions table with "..(countAdmin + countBanned + countGuest).." entries.")
	print(countAdmin.." admins, "..countBanned.." banned, and "..countGuest.." others." )

	if Settings.DebugMode then
		print("UserId | Permissions Level")
		print("-------------------")
		for userIdStr, level in pairs(permissions) do
			print(userIdStr, level)
		end
	end
end

--Gets the permission level of the player from their player object
function GetPermLevel(userId)
	local permission = permissions[tostring(userId)]

	if permission then
		return permission
	else
		return Settings.DefaultPerm
	end
end

function GetPermLevelPlayer(player)
	return GetPermLevel(player.UserId)
end

function isBanned(userId) 
	return GetPermLevel(userId) < Settings.DefaultPerm
end

function isAdmin(userId)
	return GetPermLevel(userId) >= Settings.AdminPerm
end

function isScribe(userId)
    return GetPermLevel(userId) >= Settings.ScribePerm
end

-- Everyone can write on whiteboards, unless
-- they are turned off in which case only scribes
-- or above can write
function canWriteOnWhiteboards(userId)
    local permLevel = GetPermLevel(userId)

    if scribeOnlyMode then
        return permLevel >= Settings.ScribePerm
    else
        return true
    end
end

--Sets the permission level of the speaker
function SetPermLevel(userId, level)
	permissions[tostring(userId)] = level
end

--Tells the player to update their local knowledge of the permissions
function UpdatePerms(userId)
    local player = nil
	local success, response = pcall(function() player = PlayersService:GetPlayerByUserId(tonumber(userId)) end)
	if player then
        if remoteEvents["PermissionsUpdate"] then remoteEvents["PermissionsUpdate"]:FireClient(player) end
	end
end

function SetBanned(userId)
	SetPermLevel(userId, -1)
end

function SetDefault(userId)
	SetPermLevel(userId, Settings.DefaultPerm)
end

game:BindToClose(function()
	local countAdmin = 0
	local countGuest = 0
	local countBanned = 0
	for userIdStr, level in pairs(permissions) do
		if level >= Settings.AdminPerm then
			countAdmin += 1
		elseif isBanned(userIdStr) then
			countBanned += 1
		else
			countGuest += 1
		end
	end

	print("Writing "..(countAdmin + countBanned + countGuest).." permission entries to Data Store")
	print(countAdmin.." admins, "..countBanned.." banned, and "..countGuest.." others." )
	permissionsDataStore:SetAsync("permissions", permissions)
	permissionsDataStore:SetAsync("scribeOnlyMode", scribeOnlyMode)
end)

-- Kicks banned players when they join and re-admins the admins when they join
PlayersService.PlayerAdded:Connect(function(player)
	print(player.name.." joined")
	if isBanned(player.UserId) then
		print("Kicked "..player.Name.." because they are banned. UserId: "..player.UserId..", Permission Level: "..GetPermLevel(player.UserId))
		player:Kick(Settings.BanOnJoinMessage)
		return
	else
		local hardCodedLevel = Settings.Admins[player.UserId]
		if hardCodedLevel then
			SetPermLevel(player.UserId, hardCodedLevel)
		end
	end
end)

-- ##############################################################

function SendMessageToClient(data, speakerName)
	local ChatService = require(ServerScriptService.ChatServiceRunner.ChatService)
	-- The ChatService can also be found in the ServerScriptService
	local Speaker = ChatService:GetSpeaker(speakerName)
	-- The speaker is another module script in the ChatServiceRunner that has functions related to the speaker and some other things
	local extraData = {Color = data.ChatColor} -- Sets the color of the message
	Speaker:SendSystemMessage(data.Text, "All", extraData)
	-- Sends a private message to the speaker
end

-- Returns nil if user Id can't be found
-- Happens when GetUserIdFromNameAsync raises an error
function GetUserId(name)
	local player = PlayersService:FindFirstChild(name)

	if player then
		return player.UserId
	else
		local userId = nil
		local success, reponse = pcall(function() userId = PlayersService:GetUserIdFromNameAsync(name) end)
		if success then
			return userId
		else
			return nil
		end
	end
end

function GetPermLevelName(name)
	local userId = GetUserId(name)

	if userId then
		return GetPermLevel(userId)
	else
		return Settings.DefaultPerm
	end
end

function GetTarget(player, msg)
	local msgl = msg:lower()
	local ts = {} -- Targets table

	if msgl == "all" then
		--// Loop through all players and add them to the targets table
		for i, v in pairs(PlayersService:GetPlayers()) do
			table.insert(ts, v)
		end
	elseif msgl == "others" then
		--// Loops through all players and only adds them to the targets table if they aren't the player
		for i, v in pairs(PlayersService:GetPlayers()) do
			if v.Name ~= player.Name then
				table.insert(ts, v)
			end
		end
	elseif msgl == "guests" then
		--// Loops through all players and only adds them to the targets table if they aren't the player
		for i, v in pairs(PlayersService:GetPlayers()) do
			if GetPermLevel(v) < Settings.AdminPerm then
				table.insert(ts, v)
			end
		end
	elseif msgl == "me" then
		--// Loops through all players and only adds them to the targets table if they are the player
		for i, v in pairs(PlayersService:GetPlayers()) do
			if v.Name == player.Name then
				table.insert(ts, v)
			end
		end
	else
		for i, v in pairs(PlayersService:GetPlayers()) do
			if v.Name == msg then
				table.insert(ts, v)
			end
		end
	end
	return ts
end

local commands = {}

local function getHelpMessage()
	local message = "Admin Commands:\n--------------"
	for commandName, data in pairs(commands) do
		if data.usage then
			message = message.."\n"..data.usage	
			if data.brief then
				message = message.."\n  "..data.brief
			end
		end
	end
	message = message.."\nUse /<command>? for more info about a command, e.g. /ban?"
	return message
end

local function sendCommandHelp(speakerName, commandName)
	local data = commands[commandName]
	if data then
		local message = ""
		if data.usage then
			message = data.usage
			if data.help then
				message = message.."\n  "..data.help
			elseif data.brief then
				message = message.."\n  "..data.brief
			end

			if data.examples then
				message = message.."\nExamples:"
				for _, example in ipairs(data.examples) do
					message = message.."\n  "..example
				end
			end

			SendMessageToClient({
				Text = message;
				ChatColor = Color3.new(0, 1, 0)
			}, speakerName)
		end
	end
end

-- Adds a new command to the commands table
function BindCommand(data)
	commands[data.name] = data
end

function BindCommands()

	BindCommand(
		{	name = "kick",
			usage = Settings.Prefix.."kick <name> [reason]",
			brief = "Kick a player, with an optional message",
			help = "Kick a player, with an optional message. This will instantly remove them from the game, but they can rejoin again immediately.",
			examples = {Settings.Prefix.."kick newton bye bye"},
			perm = Settings.AdminPerm,
			func = function(speaker, args)
				local commandTargets = GetTarget(speaker, args[1])

				if #commandTargets == 0 then
					-- No target was specified so we can't do anything
					SendMessageToClient({
						Text = "No targets specified";
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
					return false
				end

				local kick_message = table.concat(args, " ")
				kick_message = kick_message:sub(#args[1]+2)

				for _, target in pairs(commandTargets) do
					-- Loop through targets table
					local targetPerm = GetPermLevelPlayer(target)
					local speakerPerm = GetPermLevelPlayer(speaker)
					if targetPerm < speakerPerm or speaker == target then
						target:Kick(kick_message)
						SendMessageToClient({
							Text = "Kicked "..target.Name;
							ChatColor = Color3.new(0, 1, 0)
						}, speaker.Name)
					else
						-- People of lower ranks can't use it on higher ranks or people of the same rank
						SendMessageToClient({
							Text = "You cannot use this command on "..target.Name..". They outrank you.";
							ChatColor = Color3.new(1, 0, 0)
						}, speaker.Name)
					end


				end
			end
		})

	BindCommand({
		name = "banstatus",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."banstatus <name>...",
		brief = "Check if a user is banned or not",
		help = "Check if a user is banned or not. Also shows permission level",
		func = function(speaker, args)
			if #args == 0 then
				SendMessageToClient({
					Text = "No arguments given.";
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
				return false
			end

			for _, name in ipairs(args) do
				local userId = GetUserId(name)
				if userId then
					if isBanned(userId) then
						SendMessageToClient({
							Text = name.." is banned (User ID: "..userId.." ).";
							ChatColor = Color3.new(1, 0, 0)
						}, speaker.Name)
					else
						SendMessageToClient({
							Text = name.." is not banned (User ID: "..userId..", Permission level: "..GetPermLevel(userId)..").";
							ChatColor = Color3.new(0, 1, 0)
						}, speaker.Name)
					end
				else
					SendMessageToClient({
						Text = "Unable to get User Id of player with name: "..name;
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end
			end
		end
	})

	BindCommand({
		name = "ban",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."ban <name>...",
		brief = "Ban 1 or more players",
		help = "Ban 1 or more players. Lowers their stored permission level below the ban threshold. They are instantly kicked and will be re-kicked every time they rejoin.",
		examples = {Settings.Prefix.."ban euler", Settings.Prefix.."ban leibniz gauss"},
		func = function(speaker, args)

			if #args == 0 then
				SendMessageToClient({
					Text = "No arguments given.";
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
				return false
			end

			for _, name in ipairs(args) do
				local userId = GetUserId(name)
				if userId then
					if isAdmin(userId) then
						SendMessageToClient({
							Text = "You cannot ban an admin.";
							ChatColor = Color3.new(1, 0, 0)
						}, speaker.Name)
					else
						SetBanned(userId)		
						local player = PlayersService:GetPlayerByUserId(userId)
						if player then
							player:Kick(Settings.BanKickMessage)
							SendMessageToClient({
								Text = "User Id "..userId.." of "..name.." banned. They were kicked from this game.";
								ChatColor = Color3.new(0, 1, 0)
							}, speaker.Name)
						else
							SendMessageToClient({
								Text = name.." banned (UserId: "..userId.."). They were not found in this game, so have not been kicked.";
								ChatColor = Color3.new(0, 1, 0)
							}, speaker.Name)
						end
					end
				else
					SendMessageToClient({
						Text = "Unable to get User Id of player with name: "..name;
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end
			end
		end
	})

	BindCommand({
		name = "unban",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."unban <name>...",
		brief = "Unban 1 or more players",
		help = "Unban 1 or more players. Raises their permission level to the default/guest level if they are banned.",
		examples = {Settings.Prefix.."unban euler", Settings.Prefix.."unban leibniz gauss"},
		func = function(speaker, args)

			if #args == 0 then
				SendMessageToClient({
					Text = "No arguments given.";
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
				return false
			end

			for _, name in ipairs(args) do
				local userId = GetUserId(name)

				if userId then
					if isBanned(userId) then
						SetDefault(userId)
						SendMessageToClient({
							Text = name.." unbanned (UserId: "..userId..", Permission level: "..tostring(GetPermLevel(userId))..").";
							ChatColor = Color3.new(0, 1, 0)
						}, speaker.Name)
					else
						SendMessageToClient({
							Text = name.." is already not banned (UserId: "..userId..", Permission level: "..tostring(GetPermLevel(userId))..")";
							ChatColor = Color3.new(1, 0, 0)
						}, speaker.Name)
					end
				else
					SendMessageToClient({
						Text = "Unable to get User Id of player with name: "..name;
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end
			end
		end})

	BindCommand({
		name = "boards",
		perm = Settings.ScribePerm,
		usage = Settings.Prefix.."boards {on|off}",
		brief = "Turn the whiteboards on/off for guests (anyone below scribe level)",
		help = "'"..Settings.Prefix.."boards off' deactivates drawing on whiteboards for guests, and anyone with permission level below 'scribe'.\n'"..Settings.Prefix.."boards on' allows anyone to draw on whiteboards",
		examples = {Settings.Prefix.."boards off", Settings.Prefix.."boards on"},
		func = function(speaker, args)
			local activateMode = true

			if args[1] then
				if args[1]:lower() == "off" then
					activateMode = false
					scribeOnlyMode = true
				elseif args[1]:lower() == "on" then
					activateMode = true
					scribeOnlyMode = false
				else
					return false
				end
			else
				return false
			end

            if remoteEvents["PermissionsUpdate"] then
                remoteEvents["PermissionsUpdate"]:FireAllClients()
            end

			local actionWord = "???"
			if activateMode then
				actionWord = "activated"
			else
				actionWord = "deactivated"
			end

			SendMessageToClient({
				Text = "whiteboards "..actionWord.." for guests";
				ChatColor = Color3.new(0, 1, 0)
			}, speaker.Name)
		end
	})

	local function setLevel(level)
		return (function(speaker, args)
			if #args == 0 then
				return false
			end

			for _, name in ipairs(args) do
				local userId = GetUserId(name)

				if userId then
					if Settings.Admins[userId] then
						SendMessageToClient({
							Text = "This player's permission level is hardcoded to the value "..tostring(Settings.Admins[userId])..". This change will be overwritten when the server restarts.";
							ChatColor = Color3.new(1, 0, 0)
						}, speaker.Name)
					end

					SetPermLevel(userId, level)
                    UpdatePerms(userId)

					SendMessageToClient({
						Text = name.." given permission level "..tostring(level);
						ChatColor = Color3.new(0, 1, 0)
					}, speaker.Name)
				else
					SendMessageToClient({
						Text = "Unable to get User Id of player with name: "..name;
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end
			end
		end)
	end

	BindCommand({
		name = "setadmin",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."setadmin <name>...",
		brief = "Set the permission level of 1 or more players to admin",
		help = "Set the permission level of 1 or more players to admin. This will be overwritten on restart if their permission level is hardcoded.",
		examples = {Settings.Prefix.."setadmin euler", Settings.Prefix.."setadmin leibniz gauss"},
		func = setLevel(Settings.AdminPerm)})
	BindCommand({
		name = "setscribe",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."setscribe <name>...",
		brief = "Set the permission level of 1 or more players to scribe",
		help = "Set the permission level of 1 or more players to scribe. This will be overwritten on restart if their permission level is hardcoded.",
		examples = {Settings.Prefix.."setscribe euler", Settings.Prefix.."setscribe leibniz gauss"},
		func = setLevel(Settings.ScribePerm)})		
	BindCommand({
		name = "setguest",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."setguest <name>...",
		brief = "Set the permission level of 1 or more players to guest",
		help = "Set the permission level of 1 or more players to guest. This will be overwritten on restart if their permission level is hardcoded.",
		examples = {Settings.Prefix.."setscribe euler", Settings.Prefix.."setscribe leibniz gauss"},
		func = setLevel(Settings.DefaultPerm)})

	BindCommand({
		name = "setperm",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."setperm <name> <level>",
		brief = "Set a player's permission level",
		help = "Set a player's permission level. This will be overwritten on restart if their permission level is hardcoded.\nKey Permission Levels:\n<0 banned\n0 guest/default\n5 scribe\n10 admin",
		examples = {Settings.Prefix.."setperm gauss 5", Settings.Prefix.."setperm euler 57721"},
		func = function(speaker, args)
			if #args ~= 2 then
				SendMessageToClient({
					Text = "This command requires 2 arguments";
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
				return false
			end
			
			local userName = args[1]
			local userId = GetUserId(userName)
			local level = tonumber(args[2])
			
			if level == nil then
				SendMessageToClient({
					Text = "The second argument to this command must be an integer";
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
				return false
			end

			if userId then
				if Settings.Admins[userId] then
					SendMessageToClient({
						Text = "This player's permission level is hardcoded to the value "..Settings.Admins[userId]..". This change will be overwritten when the server restarts.";
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end

				SetPermLevel(userId, level)
                UpdatePerms(userId)

				SendMessageToClient({
					Text = userName.." given permission level "..level;
					ChatColor = Color3.new(0, 1, 0)
				}, speaker.Name)
			else
				SendMessageToClient({
					Text = "Unable to get User Id of player with name: "..userName;
					ChatColor = Color3.new(1, 0, 0)
				}, speaker.Name)
			end
		end
	})

	BindCommand({
		name = "getperm",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."getperm <name>",
		brief = "Get a player's permission level",
		help = "Get a player's permission level.\nKey Permission Levels:\n<0 banned\n0 guest/default\n5 scribe\n10 admin",
		examples = {Settings.Prefix.."setperm gauss", Settings.Prefix.."setperm euler leibniz"},
		func = function(speaker, args)
			
			if #args == 0 then
				SendMessageToClient({
					Text = "No arguments given";
					ChatColor = Color3.new(0, 1, 0)
				}, speaker.Name)
				return false
			end
			
			for _, name in ipairs(args) do
				
				local userId = GetUserId(name)
				
				if userId then

					local level = GetPermLevel(userId)

					SendMessageToClient({
						Text = name.." has permission level "..level;
						ChatColor = Color3.new(0, 1, 0)
					}, speaker.Name)
				else
					SendMessageToClient({
						Text = "Unable to get User Id of player with name: "..name;
						ChatColor = Color3.new(1, 0, 0)
					}, speaker.Name)
				end
			end
		end
	})

	local function sendHelp(speaker, args)
		SendMessageToClient({
			Text = getHelpMessage();
			ChatColor = Color3.new(1, 1, 1)
		}, speaker.Name)
	end

	BindCommand({
		name = "helpadmin",
		perm = Settings.AdminPerm,
		usage = Settings.Prefix.."help",
		brief = "Print this",
		help = getHelpMessage(),
		func = sendHelp})
end

-- These remote functions and events are invokved by client scripts
local function CreateRemotes()
    local adminCommonFolder = ReplicatedStorage:FindFirstChild("MetaAdmin")
    if not adminCommonFolder then
        adminCommonFolder = Instance.new("Folder")
        adminCommonFolder.Name = "MetaAdmin"
        adminCommonFolder.Parent = ReplicatedStorage
    end

    local remoteFunctionNames = {"GetPerm", "IsScribe", "IsAdmin", "IsBanned", "CanWrite"}

    for _, name in ipairs(remoteFunctionNames) do
        local newRF = Instance.new("RemoteFunction")
        newRF.Name = name
        newRF.Parent = adminCommonFolder
        remoteFunctions[name] = newRF
    end

    remoteFunctions["GetPerm"].OnServerInvoke = function(plr)
        return permissions[tostring(plr.UserId)]
    end

    remoteFunctions["IsScribe"].OnServerInvoke = function(plr)
        return isScribe(plr.UserId)
    end

    remoteFunctions["IsAdmin"].OnServerInvoke = function(plr)
        return isAdmin(plr.UserId)
    end

    remoteFunctions["IsBanned"].OnServerInvoke = function(plr)
        return isBanned(plr.UserId)
    end

    remoteFunctions["CanWrite"].OnServerInvoke = function(plr)
        return canWriteOnWhiteboards(plr.UserId)
    end

    local remoteEventNames = {"PermissionsUpdate"}
    
    for _, name in ipairs(remoteEventNames) do
        local newRE = Instance.new("RemoteEvent")
        newRE.Name = name
        newRE.Parent = adminCommonFolder
        remoteEvents[name] = newRE
    end
end

-- Binds all commands at once
function Run(ChatService)

	spawn(BindCommands) -- Bind all the commands

	LoadStoredInfo()

    -- Give admin rights to owners of private servers
    if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 then
        Settings.Admins[tostring(game.PrivateServerOwnerId)] = math.huge
    end

    -- Other code interacts with the permission system via remote functions and events
    CreateRemotes()

	local function ParseCommand(speakerName, message, channelName)
		local isCommand = message:match("^"..Settings.Prefix)
		-- Pattern that returns true if the prefix starts off the message
		if isCommand then
			local speaker = ChatService:GetSpeaker(speakerName) -- Requires the speaker module from the speaker module in the ChatServiceRunner
			local perms = GetPermLevelName(speakerName) -- Get speaker's permission level

			local messageWithoutPrefix = message:sub(#Settings.Prefix+1,#message) -- Get all characters after the prefix
			local command = nil -- The command the player is trying to execute (we haven't found that yet)
			local args = {} -- Table of arguments
			-- Arguments are words after the command
			-- So let's say the command was 
			-- ;fly jerry
			-- jerry would be the 1st argument
			for word in messageWithoutPrefix:gmatch("[%w%p]+") do
				-- Loops through a table of words inside of the message
				if command ~= nil then
					table.insert(args, word)
				else
					command = word:lower()
				end
			end
			-- Identify the command and get the arguments
			local properCommand = command:sub(1,1):upper() .. command:sub(2,#command):lower()
			-- This converts something like "fLy" into "Fly"
			if commands[command] then
				SendMessageToClient({
					Text = "> "..message;
					ChatColor = Color3.new(1, 1, 1)
				}, speakerName)

				-- Command exists
				local commandPerm = commands[command].perm
				if commandPerm > perms then
					-- Player does not have permission to use this command
					SendMessageToClient({
						Text = "You do not have access to this command";
						ChatColor = Color3.new(1, .5, 0)
					}, speakerName)
					return true
				else
					if message:find("?") then
						-- Player is asking how to use this command
						sendCommandHelp(speakerName, command:gsub("?", ""))
						return true
					end
					-- Player has access to the command
					if Settings.DebugMode then
						-- Only shows output of command when DebugMode is on
						-- I'd turn it on if you're creating new commands and need to test them
						local executed, response = pcall(function()
							return commands[command].func(PlayersService[speakerName], args)
						end)
						if executed then
							if response == false then
								SendMessageToClient({
									Text = "\"" .. command .. "\" failed";
									ChatColor = Color3.new(0, 1, 0)
								}, speakerName)
								sendCommandHelp(speakerName, command)
							else
								SendMessageToClient({
									Text = "\"" .. properCommand .. "\" ran without error";
									ChatColor = Color3.new(0, 1, 0)
								}, speakerName)
							end
							return true
						else
							SendMessageToClient({
								Text = "\"" .. command .. "\" failed";
								ChatColor = Color3.new(0, 1, 0)
							}, speakerName)
							sendCommandHelp(speakerName, command)
							return true
						end
					else
						-- DebugMode is disabled so we just execute the command
						local success, response = pcall(commands[command].func, PlayersService[speakerName], args)
						if success and (response ~= false) then
							return true
						else
							SendMessageToClient({
								Text = "\"" .. command .. "\" failed";
								ChatColor = Color3.new(0, 1, 0)
							}, speakerName)
							sendCommandHelp(speakerName, command)
							return true
						end
					end
				end
			elseif commands[command:gsub("?", "")] then
				SendMessageToClient({
					Text = "> "..message;
					ChatColor = Color3.new(1, 1, 1)
				}, speakerName)
				-- Player is asking how to use this command
				sendCommandHelp(speakerName, command:gsub("?", ""))
				return true
			else
				-- Command doesn't exist
				--SendMessageToClient({
				--	Text = "\"" .. properCommand .. "\" doesn't exist!";
				--	ChatColor = Color3.new(1, 0, 0)
				--}, speakerName)
				return false
			end
		end
		return false
	end

	ChatService:RegisterProcessCommandsFunction("cmd", ParseCommand)

	spawn(function() ChatService.SpeakerAdded:Connect(function(speakerName)
			if GetPermLevelName(speakerName) >= Settings.AdminPerm then
				wait(2)
				local speaker = ChatService:GetSpeaker(speakerName)
				speaker:SendSystemMessage("Chat '"..Settings.Prefix.."helpadmin' for admin commands\nUse /<command>? for more info about an admin command, e.g. /ban?", "All")
			end
		end) end)
end

return Run