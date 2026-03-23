local DungeonShader = require("src/utils/DungeonShader")
local CreditsScene = {}
CreditsScene.__index = CreditsScene

local function lerp(a, b, t) return a + (b - a) * t end

function CreditsScene:load()
	self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
	self.titleFont = love.graphics.setNewFont(54) or love.graphics.getFont()
end

function CreditsScene:enter(prev)
	local w, h = love.graphics.getDimensions()
	self.buttons = {
		{ text = "RETURN", target = "menu", y = h * 0.85, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 }
	}
	self.scrollY = 0
	self.targetScrollY = 0

	self.credits = {
		{ header = "Creator & Lead Developer", text = "Mohammed S. Mufeed\nmsinan.xyz" },
		{ header = "Programming",              text = "Mohammed S. Mufeed" },
		{ header = "Game Design & Concepts",   text = "Mohammed S. Mufeed" },
		{ header = "Original Audio & SFX",     text = "Mohammed S. Mufeed" },
		{ header = "UI & Item Sound Effects",  text = "ViRiX Dreamcore (David McKee)\nsoundcloud.com/virix" },
		{ header = "Original Soundtrack",      text = "maxstack" },
		{ header = "Additional Audio",         text = "Jesús Lastra\nOgrebane\nsluarschp" },
		{ header = "Special Thanks",           text = "Thanks for playing!" }
	}
end

function CreditsScene:update(dt)
	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	for i, btn in ipairs(self.buttons) do
		local bx = cx - btn.w / 2
		local by = btn.y
		local wasHover = btn.hover
		btn.hover = (mx >= bx and mx <= bx + btn.w and my >= by and my <= by + btn.h)
		if btn.hover and not wasHover then
			if Audio then Audio.playSFX("hover") end
		end

		btn.scale = lerp(btn.scale, btn.hover and 1.05 or 1.0, dt * 10)
		btn.clickScale = lerp(btn.clickScale, 1.0, dt * 15)
	end

	self.scrollY = lerp(self.scrollY, self.targetScrollY, dt * 10)
end

function CreditsScene:draw()
	love.graphics.push("all")
	DungeonShader:draw()

	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	if self.titleFont then love.graphics.setFont(self.titleFont) end
	love.graphics.setColor(0.6, 0.5, 0.4, 1)
	love.graphics.printf("- CREDITS -", 0, h * 0.15 + self.scrollY, w, "center")

	if self.font then love.graphics.setFont(self.font) end

	local yOffset = h * 0.25 + self.scrollY
	for i, section in ipairs(self.credits) do
		love.graphics.setColor(0.6, 0.5, 0.4, 1)
		love.graphics.printf(section.header, 0, yOffset, w, "center")
		yOffset = yOffset + self.font:getHeight() + 10

		love.graphics.setColor(0.5, 0.5, 0.5, 1)
		love.graphics.printf(section.text, 0, yOffset, w, "center")

		local _, wrappedText = self.font:getWrap(section.text, w)
		yOffset = yOffset + (#wrappedText * self.font:getHeight()) + 50
	end

	self.maxScroll = math.max(0, yOffset - self.scrollY - h * 0.75)

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

function CreditsScene:mousepressed(x, y, button, istouch, presses)
	if button == 1 then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 0.95
				if Audio then Audio.playSFX("click") end
			end
		end
	end
end

function CreditsScene:mousereleased(x, y, button, istouch, presses)
	if button == 1 then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 1.0
				if SceneManager then SceneManager:switch(btn.target, { kind = "fade", duration = 0.4 }) end
			end
		end
	end
end

function CreditsScene:wheelmoved(x, y)
	self.targetScrollY = self.targetScrollY + y * 60
	if self.targetScrollY > 0 then
		self.targetScrollY = 0
	elseif self.maxScroll and self.targetScrollY < -self.maxScroll then
		self.targetScrollY = -self.maxScroll
	end
end

return CreditsScene
