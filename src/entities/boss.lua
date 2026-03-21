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
	}, Boss)
	return self;
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
	love.graphics.setColor(1, 1, 1, 1)
	self.x = CrTvScreen.border.right - 120;
	self.y = CrTvScreen.border.bottom - 120;
	love.graphics.rectangle("fill", self.x, self.y, self.width,
		self.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", CrTvScreen.border.right - 120, CrTvScreen.border.bottom - 120, self.width,
		self.height)
end

return Boss;
