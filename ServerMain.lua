--[[
	╔══════════════════════════════════════════╗
	║         BYRONIX ANTI-CHEAT              ║
	║         Server Main Controller            ║
	║         Version: 2.0.0                   ║
	╚══════════════════════════════════════════╝

	This is the central server script that orchestrates all
	detection modules, handles player connections, and runs
	the main detection loop.
]]

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ═══════════════════════════════════════════
-- MODULES
-- ═══════════════════════════════════════════

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)
local SpeedDetector = require(script.Parent.SpeedDetector)
local FlyDetector = require(script.Parent.FlyDetector)
local TeleportDetector = require(script.Parent.TeleportDetector)
local PropertyDetector = require(script.Parent.PropertyDetector)
local NoclipDetector = require(script.Parent.NoclipDetector)
local HeartbeatMonitor = require(script.Parent.HeartbeatMonitor)
-- RemoteValidator removed (was too aggressive)
local RequireScanner = require(script.Parent.RequireScanner)

-- ═══════════════════════════════════════════
-- REMOTE REFERENCES
-- ═══════════════════════════════════════════

local Events = game.ReplicatedStorage.Superion.Events
local HeartbeatRemote = Events.Heartbeat
local ClientReportRemote = Events.ClientReport
local ServerCommandRemote = Events.ServerCommand

-- ═══════════════════════════════════════════
-- PLAYER HANDLING
-- ═══════════════════════════════════════════

local function onPlayerAdded(player)
	-- Check admin bypass
	if Shared.ShouldBypass(player, Config) then
		Logger.Log(player, "System", "Admin/Owner bypass active", "BYPASS")
		return
	end

	-- Initialize player data
	PlayerData.Init(player)

	-- Setup heartbeat
	HeartbeatMonitor.InitPlayer(player)

	-- Wait for character to load
	player.CharacterAdded:Connect(function(character)
		local data = PlayerData.Get(player)
		if data then
			data.lastPosition = nil
			data.airborneTime = 0
			data.noclipCounter = 0
			data.lastCheckTime = tick()
		end
	end)

	Logger.Log(player, "System", "Player monitoring initialized", "INIT")
end

local function onPlayerRemoving(player)
	PlayerData.Cleanup(player)
end

-- ═══════════════════════════════════════════
-- REMOTE EVENT HANDLERS
-- ═══════════════════════════════════════════

-- Heartbeat from client
HeartbeatRemote.OnServerEvent:Connect(function(player, token)
	if Shared.ShouldBypass(player, Config) then return end
	HeartbeatMonitor.OnHeartbeatReceived(player, token)
end)

-- Client-side detection reports
ClientReportRemote.OnServerEvent:Connect(function(player, detectionType, detail)
	if Shared.ShouldBypass(player, Config) then return end

	-- RemoteValidator removed - basic validation only
	if typeof(detectionType) ~= "string" or typeof(detail) ~= "string" then return end

	local code = Config.CODES.CLIENT
	Logger.Log(player, "ClientReport", string.format(
		"Client reported: %s - %s", detectionType, detail
	), code)
	PlayerData.AddViolation(player, "Client")
	Punisher.Punish(player, "Client", code)
end)

-- ═══════════════════════════════════════════
-- MAIN DETECTION LOOP
-- ═══════════════════════════════════════════

local scanCounter = 0
local REQUIRE_SCAN_INTERVAL = 30 -- Scan for require patterns every 30s

local function mainLoop()
	while task.wait(Config.LOOP_INTERVAL) do
		for _, player in Players:GetPlayers() do
			if Shared.ShouldBypass(player, Config) then continue end

			local data = PlayerData.Get(player)
			if not data or not data.isMonitored then continue end

			-- Run all detectors
			SpeedDetector.Check(player)
			FlyDetector.Check(player)
			TeleportDetector.Check(player)
			PropertyDetector.Check(player)
			NoclipDetector.Check(player)

			-- Update check time
			data.lastCheckTime = tick()
		end

		-- Heartbeat check (doesn't need per-player loop, handles internally)
		HeartbeatMonitor.Check()

		-- Periodic require scanning
		scanCounter += 1
		if scanCounter >= (REQUIRE_SCAN_INTERVAL / Config.LOOP_INTERVAL) then
			scanCounter = 0
			RequireScanner.PeriodicScan()
		end
	end
end

-- ═══════════════════════════════════════════
-- DESCENDANT ADDED MONITORING
-- ═══════════════════════════════════════════

game.DescendantAdded:Connect(function(descendant)
	RequireScanner.OnDescendantAdded(descendant)
end)

-- ═══════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════

local function initialize()
	print("[Superion] Initializing v" .. Shared.VERSION .. "...")

	-- Build script baseline for require scanning
	RequireScanner.BuildBaseline()

	-- RemoteValidator removed - skipping remote hooking
	print("[Superion] RemoteValidator disabled (removed for stability)")

	-- Run initial full scan
	local findings, scriptCount = RequireScanner.ScanAll()
	if #findings > 0 then
		print(string.format("[Superion] WARNING: %d suspicious patterns found in %d scripts!", #findings, scriptCount))
		for _, finding in findings do
			print(string.format("  [%s] %s in %s (match: %s)",
				finding.severity, finding.pattern, finding.scriptPath, finding.match))
		end
	else
		print(string.format("[Superion/B] Initial scan clean (%d scripts checked)", scriptCount))
	end

	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in the game
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Start main detection loop
	print("[Superion] All detectors active. Monitoring started.")
	task.spawn(mainLoop)
end

initialize()
