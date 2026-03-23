-- ─────────────────────────────────────────────────────────────────────────────
--  card_fx.lua  –  Visual feedback effects for BroadcastDungeon card plays
--  Pure LÖVE graphics – no extra libs required.
--
--  Usage:
--    local CardFX = require("src/utils/card_fx")
--    local fx = CardFX.new()
--    fx:burst("great", x, y)    -- trigger a named effect at world position
--    fx:update(dt)
--    fx:draw()
-- ─────────────────────────────────────────────────────────────────────────────

local CardFX = {}
CardFX.__index = CardFX

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function lerp(a, b, t) return a + (b - a) * t end
local function randRange(lo, hi) return lo + love.math.random() * (hi - lo) end
local function randAngle() return love.math.random() * math.pi * 2 end

-- ── Effect palette ────────────────────────────────────────────────────────────

-- Each effect type drives one or more "emitters":
--   sparks  – fast moving point particles
--   orbs    – slow floating filled circles
--   ring    – expanding / fading stroke circle
--   flash   – full-screen overlay quad that decays immediately
--   wisp    – slow curving particles with sine drift
--   crack   – jagged line segments in random directions (drawn once, fade out)

local EFFECTS = {
    -------------------- ATTACK RESULTS --------------------
    great = {
        flash   = { color = { 1, 0.85, 0.1, 0.40 }, decay = 7 },
        ring    = { color = { 1, 0.85, 0.1 }, count = 2, maxR = 110, speed = 260, life = 0.55 },
        sparks  = { color = { 1, 0.85, 0.1 }, count = 28, speed = { 200, 420 }, life = { 0.4, 0.75 }, size = { 2.5, 5 } },
        sparks2 = { color = { 1, 1, 1 }, count = 10, speed = { 80, 180 }, life = { 0.2, 0.45 }, size = { 1.5, 3 } },
    },
    success = {
        sparks = { color = { 1, 0.55, 0.1 }, count = 14, speed = { 80, 220 }, life = { 0.3, 0.55 }, size = { 2, 4 } },
        ring   = { color = { 1, 0.6, 0.1 }, count = 1, maxR = 65, speed = 200, life = 0.35 },
    },
    miss = {
        sparks = { color = { 0.6, 0.6, 0.65 }, count = 8, speed = { 40, 110 }, life = { 0.25, 0.45 }, size = { 1.5, 3 } },
        orbs   = { color = { 0.5, 0.5, 0.55 }, count = 4, speed = { 20, 50 }, life = { 0.5, 0.9 }, size = { 3, 7 } },
    },
    -------------------- PARRY RESULTS --------------------
    shield = {
        ring   = { color = { 0.4, 0.75, 1 }, count = 2, maxR = 90, speed = 230, life = 0.5 },
        sparks = { color = { 0.6, 0.9, 1 }, count = 16, speed = { 60, 180 }, life = { 0.3, 0.6 }, size = { 2, 4 } },
        orbs   = { color = { 0.4, 0.7, 1 }, count = 5, speed = { 15, 50 }, life = { 0.5, 0.9 }, size = { 3, 6 } },
    },
    shield_miss = {
        sparks = { color = { 0.5, 0.5, 0.7 }, count = 6, speed = { 30, 90 }, life = { 0.2, 0.4 }, size = { 1.5, 3 } },
    },
    -------------------- HEALS --------------------
    heal = {
        orbs = { color = { 0.35, 1, 0.5 }, count = 12, speed = { 20, 70 }, life = { 0.6, 1.1 }, size = { 3, 8 }, rise = -70 },
        ring = { color = { 0.35, 1, 0.5 }, count = 1, maxR = 55, speed = 160, life = 0.45 },
    },
    -------------------- SPECIAL TRIGGERS --------------------
    lucky = {
        flash  = { color = { 1, 1, 0.2, 0.20 }, decay = 8 },
        sparks = { color = { 1, 1, 0.2 }, count = 22, speed = { 100, 280 }, life = { 0.3, 0.6 }, size = { 2, 4.5 } },
    },
    counter = {
        sparks = { color = { 1, 0.4, 0.1 }, count = 14, speed = { 90, 240 }, life = { 0.25, 0.5 }, size = { 2, 4 } },
        ring   = { color = { 1, 0.4, 0.1 }, count = 1, maxR = 70, speed = 210, life = 0.40 },
    },
    reflect = {
        flash  = { color = { 1, 1, 1, 0.25 }, decay = 9 },
        ring   = { color = { 1, 1, 1 }, count = 2, maxR = 80, speed = 250, life = 0.40 },
        sparks = { color = { 0.8, 0.9, 1 }, count = 12, speed = { 80, 200 }, life = { 0.2, 0.45 }, size = { 1.5, 3.5 } },
    },
    stun = {
        sparks = { color = { 1, 1, 0.1 }, count = 18, speed = { 80, 220 }, life = { 0.3, 0.55 }, size = { 2, 4 } },
        ring   = { color = { 1, 1, 0.1 }, count = 2, maxR = 75, speed = 220, life = 0.45 },
    },
    -------------------- ROUND-END SPECIALS --------------------
    echo = {
        flash  = { color = { 0.6, 0.3, 1, 0.25 }, decay = 7 },
        sparks = { color = { 0.8, 0.5, 1 }, count = 30, speed = { 120, 350 }, life = { 0.35, 0.65 }, size = { 2, 5 } },
        ring   = { color = { 0.7, 0.4, 1 }, count = 3, maxR = 130, speed = 280, life = 0.6 },
    },
    combo = {
        flash   = { color = { 1, 0.6, 0.1, 0.35 }, decay = 6 },
        sparks  = { color = { 1, 0.85, 0.1 }, count = 35, speed = { 150, 400 }, life = { 0.4, 0.8 }, size = { 2.5, 6 } },
        sparks2 = { color = { 1, 0.4, 0.1 }, count = 15, speed = { 80, 200 }, life = { 0.3, 0.6 }, size = { 1.5, 4 } },
        ring    = { color = { 1, 0.8, 0.1 }, count = 3, maxR = 150, speed = 320, life = 0.65 },
    },
    ghost = {
        wisp = { color = { 0.7, 0.4, 1 }, count = 14, speed = { 30, 90 }, life = { 0.6, 1.1 }, size = { 4, 9 } },
        ring = { color = { 0.5, 0.2, 1 }, count = 1, maxR = 70, speed = 150, life = 0.55 },
    },
    bleed = {
        sparks = { color = { 1, 0.1, 0.1 }, count = 14, speed = { 40, 120 }, life = { 0.35, 0.7 }, size = { 2, 5 }, gravity = 180 },
        orbs   = { color = { 0.8, 0.05, 0.05 }, count = 5, speed = { 10, 40 }, life = { 0.5, 0.9 }, size = { 3, 7 }, gravity = 200 },
    },
    bleed_tick = {
        sparks = { color = { 1, 0.1, 0.1 }, count = 8, speed = { 30, 90 }, life = { 0.3, 0.6 }, size = { 2, 4 }, gravity = 150 },
    },
    brew_heal = {
        orbs = { color = { 0.7, 0.3, 1 }, count = 10, speed = { 20, 60 }, life = { 0.6, 1.0 }, size = { 4, 9 }, rise = -60 },
        ring = { color = { 0.6, 0.2, 1 }, count = 1, maxR = 60, speed = 170, life = 0.45 },
    },
    brew_hurt = {
        sparks = { color = { 0.6, 0.1, 1 }, count = 12, speed = { 60, 160 }, life = { 0.25, 0.5 }, size = { 2, 4 } },
        ring   = { color = { 0.5, 0.05, 0.8 }, count = 1, maxR = 65, speed = 190, life = 0.40 },
        crack  = { color = { 0.7, 0.2, 1 }, count = 5 },
    },
    phoenix = {
        flash  = { color = { 1, 0.5, 0.05, 0.65 }, decay = 4 },
        ring   = { color = { 1, 0.6, 0.1 }, count = 4, maxR = 200, speed = 350, life = 0.80 },
        sparks = { color = { 1, 0.7, 0.1 }, count = 50, speed = { 100, 400 }, life = { 0.5, 1.0 }, size = { 2, 7 } },
        orbs   = { color = { 1, 0.4, 0.05 }, count = 18, speed = { 20, 80 }, life = { 0.7, 1.4 }, size = { 4, 10 }, rise = -120 },
    },
    penalty = {
        flash  = { color = { 1, 0.1, 0.1, 0.30 }, decay = 8 },
        crack  = { color = { 1, 0.2, 0.2 }, count = 6 },
        sparks = { color = { 1, 0.2, 0.2 }, count = 10, speed = { 60, 160 }, life = { 0.2, 0.45 }, size = { 1.5, 3 } },
    },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function CardFX.new()
    local self     = setmetatable({}, CardFX)
    self.particles = {}  -- active spark/orb/wisp particles
    self.rings     = {}  -- active expanding rings
    self.cracks    = {}  -- active crack line sets
    self._flash    = { alpha = 0, color = { 1, 1, 1 }, decay = 6 }
    return self
end

-- ── Spawn helpers ─────────────────────────────────────────────────────────────

local function spawnSparks(pool, def, x, y, isWisp)
    local c       = def.color
    local gravity = def.gravity or 0
    local rise    = def.rise or 0
    for _ = 1, def.count do
        local angle     = randAngle()
        local spd       = randRange(def.speed[1], def.speed[2])
        local life      = randRange(def.life[1], def.life[2])
        local size      = randRange(def.size[1], def.size[2])
        pool[#pool + 1] = {
            kind = isWisp and "wisp" or "spark",
            x = x + randRange(-12, 12),
            y = y + randRange(-12, 12),
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd + rise,
            life = life,
            maxLife = life,
            size = size,
            r = c[1],
            g = c[2],
            b = c[3],
            gravity = gravity,
            seed    = love.math.random() * 10, -- for wisp sine
        }
    end
end

local function spawnOrbs(pool, def, x, y)
    local c = def.color
    local rise = def.rise or 0
    for _ = 1, def.count do
        local angle     = randAngle()
        local spd       = randRange(def.speed[1], def.speed[2])
        local life      = randRange(def.life[1], def.life[2])
        local size      = randRange(def.size[1], def.size[2])
        pool[#pool + 1] = {
            kind = "orb",
            x = x + randRange(-15, 15),
            y = y + randRange(-15, 15),
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd + rise,
            life = life,
            maxLife = life,
            size = size,
            r = c[1],
            g = c[2],
            b = c[3],
            gravity = 0,
        }
    end
end

local function spawnRings(ringPool, def, x, y)
    local c = def.color
    local stagger = 0
    for _ = 1, (def.count or 1) do
        ringPool[#ringPool + 1] = {
            x = x,
            y = y,
            r = 0,
            maxR = def.maxR,
            speed = def.speed,
            life = def.life + stagger,
            maxLife = def.life + stagger,
            cr = c[1],
            cg = c[2],
            cb = c[3],
        }
        stagger = stagger + 0.06
    end
end

local function spawnCracks(crackPool, def, x, y)
    local c = def.color
    local lines = {}
    for _ = 1, def.count do
        local angle       = randAngle()
        local len         = randRange(18, 55)
        lines[#lines + 1] = {
            x1 = x,
            y1 = y,
            x2 = x + math.cos(angle) * len,
            y2 = y + math.sin(angle) * len,
        }
    end
    crackPool[#crackPool + 1] = {
        lines = lines,
        life = 0.40,
        maxLife = 0.40,
        cr = c[1],
        cg = c[2],
        cb = c[3],
    }
end

-- ── Public: trigger a named effect at (x, y) ─────────────────────────────────

function CardFX:burst(kind, x, y)
    local def = EFFECTS[kind]
    if not def then return end

    -- screen flash
    if def.flash then
        local f           = def.flash
        self._flash.alpha = math.min(1, self._flash.alpha + f.color[4])
        self._flash.color = { f.color[1], f.color[2], f.color[3] }
        self._flash.decay = f.decay
    end

    -- sparks (primary)
    if def.sparks then
        spawnSparks(self.particles, def.sparks, x, y, false)
    end
    -- sparks (secondary accent)
    if def.sparks2 then
        spawnSparks(self.particles, def.sparks2, x, y, false)
    end
    -- orbs
    if def.orbs then
        spawnOrbs(self.particles, def.orbs, x, y)
    end
    -- wisps
    if def.wisp then
        spawnSparks(self.particles, def.wisp, x, y, true)
    end
    -- rings
    if def.ring then
        spawnRings(self.rings, def.ring, x, y)
    end
    -- cracks
    if def.crack then
        spawnCracks(self.cracks, def.crack, x, y)
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function CardFX:update(dt)
    -- flash decay
    local fl = self._flash
    if fl.alpha > 0 then
        fl.alpha = math.max(0, fl.alpha - fl.decay * dt)
    end

    -- particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        else
            p.x  = p.x + p.vx * dt
            p.vy = p.vy + (p.gravity or 0) * dt
            p.y  = p.y + p.vy * dt
            -- friction
            p.vx = p.vx * (1 - dt * 2.5)
            if p.kind == "wisp" then
                -- sinusoidal drift
                p.x = p.x + math.sin(p.life * 5 + p.seed) * 30 * dt
            end
        end
    end

    -- rings
    for i = #self.rings, 1, -1 do
        local rg = self.rings[i]
        rg.life = rg.life - dt
        if rg.life <= 0 then
            table.remove(self.rings, i)
        else
            rg.r = rg.maxR * (1 - rg.life / rg.maxLife)
        end
    end

    -- cracks
    for i = #self.cracks, 1, -1 do
        local ck = self.cracks[i]
        ck.life = ck.life - dt
        if ck.life <= 0 then
            table.remove(self.cracks, i)
        end
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

function CardFX:draw()
    -- ── Screen flash ──────────────────────────────────────────────────────────
    local fl = self._flash
    if fl.alpha > 0.005 then
        love.graphics.setColor(fl.color[1], fl.color[2], fl.color[3], fl.alpha)
        love.graphics.rectangle("fill", 0, 0,
            love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- ── Rings ─────────────────────────────────────────────────────────────────
    love.graphics.setLineWidth(2.5)
    for _, rg in ipairs(self.rings) do
        local t = 1 - rg.life / rg.maxLife   -- 0→1 as it expands
        local a = (1 - t) * 0.85             -- fade out as it expands
        love.graphics.setColor(rg.cr, rg.cg, rg.cb, a)
        love.graphics.circle("line", rg.x, rg.y, rg.r)
    end
    love.graphics.setLineWidth(1)

    -- ── Cracks ────────────────────────────────────────────────────────────────
    love.graphics.setLineWidth(2)
    for _, ck in ipairs(self.cracks) do
        local a = (ck.life / ck.maxLife) * 0.9
        love.graphics.setColor(ck.cr, ck.cg, ck.cb, a)
        for _, ln in ipairs(ck.lines) do
            love.graphics.line(ln.x1, ln.y1, ln.x2, ln.y2)
        end
    end
    love.graphics.setLineWidth(1)

    -- ── Particles ─────────────────────────────────────────────────────────────
    for _, p in ipairs(self.particles) do
        local t = p.life / p.maxLife       -- 1→0 as it dies
        local a = math.min(1, t * 1.8)     -- fade out
        local s = p.size * (0.5 + t * 0.5) -- shrink over time

        love.graphics.setColor(p.r, p.g, p.b, a)
        if p.kind == "orb" or p.kind == "wisp" then
            love.graphics.circle("fill", p.x, p.y, s)
            -- inner bright core
            love.graphics.setColor(1, 1, 1, a * 0.35)
            love.graphics.circle("fill", p.x, p.y, s * 0.45)
        else
            -- spark: draw as a short line in direction of movement
            local spd = math.sqrt(p.vx * p.vx + p.vy * p.vy)
            if spd > 1 then
                local nx = p.vx / spd
                local ny = p.vy / spd
                local tail = math.min(s * 2.5, 12)
                love.graphics.setLineWidth(math.max(1, s * 0.6))
                love.graphics.line(
                    p.x - nx * tail, p.y - ny * tail,
                    p.x + nx * 2, p.y + ny * 2
                )
                love.graphics.setLineWidth(1)
            else
                love.graphics.circle("fill", p.x, p.y, s)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return CardFX
