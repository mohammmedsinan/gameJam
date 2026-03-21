local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
local SkillCheck = require("src/game/skillcheck");
local CameraShake = require("src/utils/shake")
local DamageNumbers = require("src/utils/damage_numbers")
local MultAnim = require("src/utils/multi_animation")
local CardHand = require("src/ui/CardHand")

Player = require("src/entities/player");
Boss = require("src/entities/boss");
Signal = require("src/utils/signal")

bus = Signal.new()
local GameScene = {}
local shake, dmg
local cardHand

GameScene.__index = GameScene

function GameScene:load()
	boss = Boss.new(bus)
	player = Player.new(bus)
	dmg = DamageNumbers.new();
	CrTv:load()
	chatBox:load()
	shopper:load()
	player:load()
	if SK then
		SK:load()
	end
	-- ── Card Hand ────────────────────────────────────────────────────────
	local shopArea = shopper:getShopperScreenDetails()
	local handArea = chatBox:getChatBoxScreenDetails()
	cardHand = CardHand.new({
		layout        = "nfan",
		x             = handArea.posX + 20,
		y             = handArea.posY + 20,
		width         = handArea.width - 40,
		cardWidth     = 80,
		cardHeight    = 112,
		onCardClicked = function(card)
			print("[Card Clicked] " .. card.name .. " (" .. card:getRarityName() .. ")")
		end,
	})
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
	shake:apply()
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.rectangle("fill", 10, 10, 320, 100, 8, 8)
	local trauma_pct = math.floor(shake.trauma * 100)
	local bar_w = math.floor(shake.trauma * 200)
	love.graphics.setColor(0.25, 0.25, 0.25)
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
	if key == "tab" then
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
		cardHand:setCards(player:getInventoryCards())
	end
end

function GameScene:mousepressed(x, y, button)
	cardHand:mousepressed(x, y, button)
end

function GameScene:mousereleased(x, y, button)
	cardHand:mousereleased(x, y, button)
end

function GameScene:mousemoved(x, y, dx, dy)
	cardHand:mousemoved(x, y, dx, dy)
end

return GameScene
