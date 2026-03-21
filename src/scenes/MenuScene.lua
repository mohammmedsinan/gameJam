local MenuScene = {}
MenuScene.__index = MenuScene

function MenuScene:load()
end

function MenuScene:update(dt)
	-- nothing
end

function MenuScene:draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("MAIN MENU", 0, 200, love.graphics.getWidth(), "center")
	love.graphics.setColor(0.6, 0.9, 0.6)
	love.graphics.printf("Press SPACE to start", 0, 280, love.graphics.getWidth(), "center")
end

function MenuScene:keypressed(key)
	if key == "space" then
		SceneManager:switch("game", { kind = "fade", duration = 0.4 })
	end
end

return MenuScene
