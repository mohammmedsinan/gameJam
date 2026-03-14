local GameScene = {}
GameScene.__index = GameScene

function GameScene:load()
end

function GameScene:update(dt)
end

function GameScene:draw()
	love.graphics.setColor(0.2, 0.2, 0.2, 1)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle()

end

function GameScene:keypressed(key)
	if key == "escape" then
		SceneManager:switch("menu", { kind = "fade", duration = 0.3 })
	end
end

return GameScene
