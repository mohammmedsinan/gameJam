local CrTv = require("src/ui/CrTv");
local json = require("src/utils/json");

local Player = {}
Player.__index = Player

function Player.new(bus, cardHand)
	return setmetatable({
		name = "player",
		bus = bus,
		cardHand = cardHand,
		width = 70,
		height = 70,
		health = 10,
		maxHealth = 10,
		damage = 1,
		attack = 1,
		defence = 0,
		-- xp = 0,
		level = 1,
		drawX = 0,
		drawY = 0,
		inventory = {
			cards = {},
			items = {},
			equipments = {}
		}
	}, Player)
end

function Player:load()
	local cardsContent = love.filesystem.read("src/entities/cards.json")
	cardsData = json.decode(cardsContent)
	if cardsData then
		for _, card in ipairs(cardsData) do
			if card.id == 1 then
				self:addCardToInventory(card)
			end
		end
	end
end

function Player:addCardToInventory(cardData)
	if not self:hasCardInInventory(cardData.id) then
		table.insert(self.inventory.cards, cardData)
		self.cardHand:setCards(player:getInventoryCards())
	end
end

function Player:setInventoryCards(cardsList)
	self.inventory.cards = cardsList or {};
end

function Player:hasCardInInventory(cardId)
	for _, card in ipairs(self.inventory.cards) do
		if card.id == cardId then
			return true
		end
	end
	return false
end

function Player:getInventoryCards()
	return self.inventory.cards
end

function Player:getInventoryItems()
	return self.inventory.equipments
end

function Player:equipItem(equipment)
	if #self.inventory.equipments < math.min(6, self.level) then
		table.insert(self.inventory.equipments, equipment)
		if equipment.stats then
			if equipment.stats.damage then self.damage = self.damage + equipment.stats.damage end
			if equipment.stats.armor then self.defence = self.defence + equipment.stats.armor end
		end
		return true
	end
	return false
end

function Player:unequipItem(index)
	local equipment = table.remove(self.inventory.equipments, index)
	if equipment and equipment.stats then
		if equipment.stats.damage then self.damage = self.damage - equipment.stats.damage end
		if equipment.stats.armor then self.defence = self.defence - equipment.stats.armor end
	end
	return equipment
end

function Player:update(dt)
end

function Player:draw()
	love.graphics.setColor(1, 1, 1, 1)
	local CrTvScreen = CrTv:getCrTvScreenDetails();
	self.drawX = CrTvScreen.border.left + 100
	self.drawY = CrTvScreen.border.bottom - 100
	love.graphics.rectangle("fill", self.drawX, self.drawY, self.width,
		self.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", self.drawX, self.drawY, self.width,
		self.height)
end

function Player:keypressed(key)
	if key == "q" then
		for _, card in ipairs(cardsData) do
			if card.rarity == #self.inventory.cards + 1 then
				self:addCardToInventory(card)
			end
		end
	end
end

return Player;
