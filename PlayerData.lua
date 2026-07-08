--[[
	BYRONIX — PlayerData Module
	Tracks per-player state for all detectors.
]]

local Players = game:GetService("Players")

local PlayerData = {}

local store = {} -- [UserId] = data table

--- Initialize tracking data for a player
function PlayerData.Init(player)
	store[player.UserId] = {
		-- Position tracking
		lastPosition = nil,
		lastCheckTime = tick(),

		-- Fly detection
		airborneTime = 0,
		wasOnGround = true,

		-- Noclip detection
		noclipCounter = 0,

		-- Heartbeat
		lastHeartbeat = tick(),
		heartbeatToken = "",
		missedHeartbeats = 0,

		-- Violations
		violations = {},

		-- Rate limiting
		remoteCalls = {}, -- [remoteName] = {timestamps}

		-- Client integrity
		lastIntegrityReport = tick(),

		-- General
		isMonitored = true,
		joinedAt = tick(),
	}
end

--- Get data for a player
function PlayerData.Get(player)
	return store[player.UserId]
end

--- Clean up data when a player leaves
function PlayerData.Cleanup(player)
	store[player.UserId] = nil
end

--- Add a violation for a player
function PlayerData.AddViolation(player, detectionType)
	local data = store[player.UserId]
	if not data then return 0 end

	if not data.violations[detectionType] then
		data.violations[detectionType] = 0
	end
	data.violations[detectionType] += 1
	return data.violations[detectionType]
end

--- Get total violations for a player
function PlayerData.GetTotalViolations(player)
	local data = store[player.UserId]
	if not data then return 0 end

	local total = 0
	for _, count in data.violations do
		total += count
	end
	return total
end

--- Check rate limit for a remote
function PlayerData.CheckRateLimit(player, remoteName, maxCalls, window)
	local data = store[player.UserId]
	if not data then return false end

	if not data.remoteCalls[remoteName] then
		data.remoteCalls[remoteName] = {}
	end

	local calls = data.remoteCalls[remoteName]
	local now = tick()

	-- Prune old entries
	for i = #calls, 1, -1 do
		if now - calls[i] > window then
			table.remove(calls, i)
		end
	end

	-- Check if over limit
	if #calls >= maxCalls then
		return true -- rate limited!
	end

	-- Record this call
	table.insert(calls, now)
	return false
end

--- Reset heartbeat timer
function PlayerData.ResetHeartbeat(player)
	local data = store[player.UserId]
	if data then
		data.lastHeartbeat = tick()
		data.missedHeartbeats = 0
	end
end

--- Set heartbeat token
function PlayerData.SetHeartbeatToken(player, token)
	local data = store[player.UserId]
	if data then
		data.heartbeatToken = token
	end
end

--- Get heartbeat token
function PlayerData.GetHeartbeatToken(player)
	local data = store[player.UserId]
	if data then
		return data.heartbeatToken
	end
	return ""
end

return PlayerData
