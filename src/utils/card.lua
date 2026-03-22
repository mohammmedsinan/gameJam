-------------------------------------------------------------------------------
-- card.lua  –  CardHandler
-- The single entry-point for creating, updating, and drawing interactive cards.
-- Supports rarity-based GLSL shaders, spring animations, hover/select states,
-- and callback hooks so the card system can be dropped into any context.
-------------------------------------------------------------------------------
local love             = require("love")

local CardHandler      = {}
CardHandler.__index    = CardHandler

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local RARITY_NAMES     = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS    = {
	{ 0.65, 0.68, 0.72, 1 }, -- 1  Common   (silver)
	{ 0.20, 0.78, 0.40, 1 }, -- 2  Uncommon  (green)
	{ 0.20, 0.50, 1.00, 1 }, -- 3  Rare      (blue)
	{ 0.60, 0.20, 0.90, 1 }, -- 4  Epic      (purple)
	{ 1.00, 0.72, 0.10, 1 }, -- 5  Legendary (gold)
}
local RARITY_BG_COLORS = {
	{ 0.18, 0.19, 0.22, 1 }, -- Common
	{ 0.10, 0.22, 0.14, 1 }, -- Uncommon
	{ 0.08, 0.14, 0.28, 1 }, -- Rare
	{ 0.18, 0.08, 0.28, 1 }, -- Epic
	{ 0.28, 0.18, 0.06, 1 }, -- Legendary
}

local SHADER_FILES     = {
	"assets/shaders/common.glsl",
	"assets/shaders/uncommon.glsl",
	"assets/shaders/rare.glsl",
	"assets/shaders/epic.glsl",
	"assets/shaders/legendary.glsl",
}

local TYPE_ICONS       = {
	attack  = "a",
	defense = "d",
	magic   = "m",
	heal    = "h",
	buff    = "b",
	utility = "u",
}

local DEFAULT_WIDTH    = 100
local DEFAULT_HEIGHT   = 140
local CORNER_RADIUS    = 10
local HOVER_SCALE      = 1.28
local SELECT_SCALE     = 1.10
local HOVER_LIFT       = 25
local HOVER_DELAY      = 0.10 -- seconds before tooltip fires
local IDLE_FLOAT_AMP   = 2.0
local IDLE_FLOAT_SPEED = 3.5

-- Spring settings
local SPRING_STIFF     = 92
local SPRING_DAMP      = 0.70

-------------------------------------------------------------------------------
-- Shader cache (shared across all card instances)
-------------------------------------------------------------------------------
local _shaderCache     = {}

local function getShader(rarity)
	rarity = math.max(1, math.min(5, rarity or 1))
	if _shaderCache[rarity] then return _shaderCache[rarity] end
	local path = SHADER_FILES[rarity]
	local ok, shader = pcall(love.graphics.newShader, path)
	if ok then
		_shaderCache[rarity] = shader
		return shader
	else
		print("[CardHandler] Failed to load shader: " .. path .. " – " .. tostring(shader))
		return nil
	end
end

local _fontCache = {}
local function getFont(size)
	size = math.max(8, math.floor(size))
	if not _fontCache[size] then
		_fontCache[size] = love.graphics.newFont(size)
	end
	return _fontCache[size]
end

-------------------------------------------------------------------------------
-- Internal: simple spring interpolation
-------------------------------------------------------------------------------
local function springLerp(current, target, velocity, stiffness, damping, dt)
	local force = (target - current) * stiffness
	velocity = (velocity + force * dt) * math.pow(damping, dt * 60)
	current = current + velocity * dt
	return current, velocity
end

-------------------------------------------------------------------------------
-- CardHandler.new(data)
-- data fields:
--   id, name, price, type, description, rarity (1-5),
--   stats = { damage, manaCost, heal, armor, ... }  (all optional)
-------------------------------------------------------------------------------
function CardHandler.new(data)
	data                 = data or {}
	local self           = setmetatable({}, CardHandler)

	-- Core data
	self.id              = data.id or 0
	self.name            = data.name or "Card"
	self.price           = data.price or 0
	self.type            = data.type or "attack"
	self.description     = data.description or ""
	self.rarity          = math.max(1, math.min(5, data.rarity or 1))
	self.stats           = data.stats or {}

	-- Geometry
	self.x               = 0
	self.xVel            = 0
	self.y               = 0
	self.yVel            = 0
	self.baseX           = 0
	self.baseY           = 0
	self.width           = DEFAULT_WIDTH
	self.height          = DEFAULT_HEIGHT
	self.rotation        = 0
	self.baseRotation    = 0

	-- Animation state (spring-driven)
	self.scale           = 1.0
	self.scaleVel        = 0
	self.targetScale     = 1.0
	self.liftY           = 0
	self.liftYVel        = 0
	self.targetLiftY     = 0
	self.tiltX           = 0
	self.tiltXVel        = 0
	self.targetTiltX     = 0
	self.glowAlpha       = 0
	self.glowAlphaVel    = 0
	self.targetGlowAlpha = 0

	-- State flags
	self.hovered         = false
	self.selected        = false
	self.dragging        = false
	self._dragOffsetX    = 0
	self._dragOffsetY    = 0
	self.hoverTime       = 0
	self.tooltipReady    = false
	self.visible         = true
	self.enabled         = true
	self.zIndex          = 0

	-- Internal timer for shader / idle float
	self._time           = love.math.random() * 100
	self._idleOffset     = love.math.random() * math.pi * 2

	-- Canvas for shader rendering
	self._canvas         = nil
	self._canvasDirty    = true

	-- Callbacks (user-assigned)
	self.onClick         = nil -- function(card)
	self.onHover         = nil -- function(card, isHovering)
	self.onSelect        = nil -- function(card, isSelected)
	self.onTooltip       = nil -- function(card, show, x, y)

	return self
end

-------------------------------------------------------------------------------
-- Position / geometry API
-------------------------------------------------------------------------------
function CardHandler:setPosition(x, y)
	self.baseX = x
	self.baseY = y
	if self.x == 0 and self.y == 0 then
		self.x = x
		self.y = y
	end
end

function CardHandler:setScale(s)
	self.targetScale = s
	self.scale       = s
end

function CardHandler:setRotation(r)
	self.baseRotation = r
	self.rotation     = r
end

function CardHandler:setSize(w, h)
	self.width        = w
	self.height       = h
	self._canvasDirty = true
end

-------------------------------------------------------------------------------
-- Query API
-------------------------------------------------------------------------------
function CardHandler:isHovered() return self.hovered end

function CardHandler:isSelected() return self.selected end

function CardHandler:getData()
	return {
		id          = self.id,
		name        = self.name,
		price       = self.price,
		type        = self.type,
		description = self.description,
		rarity      = self.rarity,
		stats       = self.stats,
	}
end

function CardHandler:getRarityName()
	return RARITY_NAMES[self.rarity] or "Unknown"
end

function CardHandler:getRarityColor()
	return RARITY_COLORS[self.rarity] or { 1, 1, 1, 1 }
end

-------------------------------------------------------------------------------
-- Hit testing
-------------------------------------------------------------------------------
function CardHandler:containsPoint(px, py)
	if not self.visible then return false end
	-- Account for current scale and position
	local cx = self.x
	local cy = self.y - self.liftY
	local hw = (self.width * self.scale) / 2
	local hh = (self.height * self.scale) / 2
	return px >= cx - hw and px <= cx + hw and py >= cy - hh and py <= cy + hh
end

-------------------------------------------------------------------------------
-- Input handlers (called by CardHand or directly)
-------------------------------------------------------------------------------
function CardHandler:mousemoved(mx, my, dx, dy)
	if not self.enabled then return end
	local wasHovered = self.hovered
	self.hovered = self:containsPoint(mx, my)

	if self.hovered then
		-- Tilt toward mouse
		local cx = self.x
		local relX = (mx - cx) / (self.width * self.scale * 0.5)
		self.targetTiltX = relX * 0.06 -- max tilt ±0.06 rad (~3.4°)
	else
		self.targetTiltX = 0
	end

	if self.hovered ~= wasHovered then
		self.hoverTime = 0
		self.tooltipReady = false
		if self.hovered then
			self.targetScale     = HOVER_SCALE
			self.targetLiftY     = HOVER_LIFT
			self.targetGlowAlpha = 1.0
		else
			self.targetScale     = 1.0
			self.targetLiftY     = 0
			self.targetGlowAlpha = 0.0
		end
		if self.onHover then self.onHover(self, self.hovered) end
	end
end

function CardHandler:mousepressed(mx, my, button)
	print("self.scaleVel", self.scaleVel)
	if not self.enabled then return false end
	if button == 1 and self:containsPoint(mx, my) then
		-- Bounce animation
		self.scale = 0.8
		self.selected = not self.selected
		if self.onSelect then self.onSelect(self, self.selected) end
		if self.onClick then self.onClick(self) end
		return true -- consumed
	end
	return false
end

function CardHandler:startDrag(mx, my)
	self.dragging = true
	self._dragOffsetX = self.x - mx
	self._dragOffsetY = self.y - my
end

function CardHandler:stopDrag()
	self.dragging = false
end

function CardHandler:mousereleased(mx, my, button)
	-- drag-end logic handled in CardHand or externally
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------
function CardHandler:update(dt, mx, my)
	if not self.visible then return end
	self._time = self._time + dt

	-- Auto-track mouse if coordinates supplied
	if mx and my then
		self:mousemoved(mx, my, 0, 0)
	end

	-- Hover timer → tooltip trigger
	if self.hovered then
		self.hoverTime = self.hoverTime + dt
		if self.hoverTime >= HOVER_DELAY and not self.tooltipReady then
			self.tooltipReady = true
			if self.onTooltip then
				self.onTooltip(self, true, self.x, self.y - self.liftY - self.height * self.scale * 0.5)
			end
		end
	end

	-- Spring animations
	self.scale, self.scaleVel         = springLerp(self.scale, self.targetScale, self.scaleVel, SPRING_STIFF, SPRING_DAMP,
		dt)
	self.liftY, self.liftYVel         = springLerp(self.liftY, self.targetLiftY, self.liftYVel, SPRING_STIFF, SPRING_DAMP,
		dt)
	self.tiltX, self.tiltXVel         = springLerp(self.tiltX, self.targetTiltX, self.tiltXVel, SPRING_STIFF, SPRING_DAMP,
		dt)
	self.glowAlpha, self.glowAlphaVel = springLerp(self.glowAlpha, self.targetGlowAlpha, self.glowAlphaVel, 8, 0.75, dt)

	local targetX                     = self.baseX
	local targetY                     = self.baseY - self.liftY

	if self.dragging then
		targetX = (mx or self.baseX) + self._dragOffsetX
		targetY = (my or self.baseY) + self._dragOffsetY
	else
		-- Idle floating
		local idleFloat = math.sin(self._time * IDLE_FLOAT_SPEED + self._idleOffset) * IDLE_FLOAT_AMP
		targetY = targetY + idleFloat
	end

	self.x, self.xVel = springLerp(self.x, targetX, self.xVel, SPRING_STIFF, SPRING_DAMP, dt)
	self.y, self.yVel = springLerp(self.y, targetY, self.yVel, SPRING_STIFF, SPRING_DAMP, dt)

	-- Rotation = base + tilt
	self.rotation     = self.baseRotation + self.tiltX
end

-------------------------------------------------------------------------------
-- Internal: ensure the card canvas is ready
-------------------------------------------------------------------------------
function CardHandler:_ensureCanvas()
	if self._canvas and not self._canvasDirty then return end
	local cw = self.width + 20 -- extra margin for glow
	local ch = self.height + 20
	self._canvas = love.graphics.newCanvas(cw, ch)
	self._canvasDirty = false
end

-------------------------------------------------------------------------------
-- Internal: draw the card face onto the internal canvas
-------------------------------------------------------------------------------
function CardHandler:_renderCardFace()
	self:_ensureCanvas()
	local cw, ch = self._canvas:getDimensions()
	local ox, oy = 10, 10 -- glow margin offset

	love.graphics.setCanvas(self._canvas)
	love.graphics.clear(0, 0, 0, 0)
	local prevFont = love.graphics.getFont()

	-- ── Background fill ──
	local bg = RARITY_BG_COLORS[self.rarity] or { 0.15, 0.15, 0.18, 1 }
	love.graphics.setColor(bg)
	love.graphics.rectangle("fill", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)

	-- ── Inner art area (darker) ──
	love.graphics.setColor(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1)
	local artMargin = 8
	local artH = self.height * 0.42
	love.graphics.rectangle("fill", ox + artMargin, oy + artMargin, self.width - artMargin * 2, artH, 4, 4)

	-- ── Type icon in art area ──
	local icon = TYPE_ICONS[self.type] or "?"
	local rc = RARITY_COLORS[self.rarity]
	love.graphics.setColor(rc[1], rc[2], rc[3], 0.7)
	local iconFontSize = math.floor(self.height * 0.15)
	local iconFont = getFont(iconFontSize)
	love.graphics.setFont(iconFont)
	local iconW = iconFont:getWidth(icon)
	love.graphics.print(icon,
		ox + self.width / 2 - iconW / 2,
		oy + artMargin + artH / 2 - iconFont:getHeight() / 2)

	-- ── Name ──
	love.graphics.setColor(1, 1, 1, 1)
	local nameY = oy + artMargin + artH + 6
	local nameText = self.name
	local nameFontSize = math.floor(self.height * 0.11)
	local font = getFont(nameFontSize)
	love.graphics.setFont(font)
	-- Truncate if too long
	while font:getWidth(nameText) > self.width - 16 and #nameText > 3 do
		nameText = nameText:sub(1, -2)
	end
	local nameW = font:getWidth(nameText)
	love.graphics.print(nameText, ox + self.width / 2 - nameW / 2, nameY)

	-- ── Rarity label ──
	local rarityName = RARITY_NAMES[self.rarity] or "?"
	love.graphics.setColor(rc[1], rc[2], rc[3], 0.9)
	local rarityFontSize = math.floor(self.height * 0.08)
	local rFont = getFont(rarityFontSize)
	love.graphics.setFont(rFont)
	local rnW = rFont:getWidth(rarityName)
	local rarityY = nameY + font:getHeight() + 2
	love.graphics.print(rarityName, ox + self.width / 2 - rnW / 2, rarityY)

	-- ── Stats row ──
	-- love.graphics.setColor(0.85, 0.85, 0.85, 0.9)
	-- local statsY = self.height + oy - font:getHeight() - 6
	-- local statsText = ""
	-- if self.stats.damage then
	-- 	statsText = statsText .. "DMG:" .. self.stats.damage .. " "
	-- end
	-- if self.stats.manaCost then
	-- 	statsText = statsText .. "MP:" .. self.stats.manaCost
	-- end
	-- if self.stats.heal then
	-- 	statsText = statsText .. "HP+" .. self.stats.heal .. " "
	-- end
	-- if self.stats.armor then
	-- 	statsText = statsText .. "DEF:" .. self.stats.armor
	-- end
	-- if statsText == "" then
	-- 	statsText = "$" .. self.price
	-- end
	-- local stW = font:getWidth(statsText)
	-- love.graphics.print(statsText, ox + self.width / 2 - stW / 2, statsY)
	--
	-- ── Border ──
	love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)
	love.graphics.setLineWidth(1)

	-- ── Selection highlight ──
	-- if self.selected then
	-- 	love.graphics.setColor(1, 1, 1, 0.25)
	-- 	love.graphics.rectangle("fill", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)
	-- 	love.graphics.setColor(1, 1, 1, 0.9)
	-- 	love.graphics.setLineWidth(2)
	-- 	love.graphics.rectangle("line", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)
	-- 	love.graphics.setLineWidth(1)
	-- end

	love.graphics.setFont(prevFont)
	love.graphics.setCanvas()
end

-------------------------------------------------------------------------------
-- Draw
-------------------------------------------------------------------------------
function CardHandler:draw()
	if not self.visible then return end

	-- Render the card face to canvas
	self:_renderCardFace()

	local cw, ch = self._canvas:getDimensions()

	-- Apply shader if available
	local shader = getShader(self.rarity)
	if shader then
		shader:send("time", self._time)
		if shader:hasUniform("cardSize") then
			shader:send("cardSize", { self.width, self.height })
		end
		love.graphics.setShader(shader)
	end

	-- Draw the canvas with transform
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(
		self._canvas,
		self.x, self.y,
		self.rotation,
		self.scale, self.scale,
		cw / 2, ch / 2
	)

	love.graphics.setShader()

	-- Outer glow aura (additive)
	if self.glowAlpha > 0.01 then
		local rc = RARITY_COLORS[self.rarity]
		love.graphics.setColor(rc[1], rc[2], rc[3], self.glowAlpha * 0.25)
		local glowRad = 6 * self.scale
		love.graphics.rectangle("fill",
			self.x - (self.width * self.scale) / 2 - glowRad,
			self.y - (self.height * self.scale) / 2 - glowRad,
			self.width * self.scale + glowRad * 2,
			self.height * self.scale + glowRad * 2,
			CORNER_RADIUS + 4, CORNER_RADIUS + 4
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

-------------------------------------------------------------------------------
-- Module-level utilities
-------------------------------------------------------------------------------

--- Load a card from a flat table (e.g. decoded from JSON)
function CardHandler.fromTable(t)
	return CardHandler.new(t)
end

--- Load all cards from a JSON file, returns a list of CardHandler instances
function CardHandler.loadFromJSON(path)
	local json = require("src/utils/json")
	local content = love.filesystem.read(path)
	if not content then
		print("[CardHandler] Could not read: " .. path)
		return {}
	end
	local data = json.decode(content)
	if not data then return {} end
	-- Support both array and single-object
	if data.id then data = { data } end
	local cards = {}
	for _, entry in ipairs(data) do
		cards[#cards + 1] = CardHandler.new(entry)
	end
	return cards
end

return CardHandler
