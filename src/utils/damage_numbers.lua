-- damage_numbers.lua
-- Juicy, impactful floating damage numbers for LÖVE 2D
--
-- Features:
--   • Trauma-scaled size   — big hits spawn BIG numbers
--   • Punch-in / ease-out  — scale from 0→ overshoot → settle → float up → fade
--   • Wobbly arc travel    — numbers drift with slight horizontal wander
--   • Chromatic split      — critical hits get a coloured shadow offset
--   • Screen-flash pulse   — optional white flash on crits
--   • Number types         — NORMAL, CRIT, HEAL, MISS, SHIELD, XP
--
-- Usage:
--   local DamageNumbers = require("damage_numbers")
--   local dmg = DamageNumbers.new()
--
--   dmg:spawn(x, y, 150)                          -- normal hit
--   dmg:spawn(x, y, 450, "crit")                  -- critical
--   dmg:spawn(x, y,  80, "heal")                  -- healing (green)
--   dmg:spawn(x, y,   0, "miss")                  -- miss
--   dmg:spawn(x, y, 200, "shield")                -- blocked
--   dmg:spawn(x, y,  25, "xp")                    -- experience
--
--   dmg:update(dt)                                -- in love.update
--   dmg:draw()                                    -- in love.draw (after shake:pop so HUD is stable, OR before to shake with world)

local DamageNumbers = {}
DamageNumbers.__index = DamageNumbers

-- ── Easing helpers ────────────────────────────────────────────────────────

local function lerp(a, b, t) return a + (b - a) * t end

-- Smooth cubic ease out
local function ease_out(t) return 1 - (1 - t) ^ 3 end

-- Elastic overshoot for the "punch-in" scale
local function elastic_out(t)
	if t == 0 or t == 1 then return t end
	local c4 = (2 * math.pi) / 2.8
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

-- ── Type definitions ──────────────────────────────────────────────────────

local TYPES = {
	normal = {
		color      = { 1.00, 1.00, 1.00 },
		shadow     = { 0.15, 0.15, 0.15 },
		base_scale = 1.0,
		lifetime   = 1.1,
		rise       = 90, -- pixels to travel upward
		wobble     = 18, -- horizontal wander amplitude
		chromatic  = false,
		flash      = false,
	},
	crit = {
		color      = { 1.00, 0.85, 0.10 },
		shadow     = { 0.75, 0.10, 0.00 },
		base_scale = 1.65,
		lifetime   = 1.45,
		rise       = 230,
		wobble     = 28,
		chromatic  = true, -- split shadow offset for crit
		flash      = true, -- screen flash
	},
	heal = {
		color      = { 0.35, 1.00, 0.50 },
		shadow     = { 0.05, 0.40, 0.15 },
		base_scale = 0.95,
		lifetime   = 1.1,
		rise       = 80,
		wobble     = 12,
		chromatic  = false,
		flash      = false,
	},
	miss = {
		color      = { 0.75, 0.75, 0.75 },
		shadow     = { 0.20, 0.20, 0.20 },
		base_scale = 0.75,
		lifetime   = 0.9,
		rise       = 55,
		wobble     = 8,
		chromatic  = false,
		flash      = false,
	},
	shield = {
		color      = { 0.45, 0.75, 1.00 },
		shadow     = { 0.05, 0.20, 0.55 },
		base_scale = 1.0,
		lifetime   = 1.1,
		rise       = 75,
		wobble     = 14,
		chromatic  = false,
		flash      = false,
	},
	xp = {
		color      = { 0.80, 0.55, 1.00 },
		shadow     = { 0.25, 0.05, 0.50 },
		base_scale = 0.80,
		lifetime   = 1.3,
		rise       = 70,
		wobble     = 10,
		chromatic  = false,
		flash      = false,
	},
}

-- ── Constructor ───────────────────────────────────────────────────────────

function DamageNumbers.new(cfg)
	cfg               = cfg or {}
	local self        = setmetatable({}, DamageNumbers)

	self.numbers      = {}
	self.font_size    = cfg.font_size or 32 -- base font size (pixels)
	self.font         = love.graphics.newFont(cfg.font_size or 32)

	-- Screen flash state (for crits)
	self._flash_alpha = 0
	self._flash_decay = cfg.flash_decay or 5.0 -- alpha units per second

	return self
end

-- ── Spawn ─────────────────────────────────────────────────────────────────

---Spawn a damage number.
---@param x      number   World/screen X position
---@param y      number   World/screen Y position
---@param amount number   Damage value (0 for miss)
---@param kind   string   "normal"|"crit"|"heal"|"miss"|"shield"|"xp"
---@param opts   table|nil  { prefix="", suffix="", damage_scale=1 }
function DamageNumbers:spawn(x, y, amount, kind, opts)
	kind = kind or "normal"
	opts = opts or {}
	local def = TYPES[kind] or TYPES.normal

	-- Scale the number size relative to damage magnitude
	local dmg_scale = opts.damage_scale or 1.0

	-- Random horizontal drift direction
	local dir = (love.math.random(0, 1) == 0) and -1 or 1

	-- Build display string
	local text
	if kind == "miss" then
		text = "MISS"
	elseif kind == "xp" then
		text = "+" .. tostring(amount) .. " XP"
	elseif kind == "heal" then
		text = "+" .. tostring(amount)
	else
		text = tostring(amount)
	end
	if opts.prefix then text = opts.prefix .. text end
	if opts.suffix then text = text .. opts.suffix end

	local num = {
		text        = text,
		kind        = kind,
		def         = def,
		x           = x + love.math.random(-10, 10),
		y           = y,
		ox          = 0, -- horizontal offset accumulator
		dir         = dir,
		age         = 0,
		lifetime    = def.lifetime,
		base_scale  = def.base_scale * dmg_scale,
		scale       = 0, -- animated
		alpha       = 1,
		rise        = def.rise,
		wobble      = def.wobble,
		wobble_seed = love.math.random() * 100,
	}

	table.insert(self.numbers, num)

	-- Trigger screen flash for crits
	if def.flash then
		self._flash_alpha = math.min(1, self._flash_alpha + 0.35)
	end
end

-- ── Update ────────────────────────────────────────────────────────────────

function DamageNumbers:update(dt)
	-- Decay screen flash
	self._flash_alpha = math.max(0, self._flash_alpha - self._flash_decay * dt)

	-- Update each number
	for i = #self.numbers, 1, -1 do
		local n = self.numbers[i]
		n.age = n.age + dt

		local t = n.age / n.lifetime -- normalized 0→1

		-- ── Scale animation ───────────────────────────────────────────────
		-- Phase 1 (0→0.15): elastic punch-in
		-- Phase 2 (0.15→0.5): hold at full size
		-- Phase 3 (0.5→1.0): shrink away (combined with fade)
		if t < 0.15 then
			n.scale = elastic_out(t / 0.15) * n.base_scale
		elseif t < 0.5 then
			n.scale = n.base_scale
		else
			local shrink_t = (t - 0.5) / 0.5
			n.scale = lerp(n.base_scale, n.base_scale * 0.55, ease_out(shrink_t))
		end

		-- ── Vertical rise ────────────────────────────────────────────────
		-- Starts fast, decelerates
		local rise_t = ease_out(math.min(t * 1.1, 1))
		n.y_offset = -n.rise * rise_t

		-- ── Horizontal wobble ─────────────────────────────────────────────
		-- Sinusoidal drift that fades out
		local wobble_fade = 1 - t
		n.ox = n.dir * n.wobble * math.sin(n.age * 4.5 + n.wobble_seed) * wobble_fade

		-- ── Alpha ─────────────────────────────────────────────────────────
		-- Stay fully opaque until ~60% through, then fade out
		if t < 0.6 then
			n.alpha = 1
		else
			n.alpha = 1 - ease_out((t - 0.6) / 0.4)
		end

		-- Remove when done
		if n.age >= n.lifetime then
			table.remove(self.numbers, i)
		end
	end
end

-- ── Draw ──────────────────────────────────────────────────────────────────

function DamageNumbers:draw()
	-- Screen flash (drawn before numbers so it's behind them)
	if self._flash_alpha > 0 then
		love.graphics.setColor(1, 1, 1, self._flash_alpha * 0.18)
		love.graphics.rectangle("fill", 0, 0,
			love.graphics.getWidth(), love.graphics.getHeight())
	end

	local prev_font = love.graphics.getFont()
	love.graphics.setFont(self.font)

	for _, n in ipairs(self.numbers) do
		local def = n.def
		local px  = n.x + n.ox
		local py  = n.y + (n.y_offset or 0)

		-- Scale pivot: measure text to center it
		local tw  = self.font:getWidth(n.text)
		local th  = self.font:getHeight()
		local cx  = px - tw * 0.5
		local cy  = py - th * 0.5

		love.graphics.push()
		love.graphics.translate(px, py)
		love.graphics.scale(n.scale, n.scale)
		love.graphics.translate(-px, -py)

		-- ── Chromatic aberration shadow (crits only) ──────────────────────
		if def.chromatic then
			-- Cyan ghost offset to the left
			love.graphics.setColor(0.0, 0.9, 1.0, n.alpha * 0.55)
			love.graphics.print(n.text, cx - 3, cy + 1)
			-- Red ghost offset to the right
			love.graphics.setColor(1.0, 0.1, 0.1, n.alpha * 0.55)
			love.graphics.print(n.text, cx + 3, cy - 1)
		end

		-- ── Drop shadow ────────────────────────────────────────────────────
		local sc = def.shadow
		love.graphics.setColor(sc[1], sc[2], sc[3], n.alpha * 0.80)
		love.graphics.print(n.text, cx + 2, cy + 3)

		-- ── Outline (thin, black) ──────────────────────────────────────────
		love.graphics.setColor(0, 0, 0, n.alpha * 0.6)
		love.graphics.print(n.text, cx - 1, cy - 1)
		love.graphics.print(n.text, cx + 1, cy - 1)
		love.graphics.print(n.text, cx - 1, cy + 1)
		love.graphics.print(n.text, cx + 1, cy + 1)

		-- ── Main text ─────────────────────────────────────────────────────
		local c = def.color
		love.graphics.setColor(c[1], c[2], c[3], n.alpha)
		love.graphics.print(n.text, cx, cy)

		love.graphics.pop()
	end

	love.graphics.setFont(prev_font)
	love.graphics.setColor(1, 1, 1, 1)
end

-- ── Convenience batch spawner ──────────────────────────────────────────────

---Spawn a randomised burst of numbers (for AoE, area damage, explosions).
---@param x       number
---@param y       number
---@param count   number   How many numbers to spawn
---@param min_dmg number
---@param max_dmg number
---@param kind    string
function DamageNumbers:spawn_burst(x, y, count, min_dmg, max_dmg, kind)
	for i = 1, count do
		local spread_x = love.math.random(-60, 60)
		local spread_y = love.math.random(-40, 20)
		local amount   = love.math.random(min_dmg, max_dmg)
		-- Stagger slightly so they don't all appear at once
		local n        = {
			text        = tostring(amount),
			kind        = kind or "normal",
			def         = TYPES[kind] or TYPES.normal,
			x           = x + spread_x,
			y           = y + spread_y,
			ox          = 0,
			dir         = (love.math.random(0, 1) == 0) and -1 or 1,
			age         = love.math.random() * 0.12, -- small random stagger
			lifetime    = (TYPES[kind] or TYPES.normal).lifetime,
			base_scale  = (TYPES[kind] or TYPES.normal).base_scale,
			scale       = 0,
			alpha       = 1,
			rise        = (TYPES[kind] or TYPES.normal).rise,
			wobble      = (TYPES[kind] or TYPES.normal).wobble,
			wobble_seed = love.math.random() * 100,
		}
		table.insert(self.numbers, n)
	end
end

return DamageNumbers
