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
	love.graphics.setColor(0.12, 0.12, 0.14, 0.85)
	local chatBoxScreen = self:getChatBoxScreenDetails();
	love.graphics.rectangle("fill", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height, 6,
		6)
	-- warm brass border
	love.graphics.setColor(0.85, 0.55, 0.10, 0.9)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", chatBoxScreen.posX, chatBoxScreen.posY, chatBoxScreen.width, chatBoxScreen.height, 6,
		6)
	love.graphics.setLineWidth(1)
end

return chatBox;
