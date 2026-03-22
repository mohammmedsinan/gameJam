local DungeonShader = require("src/utils/DungeonShader")
local SettingsScene = {}
SettingsScene.__index = SettingsScene

local function lerp(a, b, t) return a + (b - a) * t end

function SettingsScene:load()
    self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
    self.titleFont = love.graphics.setNewFont(54) or love.graphics.getFont()
end

function SettingsScene:enter(prev)
    local w, h = love.graphics.getDimensions()
    self.buttons = {
        { text = "RETURN", target = "menu", y = h * 0.8, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 }
    }
end

function SettingsScene:update(dt)
    DungeonShader:update(dt)
    local mx, my = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    local cx = w / 2

    for i, btn in ipairs(self.buttons) do
        local bx = cx - btn.w / 2
        local by = btn.y
        btn.hover = (mx >= bx and mx <= bx + btn.w and my >= by and my <= by + btn.h)

        btn.scale = lerp(btn.scale, btn.hover and 1.05 or 1.0, dt * 10)
        btn.clickScale = lerp(btn.clickScale, 1.0, dt * 15)
    end
end

function SettingsScene:draw()
    love.graphics.push("all")
    DungeonShader:draw()

    local w, h = love.graphics.getDimensions()
    local cx = w / 2

    if self.titleFont then love.graphics.setFont(self.titleFont) end
    love.graphics.setColor(0.6, 0.5, 0.4, 1)
    love.graphics.printf("- SETTINGS -", 0, h * 0.15, w, "center")

    if self.font then love.graphics.setFont(self.font) end
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.printf("Volume: 100%\nFullscreen: Off\n(Placeholder settings)", 0, h * 0.4, w, "center")

    for i, btn in ipairs(self.buttons) do
        local totalScale = btn.scale * btn.clickScale
        local bw = btn.w * totalScale
        local bh = btn.h * totalScale
        local bx = cx - bw / 2
        local by = btn.y + (btn.h - bh) / 2

        if btn.hover then
            love.graphics.setColor(0.15, 0.15, 0.15, 1)
        else
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
        end
        love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
        love.graphics.setColor(0.4, 0.3, 0.2, 1)
        love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local fontHeight = self.font and self.font:getHeight() or 16
        love.graphics.printf(btn.text, bx, by + bh / 2 - fontHeight / 2, bw, "center")
    end
    love.graphics.pop()
end

function SettingsScene:mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        for i, btn in ipairs(self.buttons) do
            if btn.hover then btn.clickScale = 0.95 end
        end
    end
end

function SettingsScene:mousereleased(x, y, button, istouch, presses)
    if button == 1 then
        for i, btn in ipairs(self.buttons) do
            if btn.hover then
                btn.clickScale = 1.0
                if SceneManager then SceneManager:switch(btn.target, { kind = "fade", duration = 0.4 }) end
            end
        end
    end
end

return SettingsScene
