Package:RequirePackage("NanosWorldWeapons")


-- Triggers when the Character drops the holding Item
Character:on("Drop", function(character, object, was_triggered_by_player)
	-- If it was not the player which dropped intentionally (e.g. pressing G), then probably it was 'dropped' because he's switching the inventory item
	if (not was_triggered_by_player) then
		-- Destroys the item to simulate it being stored in the inventory
		if (object:IsValid() and not object:GetValue("IsBeingSwitched")) then
			object:Destroy()
		end
		return
	end

	-- Gets the current holding item and removes it from the Inventory
	local player = character:GetPlayer()
	local current_inventory_item_slot = player:GetValue("CurrentInventoryItemSlot")
	if (current_inventory_item_slot) then
		RemoveInventoryItem(player, current_inventory_item_slot, true)
		player:SetValue("CurrentInventoryItemSlot", nil)
	end
end)

-- Triggers when a character tries to 'PickUp' any Weapon/Item/Granade
Character:on("Interact", function(character, object)
	-- Gets the AssetName (a.k.a. Item Key/ID)
	local AssetName = object:GetAssetName()

	-- Checks if it does exists any InventoryItem with that ID
	local inventory_item = InventoryItems[AssetName]
	if (not inventory_item) then
		return
	end

	local data = nil
	if (object:GetType() == "Weapon") then
		data = {ammo_bag = object:GetAmmoBag(), ammo_clip = object:GetAmmoClip()}
	end

	local inventory = character:GetPlayer():GetValue("Inventory") or {}
	local current_inventory_item_slot = character:GetPlayer():GetValue("CurrentInventoryItemSlot")

	-- If the character is holding an Item which uses the same slot as the one he's trying to pickup, drops it and picks up the interacted one
	if (current_inventory_item_slot == inventory_item.slot) then
		character:Drop()
		character:PickUp(object)
	else
		-- If the player already contains an Item at the inventory with that Slot, then 'spawns' a new Item to simulate it is changing the Item holded
		if (inventory[inventory_item.slot]) then
			local new_inventory_item = SpawnInventoryItem(inventory[inventory_item.slot], character:GetLocation() + Vector(0, 0, 100))
		end

		-- Destroys the Item interacted (to simulate it was grabbed)
		object:Destroy()
	end

	-- Adds the entry at the player's inventory of this new Item
	GiveInventoryItem(character:GetPlayer(), AssetName, data)

	-- Returns false to forbid the character from picking up this
	return false
end)

-- Triggers when the Character actively picks up a new Item from the ground or when a new item is given to him
Character:on("PickUp", function(character, object)
	-- Gets the AssetName (a.k.a. Item Key/ID) and checks if it does exists any InventoryItem with that ID
	local inventory_item = InventoryItems[object:GetAssetName()]
	if (not inventory_item) then
		return
	end

	local inventory = character:GetPlayer():GetValue("Inventory") or {}

	-- Updates the current item grabbed
	character:GetPlayer():SetValue("CurrentInventoryItemSlot", inventory_item.slot)

	-- Gives the item to the player and calls remote to update it on the client
	local data = nil
	if (object:GetType() == "Weapon") then
		data = {ammo_bag = object:GetAmmoBag(), ammo_clip = object:GetAmmoClip()}
	end

	GiveInventoryItem(character:GetPlayer(), object:GetAssetName(), data)
	Events:CallRemote("SwitchedInventoryItem", character:GetPlayer(), {inventory_item.slot})

	-- Checks if this item is currently being "switched"
	local is_being_switched = object:GetValue("IsBeingSwitched")
	if (is_being_switched) then
		object:SetValue("IsBeingSwitched", nil)
		return
	end

	-- If there was an item with that same slot id already in the inventory, then just 'drops' it by spawning it
	if (inventory[inventory_item.slot]) then
		local new_inventory_item = SpawnInventoryItem(inventory[inventory_item.slot], character:GetLocation() + Vector(0, 0, 100))
	end
end)

function SpawnInventoryItem(inventory_item, pos)
	local inventory_item_data = InventoryItems[inventory_item.id]
	local new_inventory_item = inventory_item_data.spawn(pos)

	-- If this is a Weapon
	if (inventory_item_data.type == InventoryTypes.Weapon) then
		new_inventory_item:SetAmmoBag(inventory_item.data.ammo_bag)
		new_inventory_item:SetAmmoClip(inventory_item.data.ammo_clip)
	end

	return new_inventory_item
end

-- Gives an Item at given slot to a player
function GiveInventoryItem(player, inventory_item_key, custom_data)
	-- Gets the Item data given it's ID/Key
	local inventory_item = InventoryItems[inventory_item_key]

	-- Gets the Inventory and sets at the Item's slot, the data of this Item, and saves it
	local inventory = player:GetValue("Inventory") or {}
	inventory[inventory_item.slot] = {id = inventory_item_key, data = custom_data or inventory_item.default_data}
	player:SetValue("Inventory", inventory)

	-- Calls remote to update it on the client
	Events:CallRemote("GiveInventoryItem", player, {inventory_item_key})
end

-- Removes an Item at given slot from a player
function RemoveInventoryItem(player, slot, keep_if_holding)
	-- Gets the player's Inventory and sets the item at index 'slot' to nil, and saves it again
	local inventory = player:GetValue("Inventory") or {}
	inventory[slot] = nil
	player:SetValue("Inventory", inventory)

	-- Custom parameter for custom calls, when the scripter wants to Drop the Item if he's holding it
	if (not keep_if_holding) then
		local current_inventory_item_slot = player:GetValue("CurrentInventoryItemSlot")
		if (current_inventory_item_slot == slot) then
			player:GetControlledCharacter():Drop()
		end
	end

	-- Calls remote to update it on the client
	Events:CallRemote("RemoveInventoryItem", player, {slot})
end

-- Called from remote when a Player wants to switch it's inventory item
Events:on("SwitchInventoryItem", function(player, inventory_slot)
	local current_inventory_item_slot = player:GetValue("CurrentInventoryItemSlot")

	-- If the player is already with that item in hands, does nothing
	if (current_inventory_item_slot == inventory_slot) then return end

	local inventory = player:GetValue("Inventory") or {}
	local current_inventory_item = player:GetControlledCharacter():GetPicked()

	if (current_inventory_item and current_inventory_item:IsValid()) then
		-- If the item is a weapon, then save the Weapon's ammo in the Inventory Item's data
		if (current_inventory_item:GetType() == "Weapon") then
			inventory[current_inventory_item_slot].data.ammo_bag = current_inventory_item:GetAmmoBag()
			inventory[current_inventory_item_slot].data.ammo_clip = current_inventory_item:GetAmmoClip()

			player:SetValue("Inventory", inventory)
		end
	end

	-- If the slot wanted to be switched to is 0, means he wants to clear his hands
	if (inventory_slot == 0) then
		-- Destroys the item simulating it was stored back in the inventory
		if (current_inventory_item and current_inventory_item:IsValid()) then
			current_inventory_item:SetValue("IsBeingSwitched", true)
			current_inventory_item:Destroy()
		end

		-- Sets the current item as nil
		player:SetValue("CurrentInventoryItemSlot", nil)

	-- If the wanted slot contains an item in the player's inventory...
	elseif (inventory[inventory_slot]) then

		-- Gets and spawns the Item data given the current inventory item ID at the wanted slot position
		local new_inventory_item = SpawnInventoryItem(inventory[inventory_slot], player:GetControlledCharacter():GetLocation())

		-- Makes the character to pick up it
		new_inventory_item:SetValue("IsBeingSwitched", true)
		player:GetControlledCharacter():PickUp(new_inventory_item)
	end
end)