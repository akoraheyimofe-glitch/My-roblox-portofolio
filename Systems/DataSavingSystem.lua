-- DataSavingSystem.lua
-- Player data persistence with clean data flow

local DataSavingSystem = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local CONFIG = {
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY = 1,
	AUTO_SAVE_INTERVAL = 60,
}

local playerDataStore = DataStoreService:GetDataStore("PlayerData")
local playerStatsStore = DataStoreService:GetDataStore("PlayerStats")

local playerDataCache = {}
local autoSaveConnections = {}

local function getPlayerData(playerId)
	if playerDataCache[playerId] then
		return playerDataCache[playerId]
	end
	
	local data = {
		playerId = playerId,
		joinedAt = os.time(),
		level = 1,
		experience = 0,
		balance = 100,
		inventory = {},
		quests = {},
		settings = {
			volume = 0.5,
			brightness = 1.0,
		},
	}
	
	return data
end

local function loadPlayerData(playerId)
	local attempts = 0
	local data
	local success = false
	
	while attempts < CONFIG.RETRY_ATTEMPTS and not success do
		attempts = attempts + 1
		pcall(function()
			data = playerDataStore:GetAsync("Player_" .. playerId)
			success = true
		end)
		
		if not success and attempts < CONFIG.RETRY_ATTEMPTS then
			wait(CONFIG.RETRY_DELAY)
		end
	end
	
	if not success or not data then
		data = getPlayerData(playerId)
	end
	
	playerDataCache[playerId] = data
	return data
end

local function savePlayerData(playerId)
	if not playerDataCache[playerId] then return false end
	
	local data = playerDataCache[playerId]
	local attempts = 0
	local success = false
	
	while attempts < CONFIG.RETRY_ATTEMPTS and not success do
		attempts = attempts + 1
		pcall(function()
			playerDataStore:SetAsync("Player_" .. playerId, data)
			success = true
		end)
		
		if not success and attempts < CONFIG.RETRY_ATTEMPTS then
			wait(CONFIG.RETRY_DELAY)
		end
	end
	
	return success
end

local function updateStat(playerId, statName, value)
	local data = playerDataCache[playerId]
	if not data then return false end
	
	data[statName] = value
	return true
end

local function incrementStat(playerId, statName, amount)
	local data = playerDataCache[playerId]
	if not data then return false end
	
	if type(data[statName]) == "number" then
		data[statName] = data[statName] + amount
		return true
	end
	
	return false
end

local function addInventoryItem(playerId, itemId, quantity)
	local data = playerDataCache[playerId]
	if not data then return false end
	
	for _, item in ipairs(data.inventory) do
		if item.id == itemId then
			item.quantity = item.quantity + quantity
			return true
		end
	end
	
	table.insert(data.inventory, { id = itemId, quantity = quantity })
	return true
end

local function startAutoSave(playerId)
	if autoSaveConnections[playerId] then return end
	
	autoSaveConnections[playerId] = game:GetService("RunService").Heartbeat:Connect(function()
		wait(CONFIG.AUTO_SAVE_INTERVAL)
		savePlayerData(playerId)
	end)
end

local function stopAutoSave(playerId)
	if autoSaveConnections[playerId] then
		autoSaveConnections[playerId]:Disconnect()
		autoSaveConnections[playerId] = nil
	end
end

local getDataRemote = Instance.new("RemoteFunction")
getDataRemote.Name = "GetPlayerData"
getDataRemote.Parent = game:GetService("ReplicatedStorage")

local updateDataRemote = Instance.new("RemoteEvent")
updateDataRemote.Name = "UpdatePlayerData"
updateDataRemote.Parent = game:GetService("ReplicatedStorage")

function getDataRemote.OnServerInvoke(player)
	return playerDataCache[player.UserId]
end

updateDataRemote.OnServerEvent:Connect(function(player, statName, value)
	updateStat(player.UserId, statName, value)
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player.UserId)
	startAutoSave(player.UserId)
	print("[DataSavingSystem] Loaded data for player: " .. player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player.UserId)
	stopAutoSave(player.UserId)
	playerDataCache[player.UserId] = nil
	print("[DataSavingSystem] Saved data for player: " .. player.Name)
end)

DataSavingSystem.loadPlayerData = loadPlayerData
DataSavingSystem.savePlayerData = savePlayerData
DataSavingSystem.updateStat = updateStat
DataSavingSystem.incrementStat = incrementStat
DataSavingSystem.addInventoryItem = addInventoryItem
DataSavingSystem.getPlayerData = function(playerId) return playerDataCache[playerId] end

return DataSavingSystem