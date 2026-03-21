-------------------------------------------------------------------------------
-- CardHand.lua  –  Container that manages a collection of CardHandler cards.
-- Supports two layouts:
--   "fan"  – curved arc (combat hand)
--   "grid" – rows & columns (shop / inventory)
-- Handles input routing, z-ordering, smooth layout reflow, and tooltip display.
-------------------------------------------------------------------------------
local love = require("love")
local CardHandler = require("src/utils/card")
local CardTooltip = require("src/ui/CardTooltip")

local CardHand = {}
CardHand.__index = CardHand

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local REFLOW_SPEED = 8 -- spring-like lerp speed for layout repositioning

-------------------------------------------------------------------------------
-- CardHand.new(opts)
--   opts.layout        "fan" | "grid"  (default "fan")
--   opts.x, opts.y     anchor position (center-bottom for fan, top-left for grid)
--   opts.width         available width for the hand
--   opts.cardWidth     per-card width  (default 100)
--   opts.cardHeight    per-card height (default 140)
--   opts.gridCols      columns for grid layout (default 5)
--   opts.gridSpacingX  horizontal gap in grid (default 12)
--   opts.gridSpacingY  vertical gap in grid (default 16)
--   opts.fanArc        total arc in radians for fan (default π/4)
--   opts.onCardClicked function(card)
--   opts.onCardHovered function(card, isHovering)
-------------------------------------------------------------------------------
function CardHand.new(opts)
	opts               = opts or {}
	local self         = setmetatable({}, CardHand)

	self.layout        = opts.layout or "fan"
	self.x             = opts.x or 0
	self.y             = opts.y or 0
	self.width         = opts.width or 600
	self.cardWidth     = opts.cardWidth or 100
	self.cardHeight    = opts.cardHeight or 140
	self.cards         = {}

	-- Fan settings
	self.fanArc        = opts.fanArc or math.pi / 4

	-- Grid settings
	self.gridCols      = opts.gridCols or 2
	self.gridSpacingX  = opts.gridSpacingX or 12
	self.gridSpacingY  = opts.gridSpacingY or 16

	-- Tooltip
	self._tooltip      = CardTooltip.new()
	self._hoveredCard  = nil

	-- Callbacks
	self.onCardClicked = opts.onCardClicked
	self.onCardHovered = opts.onCardHovered

	return self
end

-------------------------------------------------------------------------------
-- Add / Remove
-------------------------------------------------------------------------------
function CardHand:addCard(data)
	local card
	if getmetatable(data) == CardHandler then
		card = data
	else
		card = CardHandler.new(data)
	end
	card:setSize(self.cardWidth, self.cardHeight)

	-- Wire tooltip callback
	local handRef = self
	card.onTooltip = function(c, show, tx, ty)
		if show then
			handRef._tooltip:show(c, tx, ty)
		else
			handRef._tooltip:hide()
		end
	end

	-- Wire click callback
	card.onClick = function(c)
		if handRef.onCardClicked then
			handRef.onCardClicked(c)
		end
	end

	card.onHover = function(c, hovering)
		if hovering then
			handRef._hoveredCard = c
		else
			if handRef._hoveredCard == c then
				handRef._hoveredCard = nil
				handRef._tooltip:hide()
			end
		end
		if handRef.onCardHovered then
			handRef.onCardHovered(c, hovering)
		end
	end

	self.cards[#self.cards + 1] = card
	self:_reflow()
	return card
end

function CardHand:removeCard(cardId)
	for i, card in ipairs(self.cards) do
		if card.id == cardId then
			table.remove(self.cards, i)
			if self._hoveredCard == card then
				self._hoveredCard = nil
				self._tooltip:hide()
			end
			self:_reflow()
			return true
		end
	end
	return false
end

function CardHand:getCards()
	return self.cards
end

function CardHand:clear()
	self.cards = {}
	self._hoveredCard = nil
	self._tooltip:hide()
end

function CardHand:setCards(cardsList)
	self:clear()
	if cardsList then
		for _, data in ipairs(cardsList) do
			self:addCard(data)
		end
	end
end

-------------------------------------------------------------------------------
-- Layout computation
-------------------------------------------------------------------------------
function CardHand:_reflow()
	local n = #self.cards
	if n == 0 then return end

	if self.layout == "fan" then
		self:_reflowFan()
	else
		self:_reflowGrid()
	end
end

function CardHand:_reflowFan()
	local n = #self.cards
	if n == 0 then return end

	local sw, sh = love.graphics.getDimensions()
	self.cardWidth = math.max(60, math.min(140, math.floor(sw * 0.08)))
	self.cardHeight = math.floor(self.cardWidth * 1.4)
	for _, card in ipairs(self.cards) do
		card:setSize(self.cardWidth, self.cardHeight)
	end

	local totalArc = self.fanArc
	if n == 1 then totalArc = 0 end

	-- Compute the spacing so cards don't overlap too much
	local maxSpacing = self.cardWidth * 0.85
	local naturalSpacing = (n > 1) and (self.width / (n - 1)) or 0
	local spacing = math.min(naturalSpacing, maxSpacing)
	local totalW = spacing * (n - 1)
	local startX = self.x - totalW / 2

	local fanRadius = 600 -- virtual arc radius

	for i, card in ipairs(self.cards) do
		local t = (n > 1) and ((i - 1) / (n - 1)) or 0.5
		local angle = (t - 0.5) * totalArc

		local cx = startX + (i - 1) * spacing
		local cy = self.y + (1 - math.cos(angle)) * fanRadius * 0.02

		card:setPosition(cx, cy)
		card:setRotation(angle * 0.4)
		card.zIndex = i
	end
end

function CardHand:_reflowGrid()
	local n = #self.cards
	if n == 0 then return end

	local sw, sh = love.graphics.getDimensions()
	self.cardWidth = math.max(60, math.min(140, math.floor(sw * 0.08)))
	self.cardHeight = math.floor(self.cardWidth * 1.4)
	for _, card in ipairs(self.cards) do
		card:setSize(self.cardWidth, self.cardHeight)
	end

	local cols = self.gridCols
	local cellW = self.cardWidth + self.gridSpacingX
	local cellH = self.cardHeight + self.gridSpacingY

	for i, card in ipairs(self.cards) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local cx = self.x + col * cellW + self.cardWidth / 2
		local cy = self.y + row * cellH + self.cardHeight / 2

		card:setPosition(cx, cy)
		card:setRotation(0)
		card.zIndex = i
	end
end

-------------------------------------------------------------------------------
-- Input routing
-------------------------------------------------------------------------------
function CardHand:mousemoved(mx, my, dx, dy)
	-- Route to all cards (they self-detect hover)
	for _, card in ipairs(self.cards) do
		card:mousemoved(mx, my, dx, dy)
	end
end

function CardHand:mousepressed(mx, my, button)
	-- Route in reverse z-order so top card gets priority
	for i = #self.cards, 1, -1 do
		if self.cards[i]:mousepressed(mx, my, button) then
			return true
		end
	end
	return false
end

function CardHand:mousereleased(mx, my, button)
	for _, card in ipairs(self.cards) do
		card:mousereleased(mx, my, button)
	end
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------
function CardHand:update(dt)
	local mx, my = love.mouse.getPosition()
	for _, card in ipairs(self.cards) do
		card:update(dt, mx, my)
	end
	self._tooltip:update(dt)
end

-------------------------------------------------------------------------------
-- Draw
-------------------------------------------------------------------------------
function CardHand:draw()
	-- Build sorted draw order: hovered card drawn last (on top)
	local sorted = {}
	for i, card in ipairs(self.cards) do
		sorted[i] = card
	end
	table.sort(sorted, function(a, b)
		if a.hovered ~= b.hovered then
			return not a.hovered -- non-hovered first
		end
		return a.zIndex < b.zIndex
	end)

	for _, card in ipairs(sorted) do
		card:draw()
	end

	-- Tooltip on top of everything
	self._tooltip:draw()
end

return CardHand
