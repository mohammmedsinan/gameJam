local CrTv = require("src/ui/CrTv");
local Boss = {}

Boss.__index = Boss
function Boss.new(bus)
	local self = setmetatable({
		name = "boss",
		bus = bus,
		width = 100,
		height = 100,
		health = 100,
		maxHealth = 100,
		damage = 0,
		attack = 2,
		defence = 0,
		level = 2,
		effect = nil,
		isBoss = false,
		x = 0,
		y = 0,
	}, Boss)
	return self;
end

--- Load encounter data from stages.json into this boss entity
function Boss:setFromEncounter(enc)
	self.name      = enc.name or "Enemy"
	self.health    = enc.health or 100
	self.maxHealth = enc.health or 100
	self.attack    = enc.attack or 2
	self.defence   = enc.defence or 0
	self.effect    = enc.effect or nil
	self.isBoss    = enc.isBoss or false
end

function Boss:load()
end

function Boss:update(dt)
end

function Boss:details()
	return {
		x = self.x,
		y = self.y
	};
end

function Boss:draw()
	local CrTvScreen = CrTv:getCrTvScreenDetails();
	self.x = CrTvScreen.border.right - 120;
	self.y = CrTvScreen.border.bottom - 120;

	-- Boss glow for final bosses
	if self.isBoss and self.effect then
		love.graphics.setColor(0.85, 0.3, 1.0, 0.12 + 0.06 * math.sin(love.timer.getTime() * 3))
		love.graphics.rectangle("fill", self.x - 6, self.y - 6, self.width + 12, self.height + 12, 4, 4)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", self.x, self.y, self.width,
		self.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", self.x, self.y, self.width,
		self.height)
end

return Boss;
