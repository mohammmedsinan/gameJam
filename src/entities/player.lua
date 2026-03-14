local CrTv = require("src/ui/CrTv");

local Player = {
}
Player.__index = Player

function Player.new(bus)
	return setmetatable({
		name = "player",
		bus = bus,
		width = 70,
		height = 70,
		health = 10,
		maxHealth = 10,
		damage = 1,
		attack = 1,
		defence = 0,
		xp = 0,
		level = 1,
		gold = 0,
	}, Player)
end

function Player:load()
end

function Player:update(dt)
	if love.keyboard.isDown("space") then
		self.bus:queue("boss:hit", self.damage)
	end
end

function Player:draw()
	love.graphics.setColor(1, 1, 1, 1)
	local CrTvScreen = CrTv:getCrTvScreenDetails();
	love.graphics.rectangle("fill", CrTvScreen.border.left + 100, CrTvScreen.border.bottom - 100, self.width, self
		.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", CrTvScreen.border.left + 100, CrTvScreen.border.bottom - 100, self.width, self
		.height)
end

return Player;
