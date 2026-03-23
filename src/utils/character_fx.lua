-- ─────────────────────────────────────────────────────────────────────────────
--  character_fx.lua  –  Per-character visual effects (shader + particles)
--  Manages idle / attack / damage visual states with smooth transitions.
--
--  Usage:
--    local CharacterFX = require("src/utils/character_fx")
--    local fx = CharacterFX.new({ color = {0.3, 0.7, 1.0} })
--    fx:setState("attack")
--    fx:update(dt)
--    fx:draw(x, y, w, h)
-- ─────────────────────────────────────────────────────────────────────────────

local CharacterFX = {}
CharacterFX.__index = CharacterFX

-- ── Shader (loaded once, shared across instances) ────────────────────────────
local _shader = nil
local function getShader()
    if not _shader then
        local code = love.filesystem.read("assets/shaders/character.glsl")
        if code then
            _shader = love.graphics.newShader(code)
        end
    end
    return _shader
end

-- ── State enum → numeric value for shader interpolation ──────────────────────
local STATE_NUM = { idle = 0, attack = 1, damage = 2 }

-- ── Particle config ──────────────────────────────────────────────────────────
local PARTICLE = {
    idleCount   = 6,
    idleSpeed   = 18,
    idleRadius  = 40,
    idleSize    = { 2, 4 },
    idleAlpha   = 0.45,

    attackCount = 10,
    attackSpeed = 180,
    attackLife  = 0.35,
    attackSize  = { 2, 5 },

    damageCount = 8,
    damageSpeed = 150,
    damageLife  = 0.4,
    damageSize  = { 3, 6 },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  Constructor
-- ─────────────────────────────────────────────────────────────────────────────
function CharacterFX.new(cfg)
    cfg                = cfg or {}
    local self         = setmetatable({}, CharacterFX)

    -- Energy color (vec3)
    self.color         = cfg.color or { 0.3, 0.7, 1.0 }
    self.intensity     = cfg.intensity or 1.0
    self.isBoss        = cfg.isBoss or false

    -- State
    self.state         = "idle"
    self.stateNum      = 0                    -- current interpolated state value
    self.targetState   = 0                    -- target state value
    self.transSpeed    = cfg.transSpeed or 6.0 -- interpolation speed

    -- Damage flash
    self.damageFlash   = 0
    self.damageDecay   = 5.0 -- how fast the red flash fades

    -- Time accumulator
    self._time         = love.math.random() * 100

    -- Idle particles (orbit around character)
    self.idleParticles = {}
    for i = 1, PARTICLE.idleCount do
        table.insert(self.idleParticles, {
            angle  = (i / PARTICLE.idleCount) * math.pi * 2,
            radius = PARTICLE.idleRadius + love.math.random() * 15,
            speed  = PARTICLE.idleSpeed * (0.7 + love.math.random() * 0.6),
            size   = PARTICLE.idleSize[1] + love.math.random() * (PARTICLE.idleSize[2] - PARTICLE.idleSize[1]),
            phase  = love.math.random() * math.pi * 2,
        })
    end

    -- Burst particles (attack / damage one-shot effects)
    self.burstParticles = {}

    -- Breathing scale for idle bob
    self._breathe = 0

    return self
end

-- ─────────────────────────────────────────────────────────────────────────────
--  State management
-- ─────────────────────────────────────────────────────────────────────────────
function CharacterFX:setState(state)
    if state == self.state then return end
    self.state = state
    self.targetState = STATE_NUM[state] or 0

    if state == "damage" then
        self.damageFlash = 1.0
        self:_spawnDamageBurst()
    elseif state == "attack" then
        self:_spawnAttackBurst()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Burst spawn helpers
-- ─────────────────────────────────────────────────────────────────────────────
function CharacterFX:_spawnAttackBurst()
    for i = 1, PARTICLE.attackCount do
        local angle = (love.math.random() * 0.6 - 0.3) -- forward direction ±30°
        local spd   = PARTICLE.attackSpeed * (0.5 + love.math.random() * 0.8)
        table.insert(self.burstParticles, {
            ox    = 0,
            oy    = 0,
            vx    = math.cos(angle) * spd,
            vy    = math.sin(angle) * spd - 40,
            life  = PARTICLE.attackLife * (0.6 + love.math.random() * 0.8),
            max   = PARTICLE.attackLife,
            size  = PARTICLE.attackSize[1] + love.math.random() * (PARTICLE.attackSize[2] - PARTICLE.attackSize[1]),
            color = { self.color[1] * 1.5, self.color[2] * 1.5, self.color[3] * 1.5 },
        })
    end
end

function CharacterFX:_spawnDamageBurst()
    for i = 1, PARTICLE.damageCount do
        local angle = love.math.random() * math.pi * 2
        local spd   = PARTICLE.damageSpeed * (0.4 + love.math.random() * 0.8)
        table.insert(self.burstParticles, {
            ox    = 0,
            oy    = 0,
            vx    = math.cos(angle) * spd,
            vy    = math.sin(angle) * spd - 30,
            life  = PARTICLE.damageLife * (0.5 + love.math.random() * 0.8),
            max   = PARTICLE.damageLife,
            size  = PARTICLE.damageSize[1] + love.math.random() * (PARTICLE.damageSize[2] - PARTICLE.damageSize[1]),
            color = { 1.0, 0.25, 0.15 },
        })
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Update
-- ─────────────────────────────────────────────────────────────────────────────
function CharacterFX:update(dt)
    self._time = self._time + dt
    self._breathe = self._breathe + dt

    -- Smooth state interpolation
    local diff = self.targetState - self.stateNum
    if math.abs(diff) > 0.01 then
        self.stateNum = self.stateNum + diff * self.transSpeed * dt
    else
        self.stateNum = self.targetState
    end

    -- Damage flash decay
    if self.damageFlash > 0 then
        self.damageFlash = math.max(0, self.damageFlash - self.damageDecay * dt)
    end

    -- Update idle particles (orbital)
    for _, p in ipairs(self.idleParticles) do
        p.angle = p.angle + p.speed * dt * 0.02
    end

    -- Update burst particles
    for i = #self.burstParticles, 1, -1 do
        local p = self.burstParticles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.burstParticles, i)
        else
            p.ox = p.ox + p.vx * dt
            p.oy = p.oy + p.vy * dt
            p.vy = p.vy + 200 * dt -- gravity
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw
-- ─────────────────────────────────────────────────────────────────────────────
function CharacterFX:draw(x, y, w, h)
    local shader = getShader()
    local cx, cy = x + w / 2, y + h / 2

    -- ── Idle breathing scale ──
    local breatheScale = 1.0 + math.sin(self._breathe * 1.8) * 0.015
    local drawW = w * breatheScale
    local drawH = h * breatheScale
    local drawX = cx - drawW / 2
    local drawY = cy - drawH / 2

    -- ── Damage jitter ──
    local jitterX, jitterY = 0, 0
    if self.damageFlash > 0.1 then
        local jAmt = self.damageFlash * 4
        jitterX = (love.math.random() * 2 - 1) * jAmt
        jitterY = (love.math.random() * 2 - 1) * jAmt
    end
    drawX = drawX + jitterX
    drawY = drawY + jitterY

    -- ── Draw ambient glow behind character ──
    local glowAlpha = 0.08 + 0.04 * math.sin(self._time * 2)
    if self.state == "attack" then glowAlpha = glowAlpha + 0.06 end
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], glowAlpha)
    love.graphics.rectangle("fill", drawX - 8, drawY - 8, drawW + 16, drawH + 16, 6, 6)

    -- ── Draw character with shader ──
    if shader then
        love.graphics.setShader(shader)
        shader:send("time", self._time)
        shader:send("state", self.stateNum)
        shader:send("baseColor", self.color)
        shader:send("intensity", self.intensity)
        shader:send("damageFlash", self.damageFlash)
        shader:send("isBoss", self.isBoss and 1.0 or 0.0)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", drawX, drawY, drawW, drawH, 3, 3)

    if shader then
        love.graphics.setShader()
    end

    -- ── Energy border (replaces old red border) ──
    local borderAlpha = 0.6 + 0.3 * math.sin(self._time * 3)
    if self.state == "attack" then borderAlpha = 1.0 end
    if self.damageFlash > 0.1 then
        love.graphics.setColor(1, 0.2, 0.15, borderAlpha)
    else
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], borderAlpha)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", drawX, drawY, drawW, drawH, 3, 3)
    love.graphics.setLineWidth(1)

    -- ── Idle orbital particles ──
    if self.state == "idle" or self.stateNum < 0.5 then
        for _, p in ipairs(self.idleParticles) do
            local px = cx + math.cos(p.angle) * p.radius
            local py = cy + math.sin(p.angle) * p.radius * 0.6
            local floatY = math.sin(self._time * 1.2 + p.phase) * 4
            local alpha = PARTICLE.idleAlpha * (0.5 + 0.5 * math.sin(self._time * 2 + p.phase))
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
            love.graphics.circle("fill", px, py + floatY, p.size)
        end
    end

    -- ── Burst particles ──
    for _, p in ipairs(self.burstParticles) do
        local t = p.life / p.max
        local alpha = t
        local size = p.size * t
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", cx + p.ox, cy + p.oy, size)
    end

    -- ── Reset color ──
    love.graphics.setColor(1, 1, 1, 1)
end

return CharacterFX
