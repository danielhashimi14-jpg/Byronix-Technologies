--[[
	BYRONIX — Require Scanner
	Real-time scanning for suspicious require(ID) calls,
	backdoor modules, and obfuscated require patterns.

	Detects:
	- require(NUMBER) with numeric asset IDs
	- Obfuscated patterns: local r=require; r(123)
	- String concatenation: require(tonumber("123".."456"))
	- getfenv/setfenv based require smuggling
	- Unknown ModuleScripts not in the original game tree
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local RequireScanner = {}

-- ═══════════════════════════════════════════
-- WHITELIST: Known safe module IDs and paths
-- ═══════════════════════════════════════════

-- Numeric IDs that are known to be safe (add your own game's module IDs here)
local WHITELISTED_IDS = {
	-- 123456789 = true,
}

-- Script paths that are allowed to use require(ID)
local WHITELISTED_PATHS = {
	["ServerScriptService.Superion"] = true,
	["ReplicatedStorage.Superion"] = true,
	["StarterPlayerScripts.Superion"] = true,
}

-- ═══════════════════════════════════════════
-- PATTERN DEFINITIONS
-- ═══════════════════════════════════════════

-- Patterns that indicate suspicious require behavior
local SUSPICIOUS_PATTERNS = {
	-- Direct numeric require: require(123456789)
	{ pattern = [[require%(%s*(%d+)%s*%)]], name = "DirectNumericRequire", severity = "HIGH" },

	-- Variable require: local r = require; r(123)
	{ pattern = [[require%s*;.*%(%s*(%d+)%s*%)]], name = "VariableRequire", severity = "HIGH" },

	-- Tonumber obfuscation: require(tonumber("123"))
	{ pattern = [[tonumber%s*%(%s*["'](%d+)]], name = "TonumberObfuscation", severity = "CRITICAL" },

	-- String concatenation: require(tonumber("123".."456"))
	{ pattern = [[%d+%s*%.%.%s*["']%d+]], name = "StringConcatObfuscation", severity = "CRITICAL" },

	-- getfenv smuggling: local r = getfenv().require
	{ pattern = [[getfenv%s*%(%s*%).*require]], name = "GetfenvRequire", severity = "CRITICAL" },

	-- setfenv smuggling
	{ pattern = [[setfenv%s*%(.+require]], name = "SetfenvRequire", severity = "CRITICAL" },

	-- Loadstring execution: loadstring(...require...)
	{ pattern = [[loadstring%s*%(.+require]], name = "LoadstringRequire", severity = "CRITICAL" },

	-- InsertService loading
	{ pattern = [[InsertService.*LoadAsset]], name = "InsertServiceLoad", severity = "HIGH" },

	-- HttpEnabled + require pattern (remote code execution)
	{ pattern = [[HttpEnabled%s*=%s*true]], name = "HttpEnabledManipulation", severity = "CRITICAL" },
}

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════

-- Track all scripts that existed at startup (baseline)
local baselineScripts = {}
local scannedScripts = {} -- scripts already scanned
local unknownModules = {} -- ModuleScripts not in baseline

-- ═══════════════════════════════════════════
-- SCANNING LOGIC
-- ═══════════════════════════════════════════

--- Build a baseline of all existing scripts at startup
function RequireScanner.BuildBaseline()
	baselineScripts = {}
	for _, descendant in game:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			baselineScripts[descendant] = true
			scannedScripts[descendant] = true
		end
	end
	Logger.Log(game:GetService("Players"):FindFirstChildOfClass("Player") or game,
		"RequireScanner",
		string.format("Baseline built: %d scripts registered", 
			#(function() local t = {} for k in baselineScripts do table.insert(t, k) end return t end)()
		),
		"BASELINE"
	)
end

--- Check if a script path is whitelisted
local function isPathWhitelisted(scriptInstance)
	local current = scriptInstance
	while current do
		local path = current:GetFullName()
		-- Remove "game." prefix
		path = path:gsub("^game%.", "")
		if WHITELISTED_PATHS[path] then
			return true
		end
		current = current.Parent
		if current == game then break end
	end
	return false
end

--- Scan a single script's source for suspicious patterns
function RequireScanner.ScanScript(scriptInstance)
	if not scriptInstance:IsA("BaseScript") and not scriptInstance:IsA("ModuleScript") then
		return {}
	end

	if isPathWhitelisted(scriptInstance) then
		return {}
	end

	local success, source = pcall(function()
		return scriptInstance.Source
	end)
	if not success or not source or source == "" then
		return {}
	end

	local findings = {}

	for _, patternDef in SUSPICIOUS_PATTERNS do
		local matches = {}
		for match in source:gmatch(patternDef.pattern) do
			table.insert(matches, match)
		end

		if #matches > 0 then
			for _, match in matches do
				-- Check if the numeric ID is whitelisted
				local numericId = tonumber(match)
				if numericId and WHITELISTED_IDS[numericId] then
					continue
				end

				table.insert(findings, {
					pattern = patternDef.name,
					severity = patternDef.severity,
					match = match,
					scriptPath = scriptInstance:GetFullName(),
				})
			end
		end
	end

	return findings
end

--- Scan all scripts in the game (full sweep)
function RequireScanner.ScanAll()
	local allFindings = {}
	local scriptCount = 0

	for _, descendant in game:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			scriptCount += 1
			local findings = RequireScanner.ScanScript(descendant)
			for _, finding in findings do
				table.insert(allFindings, finding)
			end
		end
	end

	return allFindings, scriptCount
end

--- Check for unknown ModuleScripts not in the baseline
function RequireScanner.ScanForUnknownModules()
	local unknown = {}

	for _, descendant in game:GetDescendants() do
		if descendant:IsA("ModuleScript") and not baselineScripts[descendant] then
			-- Skip Superion's own modules
			local path = descendant:GetFullName()
			if not path:find("Superion") then
				table.insert(unknown, {
					path = path,
					source = (function() local ok, src = pcall(function() return descendant.Source end); return ok and src or "<unreadable>" end)(),
				})
			end
		end
	end

	return unknown
end

--- Real-time scan: check a newly added script
function RequireScanner.OnDescendantAdded(descendant)
	if not (descendant:IsA("BaseScript") or descendant:IsA("ModuleScript")) then
		return
	end

	-- Skip if already scanned
	if scannedScripts[descendant] then return end
	scannedScripts[descendant] = true

	-- Check if this is an unknown module not in baseline
	if descendant:IsA("ModuleScript") and not baselineScripts[descendant] then
		local path = descendant:GetFullName()
		if not path:find("Superion") then
			Logger.Log(game:GetService("Players"):FindFirstChildOfClass("Player") or game,
				"RequireScanner",
				string.format("UNKNOWN ModuleScript detected: %s", path),
				Config.CODES.INTEGRITY
			)
			-- Store for reference
			unknownModules[descendant] = {
				path = path,
				addedAt = tick(),
			}
		end
	end

	-- Scan the source
	local findings = RequireScanner.ScanScript(descendant)
	for _, finding in findings do
		Logger.Log(game:GetService("Players"):FindFirstChildOfClass("Player") or game,
			"RequireScanner",
			string.format("%s [%s] in %s (match: %s)",
				finding.severity, finding.pattern, finding.scriptPath, finding.match
			),
			Config.CODES.INTEGRITY
		)
	end
end

--- Periodic real-time scan (called from ServerMain loop)
function RequireScanner.PeriodicScan()
	-- Scan for newly added scripts
	for _, descendant in game:GetDescendants() do
		if (descendant:IsA("BaseScript") or descendant:IsA("ModuleScript")) and not scannedScripts[descendant] then
			RequireScanner.OnDescendantAdded(descendant)
		end
	end

	-- Re-scan known scripts for source changes (exploiters may modify source)
	-- This catches cases where source is modified after initial scan
	for scriptInstance in baselineScripts do
		if scriptInstance and scriptInstance.Parent then
			local findings = RequireScanner.ScanScript(scriptInstance)
			for _, finding in findings do
				-- Only log if we haven't seen this exact finding before
				Logger.Log(game:GetService("Players"):FindFirstChildOfClass("Player") or game,
					"RequireScanner",
					string.format("RESCAN %s [%s] in %s (match: %s)",
						finding.severity, finding.pattern, finding.scriptPath, finding.match
				),
					Config.CODES.INTEGRITY
			)
			end
		end
	end
end

--- Get all unknown modules found
function RequireScanner.GetUnknownModules()
	return unknownModules
end

--- Add a module ID to the whitelist
function RequireScanner.WhitelistID(id)
	WHITELISTED_IDS[id] = true
end

--- Add a script path to the whitelist
function RequireScanner.WhitelistPath(path)
	WHITELISTED_PATHS[path] = true
end

return RequireScanner
