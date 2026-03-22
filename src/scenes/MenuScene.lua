local DungeonShader = require("src/utils/DungeonShader")
local MenuScene = {}
MenuScene.__index = MenuScene

local function lerp(a, b, t)
	return a + (b - a) * t
end

function MenuScene:load()
	self.time = 0

	-- Font setup
	self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
	self.titleFont = love.graphics.setNewFont(54) or love.graphics.getFont()
end

function MenuScene:enter(prev)
	self.time = 0
	local w, h = love.graphics.getDimensions()

	if not self.font then
		self.font = love.graphics.setNewFont(20) or love.graphics.getFont()
	end

	-- Dungeon-style buttons (Settings, Credits replacing Shop)
	self.buttons = {
		{ text = "ENTER DUNGEON", target = "game",     y = h * 0.4,       w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "SETTINGS",      target = "settings", y = h * 0.4 + 70,  w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "CREDITS",       target = "credits",  y = h * 0.4 + 140, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 },
		{ text = "FLEE (QUIT)",   target = "quit",     y = h * 0.4 + 210, w = 320, h = 55, scale = 1, hover = false, clickScale = 1 }
	}

	love.graphics.setFont(self.font)
end

function MenuScene:update(dt)
	self.time = self.time + dt
	DungeonShader:update(dt)

	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	if self.buttons then
		for i, btn in ipairs(self.buttons) do
			local bx = cx - btn.w / 2
			local by = btn.y
			btn.hover = (mx >= bx and mx <= bx + btn.w and my >= by and my <= by + btn.h)

			local targetScale = btn.hover and 1.05 or 1.0
			btn.scale = lerp(btn.scale, targetScale, dt * 10)
			btn.clickScale = lerp(btn.clickScale, 1.0, dt * 15)
		end
	end
end

function MenuScene:draw()
	love.graphics.push("all")
	DungeonShader:draw()

	local w, h = love.graphics.getDimensions()
	local cx = w / 2

	if self.titleFont then
		love.graphics.setFont(self.titleFont)
	end
	-- Deep shadow / drop shadow
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.printf("BROADCAST DUNGEON", 4, h * 0.15 + 4, w, "center")

	-- Flickering title text color simulating torchlight
	local flicker = (math.sin(self.time * 6) + math.sin(self.time * 11)) * 0.1 + 0.9
	love.graphics.setColor(0.9 * flicker, 0.8 * flicker, 0.6 * flicker, 1)
	love.graphics.printf("BROADCAST DUNGEON", 0, h * 0.15, w, "center")

	if self.font then
		love.graphics.setFont(self.font)
	end

	if self.buttons then
		for i, btn in ipairs(self.buttons) do
			local totalScale = btn.scale * btn.clickScale
			local bw = btn.w * totalScale
			local bh = btn.h * totalScale
			local bx = cx - bw / 2
			local by = btn.y + (btn.h - bh) / 2

			-- Ambient glow behind hovered button
			if btn.hover then
				love.graphics.setColor(0.8, 0.4, 0.1, 0.2)
				love.graphics.rectangle("fill", bx - 5, by - 5, bw + 10, bh + 10, 8, 8)
			end

			-- Button backgrounds (Dark stone appearance)
			if btn.hover then
				love.graphics.setColor(0.15, 0.12, 0.1, 0.95)
			else
				love.graphics.setColor(0.05, 0.05, 0.06, 0.9)
			end
			love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

			-- Thin torchlight rim / stone carving rim
			if btn.hover then
				love.graphics.setColor(0.8, 0.5, 0.2, 0.8)
			else
				love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
			end
			love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

			-- Text styling
			if btn.hover then
				love.graphics.setColor(1, 0.9, 0.7, 1)
			else
				love.graphics.setColor(0.6, 0.6, 0.65, 1)
			end
			local fontHeight = self.font and self.font:getHeight() or 16
			love.graphics.printf(btn.text, bx, by + bh / 2 - fontHeight / 2, bw, "center")
		end
	end
	love.graphics.pop()
end

function MenuScene:mousepressed(x, y, button, istouch, presses)
	if button == 1 and self.buttons then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 0.95
			end
		end
	end
end

function MenuScene:mousereleased(x, y, button, istouch, presses)
	if button == 1 and self.buttons then
		for i, btn in ipairs(self.buttons) do
			if btn.hover then
				btn.clickScale = 1.0
				if btn.target == "quit" then
					love.event.quit()
				else
					if SceneManager then
						SceneManager:switch(btn.target, { kind = "fade", duration = 0.4 })
					end
				end
			end
		end
	end
end

function MenuScene:keypressed(key)
	if key == "return" then
		SceneManager:switch("game", { kind = "fade", duration = 0.4 })
	end
	if key == "escape" then
		love.event.quit()
	end
end

return MenuScene
