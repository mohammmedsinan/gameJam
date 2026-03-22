local chatBox = require("src/ui/chatBox");
local shopper = require("src/ui/shopper");
local CrTv = require("src/ui/CrTv");
local CameraShake = require("src/utils/shake")
local DamageNumbers = require("src/utils/damage_numbers")
local MultAnim = require("src/utils/multi_animation")
local CardHand = require("src/ui/CardHand")
local DungeonShader = require("src/utils/DungeonShader")
local combat = require("src/utils/game_combat")
local StatsPanel = require("src/ui/StatsPanel")

Player = require("src/entities/player");
Boss = require("src/entities/boss");
Signal = require("src/utils/signal")

bus = Signal.new()
local GameScene = {}
local shake, dmg
local cardHand
local statsPanel

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

	-- ── Card Hand ────────────────────────────────────────────────────────
	cardHand:setCards(player:getInventoryCards())
	-- ── Stats Panel ──────────────────────────────────────────────────────
	statsPanel = StatsPanel.new()
	shake = CameraShake.new({
		max_offset_x = 50,
		max_offset_y = 40,
		max_rotation = 0.07,
		trauma_decay = 1.0,
		noise_speed  = 80,
		pivot_x      = 400,
		pivot_y      = 300,
	})

	-- ── Combat Engine ────────────────────────────────────────────────────
	combat:load()
	combat:setRefs(player, boss, shake, dmg, MultAnim)
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
	if statsPanel then
		statsPanel:update(dt)
	end
	-- ── Combat Engine Update ─────────────────────────────────────────────
	combat:update(dt)
end

function GameScene:draw()
	DungeonShader:draw()
	shake:apply()
	CrTv:draw()
	chatBox:draw()
	shopper:draw()
	player:draw()
	boss:draw()
	dmg:draw()
	MultAnim.draw()
	cardHand:draw()
	-- ── Combat Engine Draw (on top of game world, inside shake) ──────────
	combat:draw()
	shake:pop()
	-- draw HUD on top (outside camera shake)
	if statsPanel then
		statsPanel:draw()
	end
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

	-- ── Combat engine handles space and combat input ─────────────────────
	if combat:keypressed(key) then
		return -- combat consumed the key
	end

	if key == "q" then
		player:keypressed(key)
	end

	if key == "d" then
		local cards = player:getInventoryCards()
		for _, card in ipairs(cards) do
			for k, value in pairs(card) do
				print(k, value)
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
