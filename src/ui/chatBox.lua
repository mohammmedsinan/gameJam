local CrTv = require("src/ui/CrTv");
local chatBox = {}

function CrTv:getChatBoxScreenDetails()
    local CrTv = self:getCrTvScreenDetails();
    width = (love.graphics.getWidth() - CrTv.width) / 1.8;
    height = (love.graphics.getHeight() - posY) / 1.1;
    posX = CrTv.posX + CrTv.width + width / 4;
    posY = CrTv.posY;
    left = posX;
    right = posX + width;
    top = posY;
    bottom = posY + height;

    return {
        width = width,
        height = height,
        posX = posX,
        posY = posY,
        border = {
            left = left,
            right = right,
            top = top,
            bottom = bottom
        }
    };
end

function chatBox:new()
    local self = setmetatable({}, {
        __index = chatBox
    })
    return self
end

function chatBox:load()
end

function chatBox:update(dt)
end

function chatBox:draw()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
    local chatBoxScreen = CrTv:getChatBoxScreenDetails();
    print("Chat Box Screen Details:", chatBoxScreen.width, chatBoxScreen.height, chatBoxScreen.posX, chatBoxScreen.posY)
    love.graphics.rectangle("fill", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height)
    -- red color for the border
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height)
end

return chatBox;
