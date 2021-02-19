-- Stores the UI Instance
WeaponHUD = nil

-- Stores when the UI is ready
IsUIReady = false

-- Stores when the LocalPlayer is ready
IsLocalPlayerReady = false

-- Stores all keys used for inventory shortcut
InventoryKeyBinding = {
	["One"] = 1,
	["Two"] = 2,
	["Three"] = 3,
	["Four"] = 4,
	["Five"] = 5,
	["Six"] = 6,
	["Seven"] = 7,
	["Eight"] = 8,
	["Nine"] = 9,
	["Zero"] = 0,
}

-- When package loads, verify if LocalPlayer already exists (eg. when reloading the package), then try to get and store it's controlled character
Package:Subscribe("Load", function()
	-- Creates a WebUI for the Inventory
	WeaponHUD = WebUI("InventoryHUD", "file:///UI/index.html")

	WeaponHUD:Subscribe("Ready", function()
		IsUIReady = true
		SetupUI()
	end)
end)

Package:Subscribe("Unload", function()
	WeaponHUD:Destroy()
end)

-- Catches KeyUp event to see if it was pressed any Inventory Shortcut key
Client:Subscribe("KeyUp", function(KeyName)
	local slot = -1

	if (InventoryKeyBinding[KeyName]) then
		slot = InventoryKeyBinding[KeyName]
	end

	-- If pressed any shortcut key
	if (slot ~= -1) then
		local inventory = NanosWorld:GetLocalPlayer():GetValue("Inventory") or {}

		-- Verifies if I have any item in the index of that inventory or if I pressed 0 (means remove all items from hand), then send 'SwitchInventoryItem' to server to switch my current item
		if (inventory[slot] or slot == 0) then
			Events:CallRemote("SwitchInventoryItem", {slot})
		end
	end
end)

Events:Subscribe("SwitchedInventoryItem", function(slot)
	WeaponHUD:CallEvent("SwitchedInventoryItem", {slot})
end)

-- When LocalPlayer spawns, sets an event on it to trigger when we possesses a new character, to store the local controlled character locally. This event is only called once, see Package:Subscribe("Load") to load it when reloading a package
NanosWorld:Subscribe("SpawnLocalPlayer", function(local_player)
	IsLocalPlayerReady = true
	SetupUI()
end)

-- Receives a new item on the inventory
Events:Subscribe("GiveInventoryItem", function(inventory_item_id)
	-- Gets if the item exists item from InventoryItems list
	local InventoryItem = InventoryItems[inventory_item_id]

	-- Gets my inventory, sets the item at the slot and saves it again
	local inventory = NanosWorld:GetLocalPlayer():GetValue("Inventory") or {}
	inventory[InventoryItem.slot] = {id = inventory_item_id}
	NanosWorld:GetLocalPlayer():SetValue("Inventory", inventory)

	-- Calls HUD to add this item to the screen
	if (WeaponHUD) then
		WeaponHUD:CallEvent("AddInventoryItem", {InventoryItem.slot, InventoryItem.name, InventoryItem.image})
	end
end)

-- Removes the item from inventory (called from server)
Events:Subscribe("RemoveInventoryItem", function(slot)
	-- Gets my inventory, sets the item at slot to nil and saves it again
	local inventory = NanosWorld:GetLocalPlayer():GetValue("Inventory") or {}
	inventory[slot] = nil
	NanosWorld:GetLocalPlayer():SetValue("Inventory", inventory)

	-- Calls HUD to remove it from screen
	if (WeaponHUD) then
		WeaponHUD:CallEvent("RemoveInventoryItem", {slot})
	end
end)

-- Function to Setup the UI when everything is ready (WebUI and LocalPlayer)
function SetupUI()
	if (not IsUIReady or not IsLocalPlayerReady) then return end

	-- Updates the UI with the already saved Inventory (in case of the Package is being reloaded)
	local inventory = NanosWorld:GetLocalPlayer():GetValue("Inventory")
	if (inventory) then
		for slot, data in pairs(inventory) do
			WeaponHUD:CallEvent("AddInventoryItem", {slot, InventoryItems[data.id].name, InventoryItems[data.id].image})
		end
	end

	Events:CallRemote("RemotePlayerReady", {})
end