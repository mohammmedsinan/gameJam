local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
local SkillCheck = require("src/game/skillcheck");
local CameraShake = require("src/utils/shake")
local DamageNumbers = require("src/utils/damage_numbers")
local MultAnim = require("src/utils/multi_animation")
local CardHand = require("src/ui/CardHand")
local DungeonShader = require("src/utils/DungeonShader")

Player = require("src/entities/player");
Boss = require("src/entities/boss");
Signal = require("src/utils/signal")

bus = Signal.new()
local GameScene = {}
local shake, dmg
local cardHand

GameScene.__index = GameScene

function GameScene:load()
	local handArea = chatBox:getChatBoxScreenDetails()
	cardHand = CardHand.new({
		layout        = "nfan",
		x             = handArea.posX + 20,
		y             = handArea.posY + 20,
		width         = handArea.width - 20,
		cardWidth     = 80,
		cardHeight    = 112,
		onCardClicked = function(card)
			print("[Card Clicked] " .. card.name .. " (" .. card:getRarityName() .. ")")
		end,
	})
	boss = Boss.new(bus)
	player = Player.new(bus, cardHand)
	dmg = DamageNumbers.new();
	CrTv:load()
	chatBox:load()
	shopper:load()
	player:load()
	if SK then
		SK:load()
	end
	-- ── Card Hand ────────────────────────────────────────────────────────
	cardHand:setCards(player:getInventoryCards())
	shake = CameraShake.new({
		max_offset_x = 50,
		max_offset_y = 40,
		max_rotation = 0.07,
		trauma_decay = 1.0,
		noise_speed  = 80,
		pivot_x      = 400,
		pivot_y      = 300,
	})
end

function GameScene:update(dt)
	DungeonShader:update(dt)
	CrTv:update(dt)
	chatBox:update(dt)
	shopper:update(dt)
	player:update(dt)
	boss:update(dt)
	shake:update(dt)
	MultAnim.update(dt)
	bus:flush()
	dmg:update(dt)
	cardHand:update(dt)
	if SK then
		SK:update(dt)
	end
end

function GameScene:draw()
	DungeonShader:draw()
	shake:apply()
	love.graphics.setColor(0.05, 0.05, 0.06, 0.9)
	love.graphics.rectangle("fill", 10, 10, 320, 100, 8, 8)
	love.graphics.setColor(0.55, 0.40, 0.20, 0.9)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", 10, 10, 320, 100, 8, 8)
	love.graphics.setLineWidth(1)
	local trauma_pct = math.floor(shake.trauma * 100)
	local bar_w = math.floor(shake.trauma * 200)
	love.graphics.setColor(0.1, 0.1, 0.12)
	love.graphics.rectangle("fill", 20, 15, 200, 16, 4, 4)
	love.graphics.setColor(1, 0.35, 0.15)
	love.graphics.rectangle("fill", 20, 15, bar_w, 16, 4, 4)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Trauma: " .. trauma_pct .. "%", 228, 14)
	love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
	CrTv:draw()
	chatBox:draw()
	shopper:draw()
	player:draw()
	boss:draw()
	dmg:draw()
	MultAnim.draw()
	cardHand:draw()
	if SK then
		SK:draw()
	end
	shake:pop()
end

function GameScene:keypressed(key)
	if key == "escape" then
		SceneManager:switch("menu", {
			kind = "fade",
			duration = 0.3
		})
	end

	if key == "b" then
		SceneManager:switch("shop", {
			kind = "fade",
			duration = 0.3
		})
	end

	if (SK) then
		SK:keypressed(key)
	end

	if key == "space" then
		if SK then
			SK = nil
		else
			SK = SkillCheck:new({
				successArcSize = math.rad(75),
				greatArcSize = math.rad(12),
				pointerSpeed = 7,
				onSuccess = function()
					print("success!")
					shake:add_trauma(0.4)
				end,
				onGreat = function()
					print("GREAT!")
					shake:add_trauma(0.8)
					bs = boss:details();
					MultAnim.spawnChain(bs.x, bs.y, { 3 }, function()
						dmg:spawn(bs.x, bs.y, love.math.random(100), "crit");
					end)
				end,
				onMiss = function()
					print("miss...")
					shake:add_trauma(0.2)
				end
			})
			SK:Spawn()
		end
	end

	if key == "q" then
		player:keypressed(key)
	end

	if key == "d" then
		local cards = player:getInventoryCards()
		for _, card in ipairs(cards) do
			for key, value in pairs(card) do
				print(key, value)
			end
		end
	end
end

function GameScene:mousepressed(x, y, button)
	cardHand:mousepressed(x, y, button)
	shopper:mousepressed(x, y, button)
end

function GameScene:mousereleased(x, y, button)
	cardHand:mousereleased(x, y, button)
	shopper:mousereleased(x, y, button)
end

function GameScene:mousemoved(x, y, dx, dy)
	cardHand:mousemoved(x, y, dx, dy)
	shopper:mousemoved(x, y, dx, dy)
end

return GameScene
