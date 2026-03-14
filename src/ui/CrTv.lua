local CrTv = {}

function CrTv:getCrTvScreenDetails()
	local heightA = 1.5;
	local widthA = 1.5;

	width = love.graphics.getWidth() / widthA;
	height = love.graphics.getHeight() / heightA;
	posX = (love.graphics.getWidth() / 2 - width / widthA);
	posY = (love.graphics.getHeight() / 2 - height / heightA);

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

function CrTv:new()
	local self = setmetatable({}, CrTv)
	return self
end

function CrTv:load()
end

function CrTv:draw()
	love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
	local TvScreen = self:getCrTvScreenDetails();
	love.graphics.rectangle("fill", TvScreen.posX, TvScreen.posY, TvScreen.width, TvScreen.height)
	-- red color for the border
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", TvScreen.posX, TvScreen.posY, TvScreen.width, TvScreen.height)
end

function CrTv:update(dt)
end

return CrTv;
