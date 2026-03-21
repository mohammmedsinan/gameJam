local CrTv = require("src/ui/CrTv")

SkillCheck = {}

-- ─────────────────────────────────────────────
--  Constants
-- ─────────────────────────────────────────────
local TWO_PI = math.pi * 2

local DEFAULT_ZONES = {
	success = {
		arcSize = math.rad(60),
		color = { 0.1, 0.9, 0.1, 0.85 },
		lineWidth = 6
	},
	great = {
		arcSize = math.rad(15),
		color = { 1, 1, 0.1, 1 },
		lineWidth = 6
	}
}

local DEFAULT_POINTER = {
	speed = 5,
	size = {
		w = 10,
		h = 10
	},
	color = { 1, 0, 1, 1 }
}

local FLASH_DURATION = 0.35
local SHAKE_DURATION = 0.4
local SHAKE_MAGNITUDE = 6

-- ─────────────────────────────────────────────
--  Constructor
-- ─────────────────────────────────────────────
function SkillCheck:new(config)
	config = config or {}

	local TvScreen = CrTv:getCrTvScreenDetails()
	local newObj = {
		x = TvScreen.width / 2,
		y = TvScreen.height / 2,
		radius = TvScreen.width / 8,

		pointerAngle = 0,
		pointerSpeed = (config.pointerSpeed or DEFAULT_POINTER.speed),

		spawn = false,

		zones = {
			success = {
				arcSize = (config.successArcSize or DEFAULT_ZONES.success.arcSize),
				color = { DEFAULT_ZONES.success.color[1], DEFAULT_ZONES.success.color[2], DEFAULT_ZONES.success.color[3],
					DEFAULT_ZONES.success.color[4] },
				lineWidth = DEFAULT_ZONES.success.lineWidth,
				startAngle = 0
			},
			great = {
				arcSize = (config.greatArcSize or DEFAULT_ZONES.great.arcSize),
				color = { DEFAULT_ZONES.great.color[1], DEFAULT_ZONES.great.color[2], DEFAULT_ZONES.great.color[3],
					DEFAULT_ZONES.great.color[4] },
				lineWidth = DEFAULT_ZONES.great.lineWidth,
				startAngle = 0
			}
		},

		result = nil,
		flashTimer = 0,

		shakeTimer = 0,
		shakeOffset = {
			x = 0,
			y = 0
		},

		onSuccess = config.onSuccess or nil,
		onGreat = config.onGreat or nil,
		onMiss = config.onMiss or nil
	}

	self.__index = self
	return setmetatable(newObj, self)
end

-- ─────────────────────────────────────────────
--  Lifecycle
-- ─────────────────────────────────────────────
function SkillCheck:load()
end

function SkillCheck:update(dt)
	if not self.spawn and self.flashTimer <= 0 then
		return
	end

	self.pointerAngle = self.pointerAngle + self.pointerSpeed * dt

	if self.flashTimer > 0 then
		self.flashTimer = self.flashTimer - dt
		if self.flashTimer <= 0 then
			self.flashTimer = 0
			self.spawn = false
			self.result = nil
		end
	end

	if self.shakeTimer > 0 then
		self.shakeTimer = self.shakeTimer - dt
		if self.shakeTimer > 0 then
			local mag = SHAKE_MAGNITUDE * (self.shakeTimer / SHAKE_DURATION)
			self.shakeOffset.x = (math.random() * 2 - 1) * mag
			self.shakeOffset.y = (math.random() * 2 - 1) * mag
		else
			self.shakeTimer = 0
			self.shakeOffset.x = 0
			self.shakeOffset.y = 0
		end
	end
end

function SkillCheck:draw()
	if not self.spawn and self.flashTimer <= 0 then
		return
	end

	local TvScreen = CrTv:getCrTvScreenDetails()
	self.x = TvScreen.width / 2 + self.shakeOffset.x
	self.y = TvScreen.height / 2 + self.shakeOffset.y
	self.radius = TvScreen.width / 8

	self:_drawSkillCheck()
end

-- ─────────────────────────────────────────────
--  Input
-- ─────────────────────────────────────────────
function SkillCheck:keypressed(key)
	if not self.spawn then
		return
	end
	if key ~= "space" then
		return
	end
	self:_resolve()
end

-- ─────────────────────────────────────────────
--  Resolve
-- ─────────────────────────────────────────────
function SkillCheck:_resolve()
	local angle = self.pointerAngle % TWO_PI
	local success = self.zones.success
	local great = self.zones.great

	local function inArc(a, start, size)
		local s = start % TWO_PI
		local e = (start + size) % TWO_PI
		if s <= e then
			return a >= s and a <= e
		else
			return a >= s or a <= e
		end
	end

	if inArc(angle, great.startAngle, great.arcSize) then
		self:_triggerResult("great")
	elseif inArc(angle, success.startAngle, success.arcSize) then
		self:_triggerResult("success")
	else
		self:_triggerResult("miss")
	end
end

function SkillCheck:_triggerResult(result)
	self.result = result
	self.flashTimer = FLASH_DURATION

	if result == "miss" then
		self.shakeTimer = SHAKE_DURATION
		self.shakeOffset.x = 0
		self.shakeOffset.y = 0
		if self.onMiss then
			self.onMiss()
		end
	elseif result == "great" then
		if self.onGreat then
			self.onGreat()
		end
	else
		if self.onSuccess then
			self.onSuccess()
		end
	end
end

-- ─────────────────────────────────────────────
--  Internal draw
-- ─────────────────────────────────────────────
function SkillCheck:_drawSkillCheck()
	local x, y, r = self.x, self.y, self.radius

	-- Result flash
	if self.result and self.flashTimer > 0 then
		local alpha = self.flashTimer / FLASH_DURATION
		if self.result == "great" then
			love.graphics.setColor(1, 1, 0, alpha * 0.4)
		elseif self.result == "success" then
			love.graphics.setColor(0, 1, 0, alpha * 0.3)
		else
			love.graphics.setColor(1, 0, 0, alpha * 0.5)
		end
		love.graphics.circle("fill", x, y, r * 1.15)
	end

	-- Base filled circle
	love.graphics.setColor(0.2, 0.2, 0.5, 0.2)
	love.graphics.circle("fill", x, y, r)

	-- Success zone arc
	drawArc(x, y, r, self.zones.success.startAngle, self.zones.success.startAngle + self.zones.success.arcSize,
		self.zones.success.color, self.zones.success.lineWidth)

	-- Great zone arc
	drawArc(x, y, r, self.zones.great.startAngle, self.zones.great.startAngle + self.zones.great.arcSize,
		self.zones.great.color, self.zones.great.lineWidth)

	-- Base border circle
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.setLineWidth(1)
	--love.graphics.circle("line", x, y, r)
	love.graphics.setLineWidth(1)

	-- Pointer
	if self.spawn then
		self:_drawPointer(self.pointerAngle, x, y, r)
	end
end

function SkillCheck:_drawPointer(angle, cx, cy, radius)
	local px = cx + radius * math.cos(angle)
	local py = cy + radius * math.sin(angle)
	local w, h = DEFAULT_POINTER.size.w, DEFAULT_POINTER.size.h
	love.graphics.setColor(DEFAULT_POINTER.color)
	love.graphics.rectangle("fill", px - w / 2, py - h / 2, w, h)
end

-- ─────────────────────────────────────────────
--  Arc draw helper
-- ─────────────────────────────────────────────
function drawArc(cx, cy, radius, startAngle, endAngle, color, lineWidth)
	local segments = 64
	local step = (endAngle - startAngle) / segments
	love.graphics.setColor(color)
	love.graphics.setLineWidth(lineWidth or 4)
	for i = 0, segments - 1 do
		local a1 = startAngle + i * step
		local a2 = startAngle + (i + 1) * step
		local x1 = cx + radius * math.cos(a1)
		local y1 = cy + radius * math.sin(a1)
		local x2 = cx + radius * math.cos(a2)
		local y2 = cy + radius * math.sin(a2)
		love.graphics.line(x1, y1, x2, y2)
	end
	love.graphics.setLineWidth(1)
end

-- ─────────────────────────────────────────────
--  Zone management API
-- ─────────────────────────────────────────────
function SkillCheck:randomiseZones()
	local startAngle = math.random() * TWO_PI
	self.zones.success.startAngle = startAngle
	local greatOffset = (self.zones.success.arcSize - self.zones.great.arcSize) / 2
	self.zones.great.startAngle = startAngle + greatOffset
end

function SkillCheck:setSuccessZone(arcSizeRad, color, lineWidth)
	if arcSizeRad ~= nil then
		self.zones.success.arcSize = arcSizeRad
	end
	if color ~= nil then
		self.zones.success.color = color
	end
	if lineWidth ~= nil then
		self.zones.success.lineWidth = lineWidth
	end
end

function SkillCheck:setGreatZone(arcSizeRad, color, lineWidth)
	if arcSizeRad ~= nil then
		self.zones.great.arcSize = arcSizeRad
	end
	if color ~= nil then
		self.zones.great.color = color
	end
	if lineWidth ~= nil then
		self.zones.great.lineWidth = lineWidth
	end
end

-- ─────────────────────────────────────────────
--  Public API
-- ─────────────────────────────────────────────
function SkillCheck:Spawn()
	self.spawn = true
	self.result = nil
	self.flashTimer = 0
	self.pointerAngle = 0
	self:randomiseZones()
end

function SkillCheck:remove()
	self.spawn = false
end

function SkillCheck:isSkillCheckActive()
	return self.spawn
end

function SkillCheck:getResult()
	return self.result
end

function SkillCheck:getSkillCheckDisplayDetails()
	return {
		x = self.x,
		y = self.y,
		radius = self.radius
	}
end

return SkillCheck
