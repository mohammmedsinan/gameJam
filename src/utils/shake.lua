local CameraShake = {}
CameraShake.__index = CameraShake

-- Simplex-like smooth noise using Love2D's math.noise
local function noise1(t)
	return love.math.noise(t) * 2 - 1 -- remap [0,1] → [-1,1]
end

local function noise2(t)
	return love.math.noise(t + 9371.5) * 2 - 1
end

local function noise_angle(t)
	return love.math.noise(t + 3141.7) * 2 - 1
end

-- ── Constructor ────────────────────────────────────────────────────────────

---Create a new CameraShake instance.
---@param cfg table|nil  Optional config overrides
function CameraShake.new(cfg)
	cfg                  = cfg or {}
	local self           = setmetatable({}, CameraShake)

	-- Trauma decays each second. Range [0, 1].
	self.trauma          = 0
	self.trauma_decay    = cfg.trauma_decay or 1.2 -- units per second
	self.trauma_exponent = cfg.trauma_exponent or 2 -- controls curve shape

	-- Maximum displacements when trauma == 1
	self.max_offset_x    = cfg.max_offset_x or 40 -- pixels
	self.max_offset_y    = cfg.max_offset_y or 30 -- pixels
	self.max_rotation    = cfg.max_rotation or 0.06 -- radians (~3.4°)

	-- Noise speed: how fast the shake pattern scrolls through perlin noise
	self.noise_speed     = cfg.noise_speed or 90

	-- Internal noise time accumulator (private)
	self._time           = love.math.random() * 1000 -- random seed offset

	-- Current computed offsets (read-only from outside)
	self.offset_x        = 0
	self.offset_y        = 0
	self.rotation        = 0

	-- Optional: screen center for rotation pivot (set to your actual center)
	self.pivot_x         = cfg.pivot_x or love.graphics.getWidth() / 2
	self.pivot_y         = cfg.pivot_y or love.graphics.getHeight() / 2

	return self
end

-- ── Core API ───────────────────────────────────────────────────────────────

---Add trauma. Trauma stacks (clamped to 1). Call this on impacts, explosions, etc.
---@param amount number  Value in [0, 1]. 0.2 = subtle, 0.8 = massive.
function CameraShake:add_trauma(amount)
	self.trauma = math.min(1, self.trauma + amount)
end

---Set trauma directly (overrides current value).
---@param value number  Value in [0, 1].
function CameraShake:set_trauma(value)
	self.trauma = math.max(0, math.min(1, value))
end

---Update the shake simulation. Call every frame in love.update(dt).
---@param dt number  Delta time in seconds.
function CameraShake:update(dt)
	-- Decay trauma over time
	self.trauma = math.max(0, self.trauma - self.trauma_decay * dt)

	-- Shake magnitude = trauma^exponent (exponent=2 gives a nice quadratic feel)
	local shake = self.trauma ^ self.trauma_exponent

	-- Advance noise time
	self._time = self._time + dt * self.noise_speed

	-- Sample smooth noise for each axis
	self.offset_x = self.max_offset_x * shake * noise1(self._time)
	self.offset_y = self.max_offset_y * shake * noise2(self._time)
	self.rotation = self.max_rotation * shake * noise_angle(self._time)
end

---Apply the shake transform. Call at the very top of love.draw() before drawing anything.
function CameraShake:apply()
	love.graphics.push()

	-- Translate to pivot, rotate, translate back, then apply offset
	love.graphics.translate(self.pivot_x, self.pivot_y)
	love.graphics.rotate(self.rotation)
	love.graphics.translate(-self.pivot_x + self.offset_x, -self.pivot_y + self.offset_y)
end

---Remove the shake transform. Call at the very bottom of love.draw() after drawing everything.
function CameraShake:pop()
	love.graphics.pop()
end

---Returns true if the camera is currently shaking.
function CameraShake:is_shaking()
	return self.trauma > 0
end

---Immediately stop all shaking.
function CameraShake:stop()
	self.trauma = 0
	self.offset_x = 0
	self.offset_y = 0
	self.rotation = 0
end

-- ── Integration helpers ────────────────────────────────────────────────────

---Convenience: add trauma based on a damage value relative to a reference.
---E.g. shake:add_trauma_from_damage(50, 200) → trauma += 0.25
---@param damage        number  Damage dealt.
---@param max_damage    number  Reference damage that equals trauma 1.0.
---@param scale         number|nil  Optional multiplier (default 1).
function CameraShake:add_trauma_from_damage(damage, max_damage, scale)
	scale = scale or 1
	self:add_trauma((damage / max_damage) * scale)
end

return CameraShake
