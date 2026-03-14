local CrTv = require("src/ui/CrTv");
local chatBox = require("src/ui/chatBox");

local shopper = {}

function shopper:getChatBoxScreenDetails()
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

function shopper:load()
end

function shopper:update(dt)
end

function shopper:draw()
end

return shopper;
