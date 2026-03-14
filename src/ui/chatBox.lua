local CrTv = require("src/ui/CrTv");
local chatBox = {}

function chatBox:getChatBoxScreenDetails()
	local CrTvScreen = CrTv:getCrTvScreenDetails();

	width = (love.graphics.getWidth() - CrTvScreen.width) / 1.8;
	height = (love.graphics.getHeight() - posY) / 1.1;
	posX = CrTvScreen.posX + CrTvScreen.width + width / 4;
	posY = CrTvScreen.posY;

	return {
		width = width,
		height = height,
		posX = posX,
		posY = posY,
		border = {
			left = posX,
			right = posX + width,
			top = posY,
			bottom = posY + height,
		}
	};
end

function chatBox:load()
end

function chatBox:update(dt)
end

function chatBox:draw()
	love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
	local chatBoxScreen = self:getChatBoxScreenDetails();
	love.graphics.rectangle("fill", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height)
end

return chatBox;
