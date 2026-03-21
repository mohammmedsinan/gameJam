-------------------------------------------------------------------------------
-- CardTooltip.lua  –  Floating tooltip overlay for hovered cards
-- Shows card name (rarity-colored), full description, stats, type, and price.
-- Smooth fade-in / fade-out. Automatically positions near the card.
-------------------------------------------------------------------------------
local love          = require("love")

local CardTooltip   = {}
CardTooltip.__index = CardTooltip

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local RARITY_NAMES  = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS = {
    { 0.65, 0.68, 0.72 },
    { 0.20, 0.78, 0.40 },
    { 0.20, 0.50, 1.00 },
    { 0.60, 0.20, 0.90 },
    { 1.00, 0.72, 0.10 },
}

local _fontCache    = {}
local function getFont(size)
    size = math.max(8, math.floor(size))
    if not _fontCache[size] then
        _fontCache[size] = love.graphics.newFont(size)
    end
    return _fontCache[size]
end

local PADDING       = 10
local FADE_SPEED    = 6.0
local BG_COLOR      = { 0.08, 0.08, 0.12, 0.92 }
local BORDER_RADIUS = 6
local STAT_LABELS   = {
    damage   = "Damage",
    manaCost = "Mana Cost",
    heal     = "Heal",
    armor    = "Armor",
    range    = "Range",
    duration = "Duration",
}

-------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------
function CardTooltip.new()
    local self        = setmetatable({}, CardTooltip)
    self._visible     = false
    self._alpha       = 0
    self._targetAlpha = 0
    self._card        = nil
    self._x           = 0
    self._y           = 0
    return self
end

-------------------------------------------------------------------------------
-- Show / Hide
-------------------------------------------------------------------------------
function CardTooltip:show(card, x, y)
    self._card        = card
    self._x           = x
    self._y           = y
    self._visible     = true
    self._targetAlpha = 1.0
end

function CardTooltip:hide()
    self._targetAlpha = 0.0
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------
function CardTooltip:update(dt)
    -- Fade
    if self._alpha < self._targetAlpha then
        self._alpha = math.min(self._alpha + FADE_SPEED * dt, 1.0)
    elseif self._alpha > self._targetAlpha then
        self._alpha = math.max(self._alpha - FADE_SPEED * dt, 0.0)
    end
    if self._alpha <= 0.01 and self._targetAlpha <= 0 then
        self._visible = false
        self._card = nil
    end
end

-------------------------------------------------------------------------------
-- Word-wrap helper
-------------------------------------------------------------------------------
local function wordWrap(text, font, maxWidth)
    local lines = {}
    local line = ""
    for word in text:gmatch("%S+") do
        local test = line == "" and word or (line .. " " .. word)
        if font:getWidth(test) > maxWidth then
            if line ~= "" then
                lines[#lines + 1] = line
            end
            line = word
        else
            line = test
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

-------------------------------------------------------------------------------
-- Draw
-------------------------------------------------------------------------------
function CardTooltip:draw()
    if not self._visible or not self._card or self._alpha <= 0.01 then return end

    local card         = self._card
    local data         = type(card.getData) == "function" and card:getData() or card

    local sw, sh       = love.graphics.getDimensions()
    local tooltipWidth = math.max(160, math.floor(sw * 0.15))
    local fontSize     = math.max(12, math.floor(sh * 0.022))
    local font         = getFont(fontSize)
    love.graphics.setFont(font)
    local fh         = font:getHeight()

    -- ── Compute content height ──
    local innerW     = tooltipWidth - PADDING * 2
    local descLines  = wordWrap(data.description or "", font, innerW)
    local statsCount = 0
    if data.stats then
        for _ in pairs(data.stats) do statsCount = statsCount + 1 end
    end

    local contentH = fh   -- name
        + fh * 0.6        -- rarity label
        + 4               -- spacing
        + #descLines * fh -- description
        + 6               -- spacing
        + statsCount * fh -- stats rows
        + fh              -- price
        + 4               -- bottom pad

    local tooltipH = contentH + PADDING * 2

    -- ── Position (above card, clamped to screen) ──
    local tx = self._x - tooltipWidth / 2
    local ty = self._y - tooltipH - 8
    tx = math.max(4, math.min(tx, sw - tooltipWidth - 4))
    ty = math.max(4, ty)

    -- ── Background ──
    love.graphics.setColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4] * self._alpha)
    love.graphics.rectangle("fill", tx, ty, tooltipWidth, tooltipH, BORDER_RADIUS, BORDER_RADIUS)

    -- Border (rarity colored)
    local rc = RARITY_COLORS[data.rarity] or { 1, 1, 1 }
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.7 * self._alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", tx, ty, tooltipWidth, tooltipH, BORDER_RADIUS, BORDER_RADIUS)
    love.graphics.setLineWidth(1)

    -- ── Text content ──
    local cx = tx + PADDING
    local cy = ty + PADDING

    -- Name
    love.graphics.setColor(1, 1, 1, self._alpha)
    love.graphics.print(data.name or "Card", cx, cy)
    cy = cy + fh

    -- Rarity
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.9 * self._alpha)
    love.graphics.print(RARITY_NAMES[data.rarity] or "Unknown", cx, cy)
    cy = cy + fh * 0.6 + 4

    -- Description
    love.graphics.setColor(0.82, 0.82, 0.82, self._alpha)
    for _, line in ipairs(descLines) do
        love.graphics.print(line, cx, cy)
        cy = cy + fh
    end
    cy = cy + 6

    -- Stats
    if data.stats then
        for key, val in pairs(data.stats) do
            local label = STAT_LABELS[key] or key
            love.graphics.setColor(0.7, 0.7, 0.7, self._alpha)
            love.graphics.print(label .. ":", cx, cy)
            love.graphics.setColor(1, 1, 1, self._alpha)
            love.graphics.print(tostring(val), cx + innerW - font:getWidth(tostring(val)), cy)
            cy = cy + fh
        end
    end

    -- Price
    love.graphics.setColor(1, 0.85, 0.20, self._alpha)
    love.graphics.print("$ " .. (data.price or 0), cx, cy)

    love.graphics.setColor(1, 1, 1, 1)
end

return CardTooltip
