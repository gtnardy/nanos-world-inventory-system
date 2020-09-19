Events.on("SwitchedInventoryItem", function(slot) {
	let inventory_item = $(".inventory_item").eq(9 - slot);

	$(".inventory_item").removeClass("enabled");

	if (inventory_item)
		inventory_item.addClass("enabled");
});

Events.on("AddInventoryItem", function(slot, name, image) {
	let inventory_item = $(".inventory_item").eq(9 - slot);

	if (!inventory_item)
	{
		console.log(`Slot ${slot} not found!`);
		return;
	}

	inventory_item.find(".inventory_image").attr("src", "images/" + image);
	inventory_item.find(".inventory_slot").html(slot);
	inventory_item.find(".inventory_name").html(name);
	inventory_item.show();
});

Events.on("RemoveInventoryItem", function(slot) {
	let inventory_item = $(".inventory_item").eq(9 - slot);

	if (!inventory_item)
	{
		console.log(`Slot ${slot} not found!`);
		return;
	}

	inventory_item.removeClass("enabled");
	inventory_item.find(".inventory_image").attr("src", "");
	inventory_item.find(".inventory_slot").html("");
	inventory_item.find(".inventory_name").html("");
	inventory_item.hide();
});