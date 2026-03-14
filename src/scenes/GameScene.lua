local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
Player = require("src/entities/player");
Boss = require("src/entities/boss");
Signal = require("src/utils/signal")
bus = Signal.new()
local GameScene = {}
GameScene.__index = GameScene

function GameScene:load()
	CrTv:load()
	chatBox:load()
	shopper:load()
	boss   = Boss.new(bus)
	player = Player.new(bus)
end

function GameScene:update(dt)
	CrTv:update(dt)
	chatBox:update(dt)
	shopper:update(dt)
	player:update(dt)
	boss:update(dt)
	bus:flush()
end

function GameScene:draw()
	love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
	CrTv:draw()
	chatBox:draw()
	shopper:draw()
	player:draw()
	boss:draw()
end

function GameScene:keypressed(key)
	if key == "tab" then
		SceneManager:switch("menu", {
			kind = "fade",
			duration = 0.3
		})
	end

	if key == "escape" then
		love.event.quit();
	end

	if key == "w" then
		local isFullScreen, _ = love.window.getFullscreen()
		love.window.setFullscreen(not isFullScreen)
	end
end

return GameScene
