local player_inventory = {}

function player_inventory.new()
	local self = setmetatable({
		items = {},
		cards = {},
		gold = 0
	}, player_inventory)
	return self;
end

function player_inventory:addItem(item)
	table.insert(self.items, item)
end

function player_inventory:addCard(card)
	table.insert(self.cards, card)
end

function player_inventory:getItems()
	return self.items
end

function player_inventory:getCards()
	return self.cards
end

function player_inventory:getGold()
	return self.gold
end

function player_inventory:setGold(gold)
	self.gold = self.gold + gold
end

function player_inventory:sellItem(item)
	for i, v in ipairs(self.items) do
		if v.name == item.name then
			table.remove(self.items, i)
			self.gold = self.gold + v.price
			return true
		end
	end
	return false
end

function player_inventory:sellCard(card)
	for i, v in ipairs(self.cards) do
		if v.name == card.name then
			table.remove(self.cards, i)
			self.gold = self.gold + v.price
			return true
		end
	end
	return false
end

return player_inventory;
