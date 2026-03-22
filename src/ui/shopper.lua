local CrTv = require("src/ui/CrTv");
local chatBox = require("src/ui/chatBox");
local EquipmentHand = require("src/ui/EquipmentHand");

local shopper = {
	equipHand = nil
}

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
	local screen = self:getShopperScreenDetails()

	self.equipHand = EquipmentHand.new({
		x = screen.posX + screen.width / 2,
		y = screen.posY + screen.height / 2,
		width = screen.width,
		itemSize = 64,
		spacing = 15,
		onItemClicked = function(index, item)
			if player then
				local unequipped = player:unequipItem(index)
				if unequipped then
					local sellValue = math.floor((unequipped.price or 0) / 2)
					player.gold = player.gold + sellValue
					print("[Shopper] Sold " .. unequipped.name .. " for $" .. sellValue)
				end
				self.equipHand:syncItems(player.inventory.equipments)
			end
		end
	})
end

function shopper:update(dt)
	local mx, my = love.mouse.getPosition()
	local screen = self:getShopperScreenDetails()

	if self.equipHand then
		self.equipHand.x = screen.posX + screen.width / 2
		self.equipHand.y = screen.posY + screen.height / 2

		if player then
			self.equipHand:setUnlockedSlots(math.min(6, player.level))
			self.equipHand:syncItems(player.inventory.equipments)
		end

		self.equipHand:update(dt)
	end
end

function shopper:mousepressed(x, y, button)
	if self.equipHand then
		self.equipHand:mousepressed(x, y, button)
	end
end

function shopper:mousereleased(x, y, button)
	if self.equipHand then
		self.equipHand:mousereleased(x, y, button)
	end
end

function shopper:mousemoved(x, y, dx, dy)
	if self.equipHand then
		self.equipHand:mousemoved(x, y, dx, dy)
	end
end

function shopper:draw()
	local combat = true;
	love.graphics.setColor(0.12, 0.12, 0.14, 0.85)
	local ShopperScreen = self:getShopperScreenDetails();

	if combat then
		love.graphics.rectangle("fill", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height, 6, 6)
		love.graphics.setColor(0.85, 0.55, 0.10, 0.9)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height, 6, 6)
		love.graphics.setLineWidth(1)
	else
		love.graphics.rectangle("fill", ShopperScreen.posX, ShopperScreen.posY, ShopperScreen.width, ShopperScreen
			.height, 6, 6)
	end

	if player then
		love.graphics.setColor(0.9, 0.9, 0.9, 1)
		local unlockedSlots = math.min(6, player.level)
		local title = "Equipment (Unlocked: " .. unlockedSlots .. "/6)"
		love.graphics.print(title, ShopperScreen.posX + 10, ShopperScreen.posY + 5)
	end

	if self.equipHand then
		self.equipHand:draw()
	end
end

return shopper;
