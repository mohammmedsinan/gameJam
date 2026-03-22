local love             = require("love")
local CardHand         = require("src/ui/CardHand")
local CardHandler      = require("src/utils/card")
local json             = require("src/utils/json")
local DungeonShader    = require("src/utils/DungeonShader")

local Shop             = {}
Shop.__index           = Shop

local C                = {
	bg         = { 0.07, 0.07, 0.09, 1 },
	panelBg    = { 0.12, 0.12, 0.15, 0.95 },
	panelInner = { 0.09, 0.09, 0.11, 0.98 },
	border     = { 0.85, 0.55, 0.10, 0.9 }, -- warm orange
	borderDim  = { 0.85, 0.55, 0.10, 0.45 },
	title      = { 0.95, 0.65, 0.15, 1 },
	text       = { 0.90, 0.90, 0.90, 1 },
	textDim    = { 0.60, 0.60, 0.65, 1 },
	gold       = { 1.0, 0.85, 0.20, 1 },
	green      = { 0.30, 0.85, 0.45, 1 },
	red        = { 0.90, 0.30, 0.30, 1 },
	btnBg      = { 0.18, 0.18, 0.22, 1 },
	btnHover   = { 0.25, 0.25, 0.30, 1 },
	btnBorder  = { 0.85, 0.55, 0.10, 0.7 },
	xpBar      = { 0.30, 0.55, 0.95, 1 },
	xpBarBg    = { 0.15, 0.15, 0.20, 1 },
}

local CORNER           = 10
local BORDER_W         = 2

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
-- State
local cardHand     -- CardHand for the shop cards (top section)
local allCards     -- all card data from JSON
local allEquipment -- all equipment data from JSON

-- Shop state
local shopCards        = {}  -- 4 random cards offered this visit
local shopEquipment    = {}  -- 2 random equipment offered this visit
local playerGold       = 500 -- demo starting gold
-- using player.level now
local playerXP         = 35
local xpToNext         = 100
local levelUpCost      = 50

-- Button state
local buttons          = {}
local hoveredButton    = nil

-- Equipment hover
local hoveredEquipIdx  = nil

-- Animations
local _time            = 0
local panelAlpha       = 0
local targetPanelAlpha = 1

-------------------------------------------------------------------------------
-- Layout computation (responsive to window size)
-------------------------------------------------------------------------------
local L                = {}

local function computeLayout()
	local W, H = love.graphics.getDimensions()
	local pad = 30
	local innerPad = 16

	-- Outer panel
	L.outerX = pad
	L.outerY = pad
	L.outerW = W - pad * 2
	L.outerH = H - pad * 2

	-- Title area
	L.titleY = L.outerY + 16

	-- Cards section (top)
	local sectionPad = 14
	L.cardsX = L.outerX + innerPad
	L.cardsY = L.outerY + 50
	L.cardsW = L.outerW - innerPad * 2
	L.cardsH = math.floor(L.outerH * 0.45)

	-- Bottom row
	local bottomY = L.cardsY + L.cardsH + sectionPad
	local bottomH = L.outerY + L.outerH - bottomY - 55 -- leave room for leave button
	local gap = sectionPad
	local halfW = (L.cardsW - gap) / 2

	-- Equipment section (bottom left)
	L.equipX = L.cardsX
	L.equipY = bottomY
	L.equipW = halfW
	L.equipH = bottomH

	-- Leveling section (bottom right)
	L.levelX = L.cardsX + halfW + gap
	L.levelY = bottomY
	L.levelW = halfW
	L.levelH = bottomH

	-- Leave button
	L.leaveX = W / 2 - 80
	L.leaveY = L.outerY + L.outerH - 40
	L.leaveW = 160
	L.leaveH = 32
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function drawPanel(x, y, w, h, fillColor, borderColor, radius)
	radius = radius or CORNER
	love.graphics.setColor(fillColor)
	love.graphics.rectangle("fill", x, y, w, h, radius, radius)
	if borderColor then
		love.graphics.setColor(borderColor)
		love.graphics.setLineWidth(BORDER_W)
		love.graphics.rectangle("line", x, y, w, h, radius, radius)
		love.graphics.setLineWidth(1)
	end
end

local function drawButton(id, x, y, w, h, label, enabled)
	local btn = { id = id, x = x, y = y, w = w, h = h, enabled = enabled ~= false }
	buttons[#buttons + 1] = btn

	local isHovered = hoveredButton == id
	local bg = isHovered and C.btnHover or C.btnBg
	if not btn.enabled then bg = { 0.12, 0.12, 0.14, 0.6 } end

	drawPanel(x, y, w, h, bg, btn.enabled and C.btnBorder or C.borderDim, 6)

	local font = love.graphics.getFont()
	local tw = font:getWidth(label)
	local th = font:getHeight()
	local textColor = btn.enabled and C.text or C.textDim
	love.graphics.setColor(textColor)
	love.graphics.print(label, x + w / 2 - tw / 2, y + h / 2 - th / 2)
end

local function pointInRect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

local RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS = {
	{ 0.65, 0.68, 0.72 },
	{ 0.20, 0.78, 0.40 },
	{ 0.20, 0.50, 1.00 },
	{ 0.60, 0.20, 0.90 },
	{ 1.00, 0.72, 0.10 },
}

-------------------------------------------------------------------------------
-- Shop stock generation
-------------------------------------------------------------------------------
local function pickRandom(tbl, count)
	local pool = {}
	for i, v in ipairs(tbl) do pool[i] = v end
	local result = {}
	for i = 1, math.min(count, #pool) do
		local idx = love.math.random(1, #pool)
		result[#result + 1] = pool[idx]
		table.remove(pool, idx)
	end
	return result
end

local function refreshShop()
	-- Pick 4 cards
	shopCards = pickRandom(allCards, 4)
	cardHand:clear()
	for _, data in ipairs(shopCards) do
		cardHand:addCard(data)
	end

	-- Pick 2 equipment
	shopEquipment = pickRandom(allEquipment, 2)
end

-------------------------------------------------------------------------------
-- Load
-------------------------------------------------------------------------------
function Shop:load()
	computeLayout()

	-- Load card data
	allCards = {}
	local cardsContent = love.filesystem.read("src/entities/cards.json")
	if cardsContent then
		allCards = json.decode(cardsContent) or {}
	end

	-- Load equipment data
	allEquipment = {}
	local equipContent = love.filesystem.read("src/entities/equipment.json")
	if equipContent then
		allEquipment = json.decode(equipContent) or {}
	end

	-- Create card hand (positioned inside the cards panel)
	cardHand = CardHand.new({
		layout        = "straight",
		x             = L.cardsX + L.cardsW / 2,
		y             = L.cardsY + L.cardsH / 2,
		width         = L.cardsW - 40,
		height        = L.cardsH - 20,
		cardWidth     = 100,
		cardHeight    = 140,
		fanArc        = math.pi / 8,
		onCardClicked = function(card)
			-- Buying a card
			if playerGold >= card.price then
				playerGold = playerGold - card.price
				cardHand:removeCard(card.id)
				-- Remove from shopCards
				for i, sc in ipairs(shopCards) do
					if sc.id == card.id then
						table.remove(shopCards, i)
						break
					end
				end
				player:addCardToInventory(card)
				print("[Shop] Bought card: " .. card.name .. " for $" .. card.price)
			else
				print("[Shop] Not enough gold to buy: " .. card.name)
			end
		end,
	})

	-- Initial shop stock
	refreshShop()

	-- Reset animations
	panelAlpha = 0
	targetPanelAlpha = 1
	_time = 0
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------
function Shop:update(dt)
	_time = _time + dt
	DungeonShader:update(dt)

	-- Fade-in animation
	if panelAlpha < targetPanelAlpha then
		panelAlpha = math.min(panelAlpha + dt * 3.0, targetPanelAlpha)
	end

	cardHand:update(dt)

	-- Update hovered button
	local mx, my = love.mouse.getPosition()
	hoveredButton = nil
	for _, btn in ipairs(buttons) do
		if btn.enabled and pointInRect(mx, my, btn.x, btn.y, btn.w, btn.h) then
			hoveredButton = btn.id
			break
		end
	end

	-- Check equipment hover
	hoveredEquipIdx = nil
	for i, eq in ipairs(shopEquipment) do
		local eqY = L.equipY + 40 + (i - 1) * 90
		if pointInRect(mx, my, L.equipX + 10, eqY, L.equipW - 20, 80) then
			hoveredEquipIdx = i
		end
	end
end

-------------------------------------------------------------------------------
-- Draw
-------------------------------------------------------------------------------
function Shop:draw()
	local W, H = love.graphics.getDimensions()

	-- ── Background with dungeon shader ──
	DungeonShader:draw()

	-- Reset button list each frame
	buttons = {}

	local alpha = panelAlpha

	-- ── Outer panel ──
	love.graphics.setColor(C.panelBg[1], C.panelBg[2], C.panelBg[3], C.panelBg[4] * alpha)
	love.graphics.rectangle("fill", L.outerX, L.outerY, L.outerW, L.outerH, CORNER + 2, CORNER + 2)
	love.graphics.setColor(C.border[1], C.border[2], C.border[3], C.border[4] * alpha)
	love.graphics.setLineWidth(BORDER_W + 1)
	love.graphics.rectangle("line", L.outerX, L.outerY, L.outerW, L.outerH, CORNER + 2, CORNER + 2)
	love.graphics.setLineWidth(1)

	-- ── Title ──
	local font = love.graphics.getFont()
	local titleText = "The Shopper"
	local titleW = font:getWidth(titleText)
	love.graphics.setColor(C.title[1], C.title[2], C.title[3], alpha)
	love.graphics.print(titleText, L.outerX + L.outerW / 2 - titleW / 2, L.titleY)

	-- ── Gold display ──
	love.graphics.setColor(C.gold[1], C.gold[2], C.gold[3], alpha)
	love.graphics.print("Gold: " .. playerGold, L.outerX + L.outerW - 120, L.titleY)

	-- ════════════════════════════════════════════════════════════════════
	-- CARDS SECTION
	-- ════════════════════════════════════════════════════════════════════
	drawPanel(L.cardsX, L.cardsY, L.cardsW, L.cardsH, C.panelInner, C.borderDim)

	-- Section label
	local cardsLabel = "Cards (Artifact) - 4 per Shop"
	local clW = font:getWidth(cardsLabel)
	love.graphics.setColor(C.title[1], C.title[2], C.title[3], 0.85 * alpha)
	love.graphics.print(cardsLabel, L.cardsX + L.cardsW / 2 - clW / 2, L.cardsY + 8)

	-- Draw cards via CardHand
	cardHand:draw()

	-- ════════════════════════════════════════════════════════════════════
	-- EQUIPMENT SECTION (bottom left)
	-- ════════════════════════════════════════════════════════════════════
	drawPanel(L.equipX, L.equipY, L.equipW, L.equipH, C.panelInner, C.borderDim)

	local eqTitle = "Equipment - 2 per Shop"
	local eqTW = font:getWidth(eqTitle)
	love.graphics.setColor(C.title[1], C.title[2], C.title[3], 0.85 * alpha)
	love.graphics.print(eqTitle, L.equipX + L.equipW / 2 - eqTW / 2, L.equipY + 8)

	-- Slot info
	-- use player stats
	local equippedCount = player and #player.inventory.equipments or 0
	local maxEquipSlots = player and math.min(6, player.level) or 0
	local slotInfo = "Slots: " .. equippedCount .. " / " .. maxEquipSlots
	love.graphics.setColor(C.textDim)
	love.graphics.print(slotInfo, L.equipX + 14, L.equipY + 8 + font:getHeight() + 4)

	-- Equipment items
	local fh = font:getHeight()
	for i, eq in ipairs(shopEquipment) do
		local panelHeight = 100
		local eqY = L.equipY + 40 + (i - 1) * panelHeight
		local isHov = (hoveredEquipIdx == i)

		-- Equipment card background
		local eqBg = isHov and { 0.16, 0.16, 0.20, 0.95 } or { 0.11, 0.11, 0.14, 0.9 }
		local rc = RARITY_COLORS[eq.rarity] or { 0.6, 0.6, 0.6 }
		drawPanel(L.equipX + 10, eqY, L.equipW - 20, panelHeight, eqBg,
			{ rc[1], rc[2], rc[3], isHov and 0.9 or 0.5 }, 6)

		-- Name (rarity colored)
		love.graphics.setColor(rc[1], rc[2], rc[3], alpha)
		love.graphics.print(eq.name, L.equipX + 20, eqY + 6)

		-- Rarity + slot
		love.graphics.setColor(C.textDim)
		local meta = (RARITY_NAMES[eq.rarity] or "?") .. " • " .. (eq.slot or "?")
		love.graphics.print(meta, L.equipX + 20, eqY + 6 + fh)

		-- Description (on hover)
		if isHov then
			love.graphics.setColor(0.78, 0.78, 0.80, alpha)
			love.graphics.print(eq.description or "", L.equipX + 20, eqY + 6 + fh * 2)
		end

		-- Price + buy button
		love.graphics.setColor(C.gold)
		love.graphics.print("$" .. eq.price, L.equipX + 20, eqY + 70)

		local canBuy = false
		if player then
			local currentSlots = #player.inventory.equipments
			local maxSlots = math.min(6, player.level)
			canBuy = playerGold >= eq.price and currentSlots < maxSlots
		end

		drawButton("buy_eq_" .. i,
			L.equipX + L.equipW - 90, eqY + 48,
			68, 24,
			canBuy and "Buy" or "---",
			canBuy)
	end

	-- ════════════════════════════════════════════════════════════════════
	-- LEVELING & XP SECTION (bottom right)
	-- ════════════════════════════════════════════════════════════════════
	drawPanel(L.levelX, L.levelY, L.levelW, L.levelH, C.panelInner, C.borderDim)

	local lvlTitle = "Leveling & XP"
	local lvlTW = font:getWidth(lvlTitle)
	love.graphics.setColor(C.title[1], C.title[2], C.title[3], 0.85 * alpha)
	love.graphics.print(lvlTitle, L.levelX + L.levelW / 2 - lvlTW / 2, L.levelY + 8)

	-- Current level
	local centerX = L.levelX + L.levelW / 2
	local contentY = L.levelY + 36

	love.graphics.setColor(C.text)
	local pLevel = player and player.level or 1
	local lvlText = "Level " .. pLevel
	local lvlW2 = font:getWidth(lvlText)
	love.graphics.print(lvlText, centerX - lvlW2 / 2, contentY)
	contentY = contentY + fh + 8

	-- XP bar
	local barW = L.levelW - 60
	local barH = 16
	local barX = L.levelX + 30
	local xpPct = math.min(playerXP / xpToNext, 1.0)

	-- Animated glow
	local pulseAlpha = 0.3 + 0.15 * math.sin(_time * 3)

	-- Bar background
	love.graphics.setColor(C.xpBarBg)
	love.graphics.rectangle("fill", barX, contentY, barW, barH, 4, 4)

	-- Bar fill
	local fillW = math.max(4, barW * xpPct)
	love.graphics.setColor(C.xpBar[1], C.xpBar[2], C.xpBar[3], 0.85)
	love.graphics.rectangle("fill", barX, contentY, fillW, barH, 4, 4)

	-- Bar glow on top
	love.graphics.setColor(1, 1, 1, pulseAlpha * xpPct)
	love.graphics.rectangle("fill", barX, contentY, fillW, barH / 2, 4, 4)

	-- Bar border
	love.graphics.setColor(C.borderDim)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", barX, contentY, barW, barH, 4, 4)

	-- XP text
	love.graphics.setColor(C.text)
	local xpText = playerXP .. " / " .. xpToNext .. " XP"
	local xpTW = font:getWidth(xpText)
	love.graphics.print(xpText, centerX - xpTW / 2, contentY + barH + 4)
	contentY = contentY + barH + fh + 12

	-- Level up info
	love.graphics.setColor(C.textDim)
	local infoText = "Spend gold to gain experience"
	local infoW = font:getWidth(infoText)
	love.graphics.print(infoText, centerX - infoW / 2, contentY)
	contentY = contentY + fh + 6

	love.graphics.setColor(C.textDim)
	local costText = "Cost: $" .. levelUpCost .. " per level point"
	local costW = font:getWidth(costText)
	love.graphics.print(costText, centerX - costW / 2, contentY)
	contentY = contentY + fh + 12

	-- Level up button
	local canLevel = playerGold >= levelUpCost
	drawButton("level_up",
		centerX - 70, contentY,
		170, 50,
		canLevel and ("Level Up ($" .. levelUpCost .. ")") or "Not enough gold",
		canLevel)

	-- ════════════════════════════════════════════════════════════════════
	-- LEAVE SHOP BUTTON
	-- ════════════════════════════════════════════════════════════════════
	drawButton("leave_shop", L.leaveX, L.leaveY, L.leaveW, L.leaveH, "Leave Shop", true)

	-- ── Reroll button (next to leave) ──
	drawButton("reroll",
		L.leaveX - 160, L.leaveY,
		140, L.leaveH,
		"Reroll ($10)", playerGold >= 10)

	love.graphics.setColor(1, 1, 1, 1)
end

-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------
function Shop:keypressed(key)
	if key == "escape" or key == "b" then
		SceneManager:switch("game", { kind = "fade", duration = 0.3 })
	end
end

function Shop:mousepressed(x, y, button)
	if button ~= 1 then return end

	-- Card clicks handled by CardHand
	cardHand:mousepressed(x, y, button)

	-- Check buttons
	for _, btn in ipairs(buttons) do
		if btn.enabled and pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
			if btn.id == "leave_shop" then
				SceneManager:switch("game", { kind = "fade", duration = 0.3 })
			elseif btn.id == "reroll" and playerGold >= 10 then
				playerGold = playerGold - 10
				refreshShop()
				print("[Shop] Rerolled stock for $10")
			elseif btn.id == "level_up" and playerGold >= levelUpCost then
				playerGold = playerGold - levelUpCost
				playerXP = playerXP + 25
				if playerXP >= xpToNext then
					playerXP = playerXP - xpToNext
					if player then player.level = player.level + 1 end
					xpToNext = math.floor(xpToNext * 1.4)
					levelUpCost = math.floor(levelUpCost * 1.3)
					local newLevel = player and player.level or 1
					print("[Shop] Leveled up to " .. newLevel .. "!")
				else
					print("[Shop] Gained 25 XP!")
				end
			elseif btn.id:match("buy_eq_(%d+)") then
				local idx = tonumber(btn.id:match("buy_eq_(%d+)"))
				local eq = shopEquipment[idx]

				local currentSlots = player and #player.inventory.equipments or 0
				local maxSlots = player and math.min(6, player.level) or 0

				if eq and playerGold >= eq.price and currentSlots < maxSlots then
					playerGold = playerGold - eq.price
					if player then player:equipItem(eq) end
					table.remove(shopEquipment, idx)
					print("[Shop] Bought equipment: " .. eq.name)
				end
			end
			break
		end
	end
end

function Shop:mousereleased(x, y, button)
	cardHand:mousereleased(x, y, button)
end

function Shop:mousemoved(x, y, dx, dy)
	cardHand:mousemoved(x, y, dx, dy)
end

function Shop:resize(w, h)
	computeLayout()
	if cardHand then
		cardHand.x = L.cardsX + L.cardsW / 2
		cardHand.y = L.cardsY + L.cardsH / 2
		cardHand.width = L.cardsW - 40
		cardHand.height = L.cardsH - 20
		cardHand:_reflow()
	end
end

return Shop
