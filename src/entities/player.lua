local CrTv = require("src/ui/CrTv");
local json = require("src/utils/json");
local CharacterFX = require("src/utils/character_fx")

local Player = {}
Player.__index = Player

function Player.new(bus, cardHand)
	local self = setmetatable({
		name = "player",
		bus = bus,
		cardHand = cardHand,
		width = 70,
		height = 70,
		health = 10,
		maxHealth = 10,
		damage = 1,
		attack = 10,
		defence = 0,
		-- xp = 0,
		level = 1,
		gold = 250,
		drawX = 0,
		drawY = 0,
		inventory = {
			cards = {},
			items = {},
			equipments = {}
		}
	}, Player)
	-- Character visual effects (cool blue/cyan energy)
	self.cfx = CharacterFX.new({
		color = { 0.3, 0.7, 1.0 },
		intensity = 1.0,
	})
	return self
end

function Player:addGold(amount)
	self.gold = self.gold + (amount or 0)
end

function Player:spendGold(amount)
	if self.gold >= amount then
		self.gold = self.gold - amount
		return true
	end
	return false
end

function Player:load()
	local cardsContent = love.filesystem.read("src/entities/cards.json")
	cardsData = json.decode(cardsContent)
	-- if cardsData then
	-- 	for _, card in ipairs(cardsData) do
	-- 		if card.id == 2 or card.id == 3 then
	-- 			self:addCardToInventory(card)
	-- 		end
	-- 	end
	-- end
end

function Player:addCardToInventory(cardData)
	if not self:hasCardInInventory(cardData.id) then
		cardData.isOwned = true
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

function Player:removeCardFromInventory(cardId)
	for i, card in ipairs(self.inventory.cards) do
		if card.id == cardId then
			table.remove(self.inventory.cards, i)
			if self.cardHand then
				self.cardHand:setCards(self.inventory.cards)
			end
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
	if self.cfx then self.cfx:update(dt) end
end

function Player:setVisualState(state)
	if self.cfx then self.cfx:setState(state) end
end

function Player:draw()
	local CrTvScreen = CrTv:getCrTvScreenDetails();
	self.drawX = CrTvScreen.border.left + 100
	self.drawY = CrTvScreen.border.bottom - 100

	-- Draw character with shader + particles (replaces plain rectangle)
	if self.cfx then
		self.cfx:draw(self.drawX, self.drawY, self.width, self.height)
	end
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
