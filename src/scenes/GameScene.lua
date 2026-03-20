local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
local SkillCheck = require("src/game/skillcheck");
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
    boss = Boss.new(bus)
    player = Player.new(bus)
    if SK then
        SK:load()
    end

end

function GameScene:update(dt)
    CrTv:update(dt)
    chatBox:update(dt)
    shopper:update(dt)
    player:update(dt)
    boss:update(dt)
    bus:flush()
    if SK then
        SK:update(dt)
    end
end

function GameScene:draw()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
    CrTv:draw()
    chatBox:draw()
    shopper:draw()
    player:draw()
    boss:draw()
    if SK then
        SK:draw()
    end
end

function love.resize()
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
    if (SK) then
        SK:keypressed(key)
    end
    if key == "space" then
        if SK then
            SK = nil
        else
            SK = SkillCheck:new({
                successArcSize = math.rad(55),
                greatArcSize = math.rad(12),
                onSuccess = function()
                    print("success!")
                end,
                onGreat = function()
                    print("GREAT!")
                end,
                onMiss = function()
                    print("miss...")
                end
            })
            SK:Spawn()
        end
    end

end

return GameScene
