local CrTv = require("src/ui/CrTv");
local chatBox = require("src/ui/chatBox");

local shopper = {}

function shopper:getShopperScreenDetails()
	local CrTvScreen = CrTv:getCrTvScreenDetails();
	local chatBoxScreen = chatBox:getChatBoxScreenDetails();
	width = CrTvScreen.width;
	height = (chatBoxScreen.height - CrTvScreen.height) - 20;
	posX = CrTvScreen.posX;
	posY = CrTvScreen.border.bottom + 20;
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
	self:getShopperScreenDetails();
end

function shopper:update(dt)
end

function shopper:draw()
	local combat = true;
	love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
	local ShopperScreen = self:getShopperScreenDetails();
	if combat then
		love.graphics.rectangle("fill", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height)
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.rectangle("line", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height)
	else
		love.graphics.rectangle("fill", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height)
	end
end

return shopper;
