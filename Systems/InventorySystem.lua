-- InventorySystem.lua
-- Server-side inventory and shop system

local InventorySystem = {}

local CONFIG = {
	MAX_INVENTORY_SLOTS = 20,
	START_MONEY = 100,
}

local Players = game:GetService("Players")

local SHOP_ITEMS = {
	{
		id = "iron_sword",
		name = "Iron Sword",
		price = 50,
		type = "weapon",
		damage = 15,
	},
	{
		id = "steel_sword",
		name = "Steel Sword",
		price = 100,
		type = "weapon",
		damage = 25,
	},
	{
		id = "health_potion",
		name = "Health Potion",
		price = 25,
		type = "consumable",
		health = 50,
	},
	{
		id = "mana_potion",
		name = "Mana Potion",
		price = 30,
		type = "consumable",
		mana = 50,
	},
}

local playerInventories = {}
local playerMoney = {}

local function initializeInventory(player)
	playerInventories[player.UserId] = {}
	playerMoney[player.UserId] = CONFIG.START_MONEY
end

local function addItemToInventory(playerId, itemId, quantity)
	quantity = quantity or 1
	if not playerInventories[playerId] then return false end
	
	local inventory = playerInventories[playerId]
	
	for _, item in ipairs(inventory) do
		if item.id == itemId then
			item.quantity = item.quantity + quantity
			return true
		end
	end
	
	if #inventory < CONFIG.MAX_INVENTORY_SLOTS then
		table.insert(inventory, {
			id = itemId,
			quantity = quantity,
		})
		return true
	end
	
	return false
end

local function removeItemFromInventory(playerId, itemId, quantity)
	quantity = quantity or 1
	if not playerInventories[playerId] then return false end
	
	local inventory = playerInventories[playerId]
	
	for index, item in ipairs(inventory) do
		if item.id == itemId then
			if item.quantity > quantity then
				item.quantity = item.quantity - quantity
				return true
			elseif item.quantity == quantity then
				table.remove(inventory, index)
				return true
			end
		end
	end
	
	return false
end

local function getItemDetails(itemId)
	for _, item in ipairs(SHOP_ITEMS) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

local function purchaseItem(playerId, itemId, quantity)
	quantity = quantity or 1
	local item = getItemDetails(itemId)
	
	if not item then return { success = false, message = "Item not found" } end
	
	local totalCost = item.price * quantity
	if playerMoney[playerId] < totalCost then
		return { success = false, message = "Insufficient funds" }
	end
	
	if not addItemToInventory(playerId, itemId, quantity) then
		return { success = false, message = "Inventory full" }
	end
	
	playerMoney[playerId] = playerMoney[playerId] - totalCost
	return { success = true, message = "Purchase successful", balance = playerMoney[playerId] }
end

local function sellItem(playerId, itemId, quantity)
	quantity = quantity or 1
	local item = getItemDetails(itemId)
	
	if not item then return { success = false, message = "Item not found" } end
	
	if not removeItemFromInventory(playerId, itemId, quantity) then
		return { success = false, message = "Not enough items" }
	end
	
	local sellValue = (item.price * 0.75) * quantity
	playerMoney[playerId] = playerMoney[playerId] + sellValue
	
	return { success = true, message = "Sold successfully", balance = playerMoney[playerId], earned = sellValue }
end

local function getInventory(playerId)
	return playerInventories[playerId] or {}
end

local function getBalance(playerId)
	return playerMoney[playerId] or 0
end

local function getShopItems()
	return SHOP_ITEMS
end

local purchaseRemote = Instance.new("RemoteEvent")
purchaseRemote.Name = "PurchaseItem"
purchaseRemote.Parent = game:GetService("ReplicatedStorage")

local sellRemote = Instance.new("RemoteEvent")
sellRemote.Name = "SellItem"
sellRemote.Parent = game:GetService("ReplicatedStorage")

local getInventoryRemote = Instance.new("RemoteFunction")
getInventoryRemote.Name = "GetInventory"
getInventoryRemote.Parent = game:GetService("ReplicatedStorage")

purchaseRemote.OnServerEvent:Connect(function(player, itemId, quantity)
	local result = purchaseItem(player.UserId, itemId, quantity)
	purchaseRemote:FireClient(player, result)
end)

sellRemote.OnServerEvent:Connect(function(player, itemId, quantity)
	local result = sellItem(player.UserId, itemId, quantity)
	sellRemote:FireClient(player, result)
end)

function getInventoryRemote.OnServerInvoke(player)
	return {
		inventory = getInventory(player.UserId),
		balance = getBalance(player.UserId),
		shop = getShopItems(),
	}
end

Players.PlayerAdded:Connect(function(player)
	initializeInventory(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerInventories[player.UserId] = nil
	playerMoney[player.UserId] = nil
end)

InventorySystem.purchaseItem = purchaseItem
InventorySystem.sellItem = sellItem
InventorySystem.addItemToInventory = addItemToInventory
InventorySystem.getInventory = getInventory
InventorySystem.getBalance = getBalance

return InventorySystem