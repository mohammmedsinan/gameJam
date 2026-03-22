-- ─────────────────────────────────────────────────────────────────────────────
--  StatsPanel – top-left corner HUD for BroadcastDungeon
--  Dungeon dark theme  ·  brass accent border  ·  crisp pixel-style stats
-- ─────────────────────────────────────────────────────────────────────────────

local StatsPanel   = {}
StatsPanel.__index = StatsPanel

-- ── palette ──────────────────────────────────────────────────────────────────
local C            = {
    bg        = { 0.07, 0.07, 0.09, 0.92 }, -- near-black panel
    border    = { 0.85, 0.55, 0.10, 1.00 }, -- warm brass
    borderDim = { 0.55, 0.35, 0.06, 0.60 }, -- inner-shadow trim
    title     = { 0.95, 0.80, 0.35, 1.00 }, -- gold title
    label     = { 0.55, 0.55, 0.65, 1.00 }, -- muted label
    value     = { 0.95, 0.92, 0.85, 1.00 }, -- off-white value
    -- health bar
    hpBg      = { 0.18, 0.07, 0.07, 1.00 },
    hpFill    = { 0.82, 0.18, 0.18, 1.00 },
    hpHigh    = { 0.95, 0.30, 0.30, 1.00 },
    hpLow     = { 0.60, 0.10, 0.10, 1.00 },
    hpText    = { 1.00, 0.88, 0.88, 1.00 },
    -- level badge
    lvlBg     = { 0.85, 0.55, 0.10, 1.00 },
    lvlText   = { 0.08, 0.06, 0.04, 1.00 },
    -- accent divider
    divider   = { 0.85, 0.55, 0.10, 0.25 },
    -- gold
    gold      = { 1.00, 0.80, 0.20, 1.00 },
    -- stat icons bg
    iconBg    = { 0.14, 0.14, 0.17, 0.80 },
}

-- ── layout constants ─────────────────────────────────────────────────────────
local PADDING      = 12
local PANEL_W      = 190
local PANEL_H      = 230
local MARGIN_TOP   = 14  -- gap from screen edge
local MARGIN_LEFT  = 14
local CORNER_R     = 7
local BAR_H        = 10
local ROW_H        = 26
local ICON_SIZE    = 18
local ANIM_SPEED   = 4.0  -- health bar lerp speed

-- ── stat rows definition  (icon char, label, player field) ───────────────────
local STAT_ROWS    = {
    { icon = "⚔", label = "Attack", field = "attack" },
    { icon = "🗡", label = "Damage", field = "damage" },
    { icon = "🛡", label = "Defence", field = "defence" },
}

-- ─────────────────────────────────────────────────────────────────────────────
function StatsPanel.new()
    local self      = setmetatable({}, StatsPanel)
    self.x          = MARGIN_LEFT
    self.y          = MARGIN_TOP
    self.w          = PANEL_W
    self.h          = PANEL_H
    -- animated HP bar (lerps towards real value)
    self.hpAnim     = 1.0 -- 0..1 fraction
    -- subtle pulse for low health
    self.pulseTimer = 0
    -- entrance animation: slides in from left
    self.slideX     = -PANEL_W - 10
    self.slideReady = false
    return self
end

-- ─────────────────────────────────────────────────────────────────────────────
function StatsPanel:update(dt)
    -- slide-in entrance
    if not self.slideReady then
        self.slideX = self.slideX + (self.x - self.slideX) * math.min(1, dt * 8)
        if math.abs(self.slideX - self.x) < 0.5 then
            self.slideX     = self.x
            self.slideReady = true
        end
    end

    self.pulseTimer = self.pulseTimer + dt

    -- lerp health bar
    if player then
        local targetFrac = player.health / math.max(1, player.maxHealth)
        self.hpAnim = self.hpAnim + (targetFrac - self.hpAnim) * math.min(1, dt * ANIM_SPEED)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
function StatsPanel:draw()
    if not player then return end

    local px = math.floor(self.slideX)
    local py = self.y

    love.graphics.push("all")

    -- ── drop shadow ──────────────────────────────────────────────────────────
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", px + 4, py + 4, self.w, self.h, CORNER_R, CORNER_R)

    -- ── panel background ─────────────────────────────────────────────────────
    love.graphics.setColor(C.bg)
    love.graphics.rectangle("fill", px, py, self.w, self.h, CORNER_R, CORNER_R)

    -- ── inner border (dim) ───────────────────────────────────────────────────
    love.graphics.setColor(C.borderDim)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 2, py + 2, self.w - 4, self.h - 4, CORNER_R - 1, CORNER_R - 1)

    -- ── outer border (brass) ─────────────────────────────────────────────────
    love.graphics.setColor(C.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, self.w, self.h, CORNER_R, CORNER_R)
    love.graphics.setLineWidth(1)

    local cx     = px + PADDING -- content left edge
    local cy     = py + PADDING -- content top

    -- ── level badge ──────────────────────────────────────────────────────────
    local lvlStr = tostring(player.level)
    local badgeW = 36
    local badgeH = 18
    local badgeX = px + self.w - PADDING - badgeW
    local badgeY = cy - 1
    love.graphics.setColor(C.lvlBg)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 4, 4)
    love.graphics.setColor(C.lvlText)
    love.graphics.setFont(love.graphics.newFont(10))
    local lvlLabel = "LV " .. lvlStr
    local lw = love.graphics.getFont():getWidth(lvlLabel)
    love.graphics.print(lvlLabel, badgeX + (badgeW - lw) / 2, badgeY + 3)

    -- ── title ─────────────────────────────────────────────────────────────────
    love.graphics.setColor(C.title)
    love.graphics.setFont(love.graphics.newFont(13))
    love.graphics.print("⚰  DUNGEON HERO", cx, cy)
    cy = cy + 22

    -- ── divider ──────────────────────────────────────────────────────────────
    love.graphics.setColor(C.divider)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + 6, cy, px + self.w - 6, cy)
    cy           = cy + 8

    -- ── health bar ───────────────────────────────────────────────────────────
    local hpFrac = self.hpAnim
    local barW   = self.w - PADDING * 2
    local barX   = cx
    local barY   = cy + 12

    -- label row
    love.graphics.setColor(C.label)
    love.graphics.setFont(love.graphics.newFont(9))
    love.graphics.print("HEALTH", barX, cy)
    local hpStr = player.health .. " / " .. player.maxHealth
    love.graphics.setColor(C.hpText)
    local hpW = love.graphics.getFont():getWidth(hpStr)
    love.graphics.print(hpStr, barX + barW - hpW, cy)

    -- bar background
    love.graphics.setColor(C.hpBg)
    love.graphics.rectangle("fill", barX, barY, barW, BAR_H, 3, 3)

    -- bar fill (colour shifts red → dark at low health)
    local fillW = math.max(0, barW * hpFrac)
    if fillW > 0 then
        -- low-health pulse
        local pulse = 1.0
        if hpFrac < 0.3 then
            pulse = 0.75 + 0.25 * math.sin(self.pulseTimer * 6)
        end
        local r = C.hpFill[1] * pulse
        local g = C.hpFill[2]
        local b = C.hpFill[3]
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", barX, barY, fillW, BAR_H, 3, 3)

        -- bright highlight strip on top third of bar
        love.graphics.setColor(1, 0.6, 0.6, 0.25)
        love.graphics.rectangle("fill", barX, barY, fillW, 3, 3, 3)
    end

    -- bar border
    love.graphics.setColor(C.border[1], C.border[2], C.border[3], 0.5)
    love.graphics.rectangle("line", barX, barY, barW, BAR_H, 3, 3)

    cy = barY + BAR_H + 10

    -- ── divider ──────────────────────────────────────────────────────────────
    love.graphics.setColor(C.divider)
    love.graphics.line(px + 6, cy, px + self.w - 6, cy)
    cy = cy + 8

    -- ── stat rows ────────────────────────────────────────────────────────────
    love.graphics.setFont(love.graphics.newFont(10))
    for _, row in ipairs(STAT_ROWS) do
        self:_drawStatRow(cx, cy, barW, row)
        cy = cy + ROW_H
    end

    -- ── divider ──────────────────────────────────────────────────────────────
    love.graphics.setColor(C.divider)
    love.graphics.line(px + 6, cy, px + self.w - 6, cy)
    cy = cy + 8

    -- ── gold row ─────────────────────────────────────────────────────────────
    love.graphics.setFont(love.graphics.newFont(11))
    -- icon bg
    love.graphics.setColor(C.iconBg)
    love.graphics.rectangle("fill", cx, cy, ICON_SIZE, ICON_SIZE, 3, 3)
    love.graphics.setColor(C.gold)
    love.graphics.print("✦", cx + 3, cy + 1) -- coin glyph
    -- label
    love.graphics.setColor(C.label)
    love.graphics.setFont(love.graphics.newFont(9))
    love.graphics.print("GOLD", cx + ICON_SIZE + 6, cy + 1)
    -- value
    local goldVal = tostring(player.gold or 0)
    love.graphics.setColor(C.gold)
    love.graphics.setFont(love.graphics.newFont(11))
    local gw = love.graphics.getFont():getWidth(goldVal)
    love.graphics.print(goldVal, cx + barW - gw, cy)

    love.graphics.pop()
end

-- ── private: draw one stat row ───────────────────────────────────────────────
function StatsPanel:_drawStatRow(cx, cy, barW, row)
    local val = tostring(player[row.field] or 0)

    -- icon bubble
    love.graphics.setColor(C.iconBg)
    love.graphics.rectangle("fill", cx, cy + 2, ICON_SIZE, ICON_SIZE, 3, 3)
    love.graphics.setColor(C.border)
    love.graphics.setFont(love.graphics.newFont(9))
    local iw = love.graphics.getFont():getWidth(row.icon)
    love.graphics.print(row.icon, cx + (ICON_SIZE - iw) / 2, cy + 4)

    -- label
    love.graphics.setColor(C.label)
    love.graphics.setFont(love.graphics.newFont(9))
    love.graphics.print(string.upper(row.label), cx + ICON_SIZE + 6, cy + 5)

    -- value (right-aligned)
    love.graphics.setColor(C.value)
    love.graphics.setFont(love.graphics.newFont(11))
    local vw = love.graphics.getFont():getWidth(val)
    love.graphics.print(val, cx + barW - vw, cy + 4)
end

return StatsPanel
