--[[
	BYRONIX — Logger Module
	Centralized logging for all detections and events.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)

local Logger = {}

local logStore = {} -- {playerName = {entries}}

--- Log a detection event
function Logger.Log(player, detectionType, detail, code)
	local entry = Shared.FormatLog(player, detectionType, detail, code)

	-- Store in memory
	if not logStore[player.Name] then
		logStore[player.Name] = {}
	end
	table.insert(logStore[player.Name], {
		time = tick(),
		entry = entry,
		type = detectionType,
		code = code,
	})

	-- Prune old entries
	local now = tick()
	for name, entries in logStore do
		for i = #entries, 1, -1 do
			if now - entries[i].time > Config.LOG_RETENTION then
				table.remove(entries, i)
			end
		end
		if #entries == 0 then
			logStore[name] = nil
		end
	end

	-- Print to output if verbose
	if Config.VERBOSE_LOGGING then
		print(entry)
	end

	-- Store in ServerStorage if configured
	if Config.LOG_TO_STORAGE then
		local storage = game:GetService("ServerStorage"):FindFirstChild("SuperionLogs")
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = "SuperionLogs"
			storage.Parent = game:GetService("ServerStorage")
		end
		local logValue = Instance.new("StringValue")
		logValue.Value = entry
		logValue.Parent = storage
		game:GetService("Debris"):AddItem(logValue, Config.LOG_RETENTION)
	end
end

--- Get all logs for a specific player
function Logger.GetLogs(playerName)
	return logStore[playerName] or {}
end

--- Get all logs
function Logger.GetAllLogs()
	return logStore
end

--- Get violation count for a player by detection type
function Logger.GetViolationCount(playerName, detectionType)
	local entries = logStore[playerName] or {}
	local count = 0
	for _, entry in entries do
		if entry.type == detectionType then
			count += 1
		end
	end
	return count
end

--- Get total violation count for a player
function Logger.GetTotalViolations(playerName)
	return #(logStore[playerName] or {})
end

return Logger
