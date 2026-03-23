local CrTv = require("src/ui/CrTv");
local CharacterFX = require("src/utils/character_fx")

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
	-- Character visual effects (dark red/crimson energy)
	self.cfx = CharacterFX.new({
		color = { 0.9, 0.2, 0.15 },
		intensity = 1.0,
	})
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
	-- Update boss flag on the FX module
	if self.cfx then
		self.cfx.isBoss = self.isBoss or false
	end
end

function Boss:load()
end

function Boss:update(dt)
	if self.cfx then self.cfx:update(dt) end
end

function Boss:setVisualState(state)
	if self.cfx then self.cfx:setState(state) end
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

	-- Draw character with shader + particles (replaces plain rectangle)
	if self.cfx then
		self.cfx:draw(self.x, self.y, self.width, self.height)
	end
end

return Boss;
