local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
local GameScene = {}
GameScene.__index = GameScene

function GameScene:load()
    CrTv:load()
    chatBox:load()
    shopper:load()
end

function GameScene:update(dt)
    CrTv:update(dt)
    chatBox:update(dt)
    shopper:update(dt)
end

function GameScene:draw()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
    CrTv:draw()
    chatBox:draw()
    shopper:draw()
end

function GameScene:keypressed(key)
    if key == "escape" then
        SceneManager:switch("menu", {
            kind = "fade",
            duration = 0.3
        })
    end
    if key == "w" then
        local isFullScreen, _ = love.window.getFullscreen()
        love.window.setFullscreen(not isFullScreen)
    end
end

return GameScene
