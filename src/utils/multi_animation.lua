-- mult_animation.lua
-- Drop-in multiplier hit animation for Love2D roguelike deck builders.
-- Shows only the "×N" label — no base damage, no result.
--
-- QUICK START:
--   local MultAnim = require("mult_animation")
--
--   MultAnim.spawn(x, y, 3)                        -- single ×3 hit
--   MultAnim.spawnChain(x, y, {3, 2, 4})           -- rapid chain of ×3, ×2, ×4
--
--   -- In love.update:  MultAnim.update(dt)
--   -- In love.draw:    MultAnim.draw()
-- ─────────────────────────────────────────────────────────────────────────────

local MultAnim = {}
MultAnim._anims = {}

-- ─────────────────────────────────────────────
-- CONFIGURATION
-- ─────────────────────────────────────────────
local CFG = {
	flashDuration  = 0.07, -- white screen-flash length (s)
	impactFreeze   = 0.055, -- freeze-frame before label appears (s)
	showTime       = 0.45, -- how long "×N" stays visible (s)
	riseSpeed      = -110, -- px/s upward drift

	chainDelay     = 0.16, -- seconds between chained hits

	startScale     = 3.0, -- scale when label first pops in
	peakScale      = 3.6, -- overshoot bounce peak
	endScale       = 1.8, -- settled resting scale before fade

	shakeAmplitude = 13,
	shakeDuration  = 0.20,

	colorLabel     = { 1.00, 0.82, 0.10, 1 }, -- golden yellow
	colorOutline   = { 0.10, 0.04, 0.00, 1 }, -- near-black warm
	colorFlash     = { 1.00, 1.00, 1.00, 0.50 },
	colorGlow      = { 1.00, 0.65, 0.05, 0.20 },
	colorSpark     = { 1.00, 0.90, 0.25, 1 },

	sparkCount     = 12,
	sparkSpeed     = 300,
	sparkLife      = 0.42,

	ringMaxRadius  = 72,
	ringDuration   = 0.26,
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function easeOut(t) return 1 - (1 - t) ^ 3 end

local function easeOutBounce(t)
	local n1, d1 = 7.5625, 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		t = t - 1.5 / d1; return n1 * t * t + 0.75
	elseif t < 2.5 / d1 then
		t = t - 2.25 / d1; return n1 * t * t + 0.9375
	else
		t = t - 2.625 / d1; return n1 * t * t + 0.984375
	end
end

-- Shake
local shake = { x = 0, y = 0, timer = 0, amp = 0 }
local function triggerShake(amp)
	shake.timer = CFG.shakeDuration
	shake.amp   = math.max(shake.amp, amp)
end
local function updateShake(dt)
	if shake.timer > 0 then
		shake.timer = shake.timer - dt
		local a = shake.amp * (shake.timer / CFG.shakeDuration)
		shake.x = (math.random() * 2 - 1) * a
		shake.y = (math.random() * 2 - 1) * a
	else
		shake.x, shake.y = 0, 0
	end
end

-- Flash
local flash = { timer = 0 }
local function triggerFlash() flash.timer = CFG.flashDuration end

-- Sparks
local function makeSparks(x, y)
	local s = {}
	for i = 1, CFG.sparkCount do
		local angle = (i / CFG.sparkCount) * math.pi * 2 + math.random() * 0.5
		local spd   = CFG.sparkSpeed * (0.5 + math.random() * 0.8)
		s[#s + 1]   = {
			x = x,
			y = y,
			vx = math.cos(angle) * spd,
			vy = math.sin(angle) * spd - 55,
			life = CFG.sparkLife * (0.7 + math.random() * 0.6),
			maxLife = CFG.sparkLife,
			size = 2 + math.random() * 3,
		}
	end
	return s
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

--- Spawn a single multiplier animation.
-- @param x          Screen X (impact center)
-- @param y          Screen Y (impact center)
-- @param multiplier The ×N value to display (number)
-- @param delay      Optional delay in seconds before starting (default 0)
-- @param onDone     Optional callback function fired when the animation finishes
function MultAnim.spawn(x, y, multiplier, delay, onDone)
	MultAnim._anims[#MultAnim._anims + 1] = {
		x      = x,
		y      = y,
		mult   = multiplier,
		delay  = delay or 0,
		onDone = onDone, -- called once when animation completes
		timer  = 0,
		phase  = "waiting", -- waiting → impact → show → done
		oy     = 0,
		sparks = {},
		ring   = nil,
		done   = false,
	}
end

--- Spawn a rapid chain of multipliers at roughly the same location.
-- @param x       Center X
-- @param y       Center Y
-- @param mults   Array of multiplier values, e.g. {3, 2, 4}
-- @param onDone  Optional callback fired once after the LAST hit finishes
function MultAnim.spawnChain(x, y, mults, onDone)
	for i, m in ipairs(mults) do
		-- Only attach the callback to the final hit in the chain
		local cb = (i == #mults) and onDone or nil
		MultAnim.spawn(
			x + math.random(-16, 16),
			y + math.random(-10, 10),
			m,
			(i - 1) * CFG.chainDelay,
			cb
		)
	end
end

-- ─────────────────────────────────────────────
-- Update  (love.update)
-- ─────────────────────────────────────────────
function MultAnim.update(dt)
	updateShake(dt)
	if flash.timer > 0 then flash.timer = flash.timer - dt end

	for i = #MultAnim._anims, 1, -1 do
		local a = MultAnim._anims[i]

		if a.done then
			table.remove(MultAnim._anims, i)
		elseif a.phase == "waiting" then
			a.delay = a.delay - dt
			if a.delay <= 0 then
				a.phase  = "impact"
				a.timer  = 0
				a.sparks = makeSparks(a.x, a.y)
				a.ring   = { timer = 0 }
				triggerShake(CFG.shakeAmplitude)
				triggerFlash()
			end
		else
			a.timer = a.timer + dt

			for _, sp in ipairs(a.sparks) do
				sp.life = sp.life - dt
				sp.x    = sp.x + sp.vx * dt
				sp.y    = sp.y + sp.vy * dt
				sp.vy   = sp.vy + 370 * dt
			end

			if a.ring then
				a.ring.timer = a.ring.timer + dt
				if a.ring.timer > CFG.ringDuration then a.ring = nil end
			end

			if a.phase == "impact" then
				if a.timer >= CFG.impactFreeze then
					a.phase = "show"
					a.timer = 0
				end
			elseif a.phase == "show" then
				a.oy = a.oy + CFG.riseSpeed * dt
				if a.timer >= CFG.showTime then
					a.done = true
					if a.onDone then a.onDone() end
				end
			end
		end
	end
end

-- ─────────────────────────────────────────────
-- Draw  (love.draw)
-- ─────────────────────────────────────────────
function MultAnim.draw()
	local W, H = love.graphics.getDimensions()

	love.graphics.push()
	love.graphics.translate(shake.x, shake.y)

	for _, a in ipairs(MultAnim._anims) do
		if a.phase == "waiting" or a.phase == "impact" then goto continue end

		local cx      = a.x
		local cy      = a.y + a.oy
		local t       = a.timer

		-- Fade-in and fade-out alpha
		local fadeIn  = clamp(t / 0.08, 0, 1)
		local fadeOut = clamp((CFG.showTime - t) / 0.12, 0, 1)
		local alpha   = math.min(fadeIn, fadeOut)

		-- Scale: bounce-in then settle
		local bounceT = clamp(t / 0.14, 0, 1)
		local settleT = clamp((t - 0.05) / 0.18, 0, 1)
		local sc      = lerp(
			lerp(CFG.startScale, CFG.peakScale, easeOutBounce(bounceT)),
			CFG.endScale, easeOut(settleT))

		-- ── Glow ──
		-- local ga = CFG.colorGlow[4] * easeOut(fadeIn) * fadeOut
		-- love.graphics.setColor(CFG.colorGlow[1], CFG.colorGlow[2], CFG.colorGlow[3], ga)
		-- love.graphics.circle("fill", cx, cy, 55)

		-- ── Shockwave ring ──
		if a.ring then
			local rt = a.ring.timer / CFG.ringDuration
			love.graphics.setColor(1, 0.85, 0.2, (1 - rt) * 0.65)
			love.graphics.setLineWidth(2.5 * (1 - rt) + 0.5)
			love.graphics.circle("line", a.x, a.y, CFG.ringMaxRadius * easeOut(rt))
			love.graphics.setLineWidth(1)
		end

		-- ── Sparks ──
		for _, sp in ipairs(a.sparks) do
			if sp.life > 0 then
				local lt = sp.life / sp.maxLife
				love.graphics.setColor(CFG.colorSpark[1], CFG.colorSpark[2], CFG.colorSpark[3], lt)
				love.graphics.circle("fill", sp.x, sp.y, sp.size * lt)
			end
		end

		-- ── "×N" label ──
		love.graphics.push()
		love.graphics.translate(cx, cy)
		love.graphics.scale(sc, sc)

		-- Chunky outline
		love.graphics.setColor(CFG.colorOutline[1], CFG.colorOutline[2], CFG.colorOutline[3], alpha * 0.85)
		for ox = -2, 2 do
			for oy = -2, 2 do
				if ox ~= 0 or oy ~= 0 then
					love.graphics.printf("×" .. a.mult, -200 + ox, -28 + oy, 400, "center")
				end
			end
		end

		-- Main label
		love.graphics.setColor(CFG.colorLabel[1], CFG.colorLabel[2], CFG.colorLabel[3], alpha)
		love.graphics.printf("×" .. a.mult, -200, -28, 400, "center")

		love.graphics.pop()

		::continue::
	end

	love.graphics.pop()

	-- Screen flash
	if flash.timer > 0 then
		local ft = flash.timer / CFG.flashDuration
		love.graphics.setColor(
			CFG.colorFlash[1], CFG.colorFlash[2], CFG.colorFlash[3],
			CFG.colorFlash[4] * ft)
		love.graphics.rectangle("fill", 0, 0, W, H)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

--- Set a custom font for the label.
-- Call once in love.load:  MultAnim.setFont(love.graphics.newFont("myfont.ttf", 52))
function MultAnim.setFont(font)
	love.graphics.setFont(font)
end

return MultAnim
