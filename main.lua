SceneManager = require("lib/SceneManager")
love = require("love")

-- Scenes ----------------------------------------------------------------------
local MenuScene = require("src/scenes/MenuScene")
local GameScene = require("src/scenes/GameScene")
local Shop = require("src/scenes/Shop")
local SettingsScene = require("src/scenes/SettingsScene")
local CreditsScene = require("src/scenes/CreditsScene")


function love.load()
	SceneManager:add("menu", setmetatable({}, MenuScene))
	SceneManager:add("game", setmetatable({}, GameScene))
	SceneManager:add("shop", setmetatable({}, Shop))
	SceneManager:add("settings", setmetatable({}, SettingsScene))
	SceneManager:add("credits", setmetatable({}, CreditsScene))
	SceneManager:switch("menu")
	music = love.audio.newSource("assets/audio/music/videoplayback.ogg", "stream")
	music:play()
end

function love.update(dt)
	SceneManager:update(dt)
end

function love.draw()
	SceneManager:draw()
end

function love.keypressed(k, s, r)
	SceneManager:keypressed(k, s, r)
end

function love.keyreleased(k, s)
	if k == "w" then
		local isFullScreen, _ = love.window.getFullscreen()
		love.window.setFullscreen(not isFullScreen)
	end
	SceneManager:keyreleased(k, s)
end

function love.mousepressed(x, y, b, t, p)
	SceneManager:mousepressed(x, y, b, t, p)
end

function love.mousereleased(x, y, b, t, p)
	SceneManager:mousereleased(x, y, b, t, p)
end

function love.mousemoved(x, y, dx, dy, t)
	SceneManager:mousemoved(x, y, dx, dy, t)
end

function love.wheelmoved(x, y)
	SceneManager:wheelmoved(x, y)
end

function love.resize(w, h)
	SceneManager:resize(w, h)
end

function love.focus(f)
	SceneManager:focus(f)
end

function love.quit()
	return SceneManager:quit()
end
