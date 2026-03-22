local love = require("love")

local EquipmentItem = {}
EquipmentItem.__index = EquipmentItem

local RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS = {
    { 0.65, 0.68, 0.72, 1 },
    { 0.20, 0.78, 0.40, 1 },
    { 0.20, 0.50, 1.00, 1 },
    { 0.60, 0.20, 0.90, 1 },
    { 1.00, 0.72, 0.10, 1 },
}
local RARITY_BG_COLORS = {
    { 0.18, 0.19, 0.22, 1 },
    { 0.10, 0.22, 0.14, 1 },
    { 0.08, 0.14, 0.28, 1 },
    { 0.18, 0.08, 0.28, 1 },
    { 0.28, 0.18, 0.06, 1 },
}

local SHADER_FILES = {
    "assets/shaders/common.glsl",
    "assets/shaders/uncommon.glsl",
    "assets/shaders/rare.glsl",
    "assets/shaders/epic.glsl",
    "assets/shaders/legendary.glsl",
}

local SLOT_ICONS = {
    hands = "H",
    accessory = "A",
    armor = "M",
    weapon = "W"
}

local DEFAULT_SIZE = 64
local CORNER_RADIUS = 8
local HOVER_SCALE = 1.2
local SELECT_SCALE = 1.10
local HOVER_LIFT = 10
local HOVER_DELAY = 0.10
local IDLE_FLOAT_AMP = 1.0
local IDLE_FLOAT_SPEED = 2.0

local SPRING_STIFF = 92
local SPRING_DAMP = 0.70

local _shaderCache = {}

local function getShader(rarity)
    rarity = math.max(1, math.min(5, rarity or 1))
    if _shaderCache[rarity] then return _shaderCache[rarity] end
    local path = SHADER_FILES[rarity]
    local ok, shader = pcall(love.graphics.newShader, path)
    if ok then
        _shaderCache[rarity] = shader
        return shader
    else
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

local function springLerp(current, target, velocity, stiffness, damping, dt)
    local force = (target - current) * stiffness
    velocity = (velocity + force * dt) * math.pow(damping, dt * 60)
    current = current + velocity * dt
    return current, velocity
end

function EquipmentItem.new(data)
    data = data or {}
    local self = setmetatable({}, EquipmentItem)

    self.id = data.id or 0
    self.name = data.name or "Equipment"
    self.price = data.price or 0
    self.slot = data.slot or "accessory"
    self.description = data.description or ""
    self.rarity = math.max(1, math.min(5, data.rarity or 1))
    self.stats = data.stats or {}

    self.x = 0
    self.xVel = 0
    self.y = 0
    self.yVel = 0
    self.baseX = 0
    self.baseY = 0
    self.width = DEFAULT_SIZE
    self.height = DEFAULT_SIZE
    self.rotation = 0
    self.baseRotation = 0

    self.scale = 1.0
    self.scaleVel = 0
    self.targetScale = 1.0
    self.liftY = 0
    self.liftYVel = 0
    self.targetLiftY = 0
    self.tiltX = 0
    self.tiltXVel = 0
    self.targetTiltX = 0
    self.glowAlpha = 0
    self.glowAlphaVel = 0
    self.targetGlowAlpha = 0

    self.hovered = false
    self.selected = false
    self.dragging = false
    self._dragOffsetX = 0
    self._dragOffsetY = 0
    self.hoverTime = 0
    self.tooltipReady = false
    self.visible = true
    self.enabled = true
    self.zIndex = 0

    self.badgeAlpha = 0
    self.badgeAlphaVel = 0
    self.targetBadgeAlpha = 0
    self.badgeOffsetY = 0
    self.badgeOffsetYVel = 0
    self.targetBadgeOffsetY = 0

    self._time = love.math.random() * 100
    self._idleOffset = love.math.random() * math.pi * 2

    self._canvas = nil
    self._canvasDirty = true

    self.onClick = nil
    self.onHover = nil
    self.onSelect = nil
    self.onTooltip = nil

    return self
end

function EquipmentItem:setPosition(x, y)
    self.baseX = x
    self.baseY = y
    if self.x == 0 and self.y == 0 then
        self.x = x
        self.y = y
    end
end

function EquipmentItem:setScale(s)
    self.targetScale = s
    self.scale = s
end

function EquipmentItem:setRotation(r)
    self.baseRotation = r
    self.rotation = r
end

function EquipmentItem:setSize(w, h)
    self.width = w
    self.height = h
    self._canvasDirty = true
end

function EquipmentItem:containsPoint(px, py)
    if not self.visible then return false end
    local cx = self.x
    local cy = self.y - self.liftY
    local hw = (self.width * self.scale) / 2
    local hh = (self.height * self.scale) / 2
    return px >= cx - hw and px <= cx + hw and py >= cy - hh and py <= cy + hh
end

function EquipmentItem:mousemoved(mx, my, dx, dy)
    if not self.enabled then return end
    local wasHovered = self.hovered
    self.hovered = self:containsPoint(mx, my)

    if self.hovered then
        local cx = self.x
        local relX = (mx - cx) / (self.width * self.scale * 0.5)
        self.targetTiltX = relX * 0.08
    else
        self.targetTiltX = 0
    end

    if self.hovered ~= wasHovered then
        self.hoverTime = 0
        self.tooltipReady = false
        if self.hovered then
            self.targetScale = HOVER_SCALE
            self.targetLiftY = HOVER_LIFT
            self.targetGlowAlpha = 1.0
            self.targetBadgeAlpha = 1.0
            self.targetBadgeOffsetY = 25
        else
            self.targetScale = 1.0
            self.targetLiftY = 0
            self.targetGlowAlpha = 0.0
            self.targetBadgeAlpha = 0.0
            self.targetBadgeOffsetY = 0
        end
        if self.onHover then self.onHover(self, self.hovered) end
    end
end

function EquipmentItem:mousepressed(mx, my, button)
    if not self.enabled then return false end
    if button == 1 and self:containsPoint(mx, my) then
        self.scale = 0.8
        self.selected = not self.selected
        if self.onSelect then self.onSelect(self, self.selected) end
        if self.onClick then self.onClick(self) end
        return true
    end
    return false
end

function EquipmentItem:startDrag(mx, my)
    self.dragging = true
    self._dragOffsetX = self.x - mx
    self._dragOffsetY = self.y - my
end

function EquipmentItem:stopDrag()
    self.dragging = false
end

function EquipmentItem:mousereleased(mx, my, button)
end

function EquipmentItem:update(dt, mx, my)
    if not self.visible then return end
    self._time = self._time + dt

    if mx and my then
        self:mousemoved(mx, my, 0, 0)
    end

    if self.hovered then
        self.hoverTime = self.hoverTime + dt
        if self.hoverTime >= HOVER_DELAY and not self.tooltipReady then
            self.tooltipReady = true
            if self.onTooltip then
                self.onTooltip(self, true, self.x, self.y - self.liftY - self.height * self.scale * 0.5)
            end
        end
    end

    self.scale, self.scaleVel = springLerp(self.scale, self.targetScale, self.scaleVel, SPRING_STIFF, SPRING_DAMP, dt)
    self.liftY, self.liftYVel = springLerp(self.liftY, self.targetLiftY, self.liftYVel, SPRING_STIFF, SPRING_DAMP, dt)
    self.tiltX, self.tiltXVel = springLerp(self.tiltX, self.targetTiltX, self.tiltXVel, SPRING_STIFF, SPRING_DAMP, dt)
    self.glowAlpha, self.glowAlphaVel = springLerp(self.glowAlpha, self.targetGlowAlpha, self.glowAlphaVel, 8, 0.75, dt)
    self.badgeAlpha, self.badgeAlphaVel = springLerp(self.badgeAlpha, self.targetBadgeAlpha, self.badgeAlphaVel,
        SPRING_STIFF, SPRING_DAMP, dt)
    self.badgeOffsetY, self.badgeOffsetYVel = springLerp(self.badgeOffsetY, self.targetBadgeOffsetY, self
    .badgeOffsetYVel, SPRING_STIFF, SPRING_DAMP, dt)

    local targetX = self.baseX
    local targetY = self.baseY - self.liftY

    if self.dragging then
        targetX = (mx or self.baseX) + self._dragOffsetX
        targetY = (my or self.baseY) + self._dragOffsetY
    else
        local idleFloat = math.sin(self._time * IDLE_FLOAT_SPEED + self._idleOffset) * IDLE_FLOAT_AMP
        targetY = targetY + idleFloat
    end

    self.x, self.xVel = springLerp(self.x, targetX, self.xVel, SPRING_STIFF, SPRING_DAMP, dt)
    self.y, self.yVel = springLerp(self.y, targetY, self.yVel, SPRING_STIFF, SPRING_DAMP, dt)

    self.rotation = self.baseRotation + self.tiltX
end

function EquipmentItem:_ensureCanvas()
    if self._canvas and not self._canvasDirty then return end
    local cw = self.width + 20
    local ch = self.height + 20
    self._canvas = love.graphics.newCanvas(cw, ch)
    self._canvasDirty = false
end

function EquipmentItem:_renderFace()
    self:_ensureCanvas()
    local cw, ch = self._canvas:getDimensions()
    local ox, oy = 10, 10

    love.graphics.setCanvas(self._canvas)
    love.graphics.clear(0, 0, 0, 0)

    local bg = RARITY_BG_COLORS[self.rarity] or { 0.15, 0.15, 0.18, 1 }
    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)

    love.graphics.setColor(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1)
    local artMargin = 6
    love.graphics.rectangle("fill", ox + artMargin, oy + artMargin, self.width - artMargin * 2,
        self.height - artMargin * 2, 4, 4)

    local icon = SLOT_ICONS[self.slot] or "E"
    local rc = RARITY_COLORS[self.rarity]
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
    local iconFont = getFont(32)
    love.graphics.setFont(iconFont)
    local iconW = iconFont:getWidth(icon)
    love.graphics.print(icon, ox + self.width / 2 - iconW / 2, oy + self.height / 2 - iconFont:getHeight() / 2)

    love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ox, oy, self.width, self.height, CORNER_RADIUS, CORNER_RADIUS)
    love.graphics.setLineWidth(1)

    love.graphics.setCanvas()
end

function EquipmentItem:draw()
    if not self.visible then return end

    self:_renderFace()
    local cw, ch = self._canvas:getDimensions()

    local shader = getShader(self.rarity)
    if shader then
        shader:send("time", self._time)
        if shader:hasUniform("cardSize") then
            shader:send("cardSize", { self.width, self.height })
        end
        love.graphics.setShader(shader)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self._canvas,
        self.x, self.y,
        self.rotation,
        self.scale, self.scale,
        cw / 2, ch / 2
    )
    love.graphics.setShader()

    if self.glowAlpha > 0.01 then
        local rc = RARITY_COLORS[self.rarity]
        love.graphics.setColor(rc[1], rc[2], rc[3], self.glowAlpha * 0.3)
        local glowRad = 4 * self.scale
        love.graphics.rectangle("line",
            self.x - (self.width * self.scale) / 2 - glowRad,
            self.y - (self.height * self.scale) / 2 - glowRad,
            self.width * self.scale + glowRad * 2,
            self.height * self.scale + glowRad * 2,
            CORNER_RADIUS + 2, CORNER_RADIUS + 2
        )
    end
    if self.badgeAlpha > 0.01 then
        local sellValue = math.floor(self.price / 2)
        local font = getFont(14)
        local sellText = "Sell $" .. sellValue
        local sw = font:getWidth(sellText)
        local sh = font:getHeight()
        local padX = 8
        local padY = 4

        local bx = self.x - (sw + padX * 2) / 2
        local by = self.y - self.height * self.scale / 2 - self.badgeOffsetY - sh - padY * 2

        love.graphics.setColor(0.1, 0.1, 0.1, self.badgeAlpha * 0.9)
        love.graphics.rectangle("fill", bx, by, sw + padX * 2, sh + padY * 2, 4, 4)

        love.graphics.setColor(1, 0.1, 0.1, self.badgeAlpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx, by, sw + padX * 2, sh + padY * 2, 4, 4)

        love.graphics.setFont(font)
        love.graphics.setColor(1, 0.5, 0.2, self.badgeAlpha)
        love.graphics.print(sellText, bx + padX, by + padY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return EquipmentItem
