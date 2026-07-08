--[[
	BYRONIX — Heartbeat Monitor
	Validates client heartbeats and detects missing/tampered signals.
	Uses token rotation for anti-replay protection.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local HeartbeatMonitor = {}

--- Handle incoming heartbeat from client
function HeartbeatMonitor.OnHeartbeatReceived(player, token)
	local data = PlayerData.Get(player)
	if not data then return end

	-- Validate the token if rotation is enabled
	if Config.HEARTBEAT_TOKEN_ROTATION then
		local expectedToken = PlayerData.GetHeartbeatToken(player)
		if token ~= expectedToken then
			local code = Config.CODES.HEARTBEAT
			Logger.Log(player, "Heartbeat", string.format(
				"Invalid token received (expected: %s, got: %s)",
				expectedToken:sub(1, 8) .. "...", token:sub(1, 8) .. "..."
			), code)
			PlayerData.AddViolation(player, "Heartbeat")
			Punisher.Punish(player, "Heartbeat", code)
			return
		end
	end

	-- Reset the heartbeat timer
	PlayerData.ResetHeartbeat(player)

	-- Generate and send new token for next heartbeat
	if Config.HEARTBEAT_TOKEN_ROTATION then
		local newToken = Shared.GenerateToken()
		PlayerData.SetHeartbeatToken(player, newToken)

		local eventsFolder = game.ReplicatedStorage:FindFirstChild("Superion")
			and game.ReplicatedStorage.Superion:FindFirstChild("Events")
		if eventsFolder then
			local serverCommand = eventsFolder:FindFirstChild("ServerCommand")
			if serverCommand then
				serverCommand:FireClient(player, "NewToken", newToken)
			end
		end
	end
end

--- Check if any player has missed heartbeats (called from main loop)
function HeartbeatMonitor.Check()
	if not Config.HEARTBEAT_ENABLED then return end

	local Players = game:GetService("Players")
	local now = tick()

	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data and data.isMonitored then
			local elapsed = now - data.lastHeartbeat

			if elapsed > Config.HEARTBEAT_TIMEOUT then
				data.missedHeartbeats += 1
				local code = Config.CODES.HEARTBEAT
				Logger.Log(player, "Heartbeat", string.format(
					"No heartbeat for %.1fs (timeout: %ds)",
					elapsed, Config.HEARTBEAT_TIMEOUT
				), code)
				PlayerData.AddViolation(player, "Heartbeat")
				Punisher.Punish(player, "Heartbeat", code)

				-- Reset timer to avoid spamming violations
				data.lastHeartbeat = now
			end
		end
	end
end

--- Initialize heartbeat for a new player
function HeartbeatMonitor.InitPlayer(player)
	local token = Shared.GenerateToken()
	PlayerData.SetHeartbeatToken(player, token)

	-- Send initial token to client
	local eventsFolder = game.ReplicatedStorage:FindFirstChild("Superion")
		and game.ReplicatedStorage.Superion:FindFirstChild("Events")
	if eventsFolder then
		local serverCommand = eventsFolder:FindFirstChild("ServerCommand")
		if serverCommand then
			-- Small delay to ensure client is ready
			task.delay(2, function()
				if player.Parent then
					serverCommand:FireClient(player, "InitToken", token)
				end
			end)
		end
	end
end

return HeartbeatMonitor
