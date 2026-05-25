-- CombatSystem.lua
-- Server-side combat system with validation, hit detection, and effects

local CombatSystem = {}

-- CONFIGURATION
local CONFIG = {
	HIT_DISTANCE = 50,
	HIT_RATE = 0.1,
	BASE_DAMAGE = 25,
	CRITICAL_CHANCE = 0.2,
	CRITICAL_MULTIPLIER = 1.5,
	DEFAULT_KNOCKBACK = 50,
	EFFECT_DURATION = 0.5,
}

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local playerCombatState = {}

local function initializePlayerCombat(player, character)
	if not playerCombatState[player.UserId] then
		playerCombatState[player.UserId] = {
			lastHitTime = {},
			isAttacking = false,
			currentWeapon = nil,
		}
	end
end

local function validateHit(attacker, target, weaponName)
	if not attacker or not target then return false end
	if not attacker:FindFirstChild("Humanoid") or not target:FindFirstChild("Humanoid") then
		return false
	end
	
	local attackerPos = attacker:FindFirstChild("HumanoidRootPart").Position
	local targetPos = target:FindFirstChild("HumanoidRootPart").Position
	local distance = (attackerPos - targetPos).Magnitude
	
	if distance > CONFIG.HIT_DISTANCE then
		return false
	end
	
	return true
end

local function calculateDamage(baseAttack, defenseTarget)
	local damage = CONFIG.BASE_DAMAGE + (baseAttack or 0)
	local isCritical = math.random() < CONFIG.CRITICAL_CHANCE
	
	if isCritical then
		damage = damage * CONFIG.CRITICAL_MULTIPLIER
	end
	
	return damage, isCritical
end

local function applyDamage(attacker, target, damage, isCritical, weaponName)
	local humanoid = target:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
		
		local humanoidRootPart = target:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local attackerPos = attacker:FindFirstChild("HumanoidRootPart").Position
			local direction = (humanoidRootPart.Position - attackerPos).Unit
			humanoidRootPart.AssemblyLinearVelocity = direction * CONFIG.DEFAULT_KNOCKBACK
		end
	end
end

local function processHit(attacker, target, weaponName, baseDamage)
	if not validateHit(attacker, target, weaponName) then
		return { success = false, message = "Invalid hit" }
	end
	
	local attackerUserId = Players:GetUserIdFromCharacter(attacker)
	if not attackerUserId then return { success = false } end
	
	local lastHitTime = playerCombatState[attackerUserId].lastHitTime[target] or 0
	local currentTime = tick()
	
	if currentTime - lastHitTime < CONFIG.HIT_RATE then
		return { success = false, message = "Hit cooldown active" }
	end
	
	local damage, isCritical = calculateDamage(baseDamage, 0)
	applyDamage(attacker, target, damage, isCritical, weaponName)
	
	playerCombatState[attackerUserId].lastHitTime[target] = currentTime
	
	return { success = true, damage = damage, isCritical = isCritical }
end

local hitRemote = Instance.new("RemoteEvent")
hitRemote.Name = "CombatHit"
hitRemote.Parent = game:GetService("ReplicatedStorage")

hitRemote.OnServerEvent:Connect(function(player, targetCharacter, weaponName, baseDamage)
	if player.Character then
		local result = processHit(player.Character, targetCharacter, weaponName, baseDamage or CONFIG.BASE_DAMAGE)
		hitRemote:FireClient(player, result)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		initializePlayerCombat(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerCombatState[player.UserId] = nil
end)

CombatSystem.processHit = processHit
CombatSystem.validateHit = validateHit

return CombatSystem