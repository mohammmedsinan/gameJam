-- ─────────────────────────────────────────────────────────────────────────────
--  game_combat.lua  –  Turn-based combat engine for BroadcastDungeon
--  State machine: IDLE → CTA → PLAYER_ATTACK(×3) → PARRY_CTA → PLAYER_PARRY(×3)
--                 → ENEMY_TURN → RESOLUTION → loop / VICTORY / DEFEAT
-- ─────────────────────────────────────────────────────────────────────────────

local CrTv              = require("src/ui/CrTv")
local SkillCheck        = require("src/game/skillcheck")
local json              = require("src/utils/json")

local combat            = {}
combat.__index          = combat

-- ── States ───────────────────────────────────────────────────────────────────
local STATE             = {
	IDLE          = "IDLE",
	CTA           = "CTA",
	PLAYER_ATTACK = "PLAYER_ATTACK",
	PARRY_CTA     = "PARRY_CTA", -- NEW: pause before parry phase
	PLAYER_PARRY  = "PLAYER_PARRY",
	ENEMY_TURN    = "ENEMY_TURN",
	RESOLUTION    = "RESOLUTION",
	VICTORY       = "VICTORY",
	DEFEAT        = "DEFEAT",
	STAGE_CLEAR   = "STAGE_CLEAR",
	GAME_COMPLETE = "GAME_COMPLETE",
}

-- ── Palette (dungeon dark + brass) ───────────────────────────────────────────
local C                 = {
	panelBg    = { 0.07, 0.07, 0.09, 0.92 },
	border     = { 0.85, 0.55, 0.10, 1.00 },
	borderDim  = { 0.55, 0.35, 0.06, 0.60 },
	title      = { 0.95, 0.80, 0.35, 1.00 },
	label      = { 0.55, 0.55, 0.65, 1.00 },
	value      = { 0.95, 0.92, 0.85, 1.00 },
	attackText = { 1.00, 0.35, 0.20, 1.00 },
	parryText  = { 0.30, 0.70, 1.00, 1.00 },
	ctaGlow    = { 0.85, 0.55, 0.10, 1.00 },
	ctaBg      = { 0.0, 0.0, 0.0, 0.70 },
	hpBg       = { 0.18, 0.07, 0.07, 1.00 },
	hpFill     = { 0.82, 0.18, 0.18, 1.00 },
	hpText     = { 1.00, 0.88, 0.88, 1.00 },
	pipDone    = { 0.85, 0.55, 0.10, 1.00 },
	pipCurrent = { 1.00, 0.90, 0.30, 1.00 },
	pipEmpty   = { 0.25, 0.25, 0.30, 0.80 },
	victory    = { 0.30, 1.00, 0.50, 1.00 },
	defeat     = { 1.00, 0.20, 0.20, 1.00 },
	enemyTurn  = { 0.90, 0.25, 0.25, 1.00 },
}

-- ── Combat tuning ────────────────────────────────────────────────────────────
local ATTACK_CHECKS     = 3
local PARRY_CHECKS      = 3
local GREAT_QUALITY     = 1.0 -- 100% base damage on great
local SUCCESS_QUALITY   = 0.6 -- 60% base damage on success
local ENEMY_TURN_DELAY  = 1.2 -- seconds before enemy attacks
local RESOLUTION_DELAY  = 1.5 -- seconds before next round/encounter
local STAGE_CLEAR_DELAY = 2.0
local CTA_PULSE_SPEED   = 3.0

-- ── Font cache (created once, reused every frame) ────────────────────────────
local FONTS             = {}
local function getFont(size)
	if not FONTS[size] then
		FONTS[size] = love.graphics.newFont(size)
	end
	return FONTS[size]
end

-- ── Skill check configs that get harder each stage ───────────────────────────
local function getSkillCheckConfig(stageIndex, isParry)
	local baseArc     = 75
	local baseGreat   = 12
	local baseSpeed   = 7
	local arcShrink   = math.max(25, baseArc - (stageIndex - 1) * 4)
	local greatShrink = math.max(5, baseGreat - (stageIndex - 1) * 0.6)
	local speedUp     = baseSpeed + (stageIndex - 1) * 0.4
	return {
		successArcSize = math.rad(arcShrink),
		greatArcSize   = math.rad(greatShrink),
		pointerSpeed   = speedUp,
	}
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Load
-- ─────────────────────────────────────────────────────────────────────────────
function combat:load()
	-- Audio is handled by Audio module

	-- Load stages
	local raw = love.filesystem.read("src/entities/stages.json")
	local data = json.decode(raw)
	self.allStages = data and data.stages or {}

	-- Play stages in order (sorted by difficulty in stages.json)
	self.stageOrder = {}
	for i = 1, #self.allStages do
		self.stageOrder[i] = i
	end

	-- Progress tracking
	self.currentStageIdx     = 1
	self.currentEncounterIdx = 1
	self.state               = STATE.CTA

	-- Combat round data
	self.attackResults       = {}
	self.parryResults        = {}
	self.checkIndex          = 0
	self.totalDamage         = 0
	self.totalParry          = 0
	self.enemyDamageDealt    = 0

	-- Timers
	self.enemyTimer          = 0
	self.resolutionTimer     = 0
	self.stageClearTimer     = 0
	self.ctaPulse            = 0
	self.parryCTAPulse       = 0

	-- Turn indicator animation
	self.turnIndicator       = { text = "", color = { 1, 1, 1, 1 }, alpha = 0, scale = 1, timer = 0 }

	-- External refs (set by GameScene)
	self.player              = nil
	self.boss                = nil
	self.shake               = nil
	self.dmg                 = nil
	self.multAnim            = nil
	self.SK                  = nil
	self.fx                  = nil
	self.cardHand            = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Setup references from GameScene
-- ─────────────────────────────────────────────────────────────────────────────
function combat:setRefs(playerRef, bossRef, shakeRef, dmgRef, multAnimRef)
	self.player   = playerRef
	self.boss     = bossRef
	self.shake    = shakeRef
	self.dmg      = dmgRef
	self.multAnim = multAnimRef
end

function combat:setFXRef(fxRef)
	self.fx = fxRef
end

function combat:setCardHandRef(handRef)
	self.cardHand = handRef
end

-- Helper: trigger the card activation animation in the sidebar.
-- effectType is the card.effect string (e.g. "chain_mult").
function combat:_triggerCard(effectType)
	if self.cardHand and effectType then
		self.cardHand:triggerEffect(effectType)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Get current encounter data
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_getCurrentStage()
	local idx = self.stageOrder[self.currentStageIdx]
	return self.allStages[idx]
end

function combat:_getCurrentEncounter()
	local stage = self:_getCurrentStage()
	if stage then
		return stage.encounters[self.currentEncounterIdx]
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Load encounter into boss (applies difficulty scaling by progression)
--  Stage 1 = easy (0.5x), Stage 5 = moderate (1.25x), Stage 10 = hard (2.5x)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_getDifficultyScale()
	-- Gentle ramp: stage 1 → 0.8, stage 10 → 1.4
	-- (stages.json already has escalating base stats)
	local progress = (self.currentStageIdx - 1) / math.max(1, #self.stageOrder - 1)
	return 0.8 + progress * 0.6
end

function combat:_loadEncounter()
	local enc = self:_getCurrentEncounter()
	if enc and self.boss then
		local scale = self:_getDifficultyScale()
		local scaled = {
			name    = enc.name,
			health  = math.max(1, math.floor(enc.health * scale)),
			attack  = math.max(1, math.floor(enc.attack * scale)),
			defence = math.max(0, math.floor((enc.defence or 0) * scale)),
			effect  = enc.effect,
			isBoss  = enc.isBoss,
		}
		self.boss:setFromEncounter(scaled)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Calculate card bonuses (reads ALL new card effect types)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_getCardBonuses()
	local bonuses = {
		-- Skill check modifiers
		speedMult       = 1.0,
		successArcMult  = 1.0,
		greatArcMult    = 1.0,
		extraRounds     = 0,
		missRetryChance = 0,
		-- Damage modifiers
		chainMult       = 0,
		comboMult       = 0,
		greatDmgMult    = 0,
		atkMult         = 1.0,
		defMult         = 1.0,
		lifestealPct    = 0,
		dmgPerKill      = 0,
		-- Defense modifiers
		flatParryArmor  = 0,
		reflectPct      = 0,
		counterDmg      = 0,
		stunReduction   = 0,
		-- Healing
		healPerTurn     = 0,
		-- New effects
		missPenalty     = 0, -- self-damage on miss (Double Down)
		successMult     = 1.0, -- multiplier on success hits (Double Down)
		hpPerKill       = 0, -- +maxHP on kill (Bone Armor)
		hasEchoStrike   = false, -- 3rd attack repeats best (Echo Strike)
		hasWitchsBrew   = false, -- random heal/damage at round end
		witchsHeal      = 0,
		witchsPenalty   = 0,
		witchsChance    = 0,
		hasLastStand    = false, -- triple dmg at low HP
		lastStandThresh = 0,
		lastStandMult   = 1.0,
		defSteal        = 0, -- steal enemy def on great (Siphon Soul)
		bleedDmg        = 0, -- bleed damage per round
		bleedRounds     = 0, -- bleed duration
		hasRetribution  = false, -- +1% dmg per 1% HP missing
		hasResonance    = false, -- consecutive greats amplify
		fortifyStack    = 0, -- stacking armor per consecutive parry
		ghostPct        = 0, -- ghost hit % (Doppelganger)
		hasPhoenix      = false, -- revive once per stage
		phoenixPct      = 0,
	}
	if not self.player then return bonuses end

	for _, card in ipairs(self.player:getInventoryCards()) do
		local e = card.effect
		local s = card.stats or {}

		if e == "chain_mult" then
			bonuses.chainMult = bonuses.chainMult + (s.multBonus or 0)
		elseif e == "widen_great" then
			bonuses.greatArcMult = bonuses.greatArcMult * (s.greatArcMult or 1)
		elseif e == "slow_pointer" then
			bonuses.speedMult = bonuses.speedMult * (s.speedMult or 1)
		elseif e == "flat_parry" then
			bonuses.flatParryArmor = bonuses.flatParryArmor + (s.armor or 0)
		elseif e == "reflect_great" then
			bonuses.reflectPct = bonuses.reflectPct + (s.reflectPct or 0)
		elseif e == "lifesteal_great" then
			bonuses.lifestealPct = bonuses.lifestealPct + (s.lifestealPct or 0)
		elseif e == "miss_reroll" then
			bonuses.missRetryChance = math.min(1, bonuses.missRetryChance + (s.missRetryChance or 0))
		elseif e == "full_combo" then
			bonuses.comboMult = bonuses.comboMult + (s.comboMult or 0)
		elseif e == "glass_cannon" then
			bonuses.atkMult = bonuses.atkMult * (s.atkMult or 1)
			bonuses.defMult = bonuses.defMult * (s.defMult or 1)
		elseif e == "heal_per_turn" then
			bonuses.healPerTurn = bonuses.healPerTurn + (s.heal or 0)
		elseif e == "extra_rounds" then
			bonuses.extraRounds = bonuses.extraRounds + (s.extraRounds or 0)
		elseif e == "great_multiplier" then
			bonuses.greatDmgMult = bonuses.greatDmgMult + (s.greatDmgMult or 0)
		elseif e == "counter_hit" then
			bonuses.counterDmg = bonuses.counterDmg + (s.counterDmg or 0)
		elseif e == "tunnel_vision" then
			bonuses.successArcMult = bonuses.successArcMult * (s.successArcMult or 1)
			bonuses.greatArcMult   = bonuses.greatArcMult * (s.greatArcMult or 1)
		elseif e == "soul_harvest" then
			bonuses.dmgPerKill = bonuses.dmgPerKill + (s.dmgPerKill or 0)
		elseif e == "stun_parry" then
			bonuses.stunReduction = math.min(0.9, bonuses.stunReduction + (s.stunReduction or 0))
			-- ── New effects ──────────────────────────────────────────────────
		elseif e == "double_down" then
			bonuses.missPenalty = bonuses.missPenalty + (s.missPenalty or 0)
			bonuses.successMult = bonuses.successMult * (s.successMult or 1)
		elseif e == "bone_armor" then
			bonuses.hpPerKill = bonuses.hpPerKill + (s.hpPerKill or 0)
		elseif e == "echo_strike" then
			bonuses.hasEchoStrike = true
		elseif e == "witchs_brew" then
			bonuses.hasWitchsBrew = true
			bonuses.witchsHeal    = bonuses.witchsHeal + (s.healAmt or 0)
			bonuses.witchsPenalty = bonuses.witchsPenalty + (s.penaltyAmt or 0)
			bonuses.witchsChance  = s.chance or 0.5
		elseif e == "last_stand" then
			bonuses.hasLastStand    = true
			bonuses.lastStandThresh = math.max(bonuses.lastStandThresh, s.threshold or 0.25)
			bonuses.lastStandMult   = math.max(bonuses.lastStandMult, s.dmgMult or 3.0)
		elseif e == "siphon_soul" then
			bonuses.defSteal = bonuses.defSteal + (s.defSteal or 0)
		elseif e == "overcharge" then
			bonuses.extraRounds = bonuses.extraRounds + (s.extraRounds or 0)
			bonuses.speedMult   = bonuses.speedMult * (s.speedMult or 1)
		elseif e == "bleed" then
			bonuses.bleedDmg    = bonuses.bleedDmg + (s.bleedDmg or 0)
			bonuses.bleedRounds = math.max(bonuses.bleedRounds, s.bleedRounds or 0)
		elseif e == "retribution" then
			bonuses.hasRetribution = true
		elseif e == "resonance" then
			bonuses.hasResonance = true
		elseif e == "fortify" then
			bonuses.fortifyStack = bonuses.fortifyStack + (s.stackArmor or 0)
		elseif e == "doppelganger" then
			bonuses.ghostPct = bonuses.ghostPct + (s.ghostPct or 0)
		elseif e == "phoenix" then
			bonuses.hasPhoenix = true
			bonuses.phoenixPct = math.max(bonuses.phoenixPct, s.revivePct or 0.5)
		end
	end
	return bonuses
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Spawn a skill check for the current phase (applies card mods)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_spawnSkillCheck()
	local isParry      = (self.state == STATE.PLAYER_PARRY)
	local cfg          = getSkillCheckConfig(self.currentStageIdx, isParry)
	local bonuses      = self:_getCardBonuses()

	-- Apply card-based skill check mods
	local finalSpeed   = cfg.pointerSpeed * bonuses.speedMult
	local finalSuccess = cfg.successArcSize * bonuses.successArcMult
	local finalGreat   = cfg.greatArcSize * bonuses.greatArcMult
	local finalRounds  = 3 + bonuses.extraRounds

	-- ── Visual state: player attacks or parries ──────────────────────────
	if isParry then
		if self.player then self.player:setVisualState("idle") end
		if self.boss then self.boss:setVisualState("attack") end
	else
		if self.player then self.player:setVisualState("attack") end
		if self.boss then self.boss:setVisualState("idle") end
	end

	local selfRef = self
	self.SK       = SkillCheck:new({
		successArcSize = finalSuccess,
		greatArcSize   = finalGreat,
		pointerSpeed   = finalSpeed,
		numberOfRounds = finalRounds,
		onSuccess      = function(rounds)
			selfRef:_onSkillCheckResult("success", rounds)
		end,
		onGreat        = function(rounds)
			selfRef:_onSkillCheckResult("great", rounds)
		end,
		onMiss         = function()
			selfRef:_onSkillCheckResult("miss", 0)
		end,
		onDespawn      = function()
			selfRef.SK = nil
			selfRef:_onSkillCheckDespawn()
		end,
	})
	self.SK:Spawn()

	if Audio then Audio.playSFX("skill_start") end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Skill check result callback (handles miss reroll, lifesteal, counter-hit)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_onSkillCheckResult(quality, rounds)
	local bonuses = self:_getCardBonuses()
	local isParry = (self.state == STATE.PLAYER_PARRY)

	-- ── Miss Reroll (Lucky Coin effect) ──────────────────────────────────
	if quality == "miss" and bonuses.missRetryChance > 0 then
		if love.math.random() < bonuses.missRetryChance then
			quality      = "success"
			rounds       = 1
			-- Show "LUCKY!" feedback
			local bs     = self.boss:details()
			local tx, ty = isParry and (self.player.drawX or 0) or bs.x,
				isParry and (self.player.drawY or 0) or bs.y
			self.dmg:spawn(tx, ty - 30, 0, "xp", { prefix = "LUCKY! " })
			if self.fx then self.fx:burst("lucky", tx, ty) end
			self:_triggerCard("miss_reroll")
		end
	end

	-- ── Double Down: self-damage on miss ──────────────────────────────────
	if quality == "miss" and bonuses.missPenalty > 0 and self.player then
		self.player.health = math.max(0, self.player.health - bonuses.missPenalty)
		local px = self.player.drawX or 0
		local py = self.player.drawY or 0
		self.dmg:spawn(px, py, bonuses.missPenalty, "normal", { prefix = "PENALTY! " })
		if self.fx then self.fx:burst("penalty", px, py) end
		self:_triggerCard("double_down")
	end

	local results = isParry and self.parryResults or self.attackResults
	table.insert(results, { quality = quality, multiplier = rounds })

	-- Visual feedback
	local bs = self.boss:details()
	if not isParry then
		-- ── Chain Mult: add bonus mult items per consecutive hit ─────────
		local chainBonus = 0
		if quality ~= "miss" and bonuses.chainMult > 0 then
			-- Count consecutive non-miss hits before this one
			local streak = 0
			for i = #self.attackResults - 1, 1, -1 do
				if self.attackResults[i].quality ~= "miss" then
					streak = streak + 1
				else
					break
				end
			end
			chainBonus = streak * bonuses.chainMult
			if chainBonus > 0 then self:_triggerCard("chain_mult") end
		end

		if quality == "great" then
			if self.boss then self.boss:setVisualState("damage") end
			self.shake:add_trauma(1)
			if Audio then Audio.playSFX("hit_great") end
			local multChain = {}
			for i = 1, math.max(1, rounds) + chainBonus do
				table.insert(multChain, rounds)
			end
			self.multAnim.spawnChain(bs.x, bs.y, multChain, function()
				local dmgVal = self:_calcSingleAttack(quality, rounds)
				self.dmg:spawn(bs.x, bs.y, math.floor(dmgVal), "crit")
				if self.fx then self.fx:burst("great", bs.x, bs.y) end
				-- ── Lifesteal on Great ────────────────────────────────────
				if bonuses.lifestealPct > 0 and self.player then
					local healAmt = math.floor(dmgVal * bonuses.lifestealPct)
					if healAmt > 0 then
						self.player.health = math.min(self.player.maxHealth, self.player.health + healAmt)
						local px = self.player.drawX or 0
						local py = self.player.drawY or 0
						self.dmg:spawn(px, py, healAmt, "heal")
						if self.fx then self.fx:burst("heal", px, py) end
						self:_triggerCard("lifesteal_great")
					end
				end
				-- ── Siphon Soul: steal enemy defence on Great ─────────────
				if bonuses.defSteal > 0 and self.boss then
					self.boss.defence = math.max(0, (self.boss.defence or 0) - bonuses.defSteal)
					self.dmg:spawn(bs.x, bs.y - 20, bonuses.defSteal, "xp",
						{ prefix = "-", suffix = " DEF" })
					if self.fx then self.fx:burst("stun", bs.x, bs.y - 20) end
					self:_triggerCard("siphon_soul")
				end
			end)
		elseif quality == "success" then
			if self.boss then self.boss:setVisualState("damage") end
			self.shake:add_trauma(0.4)
			if Audio then Audio.playSFX("hit_success") end
			local multChain = { rounds }
			for i = 1, chainBonus do
				table.insert(multChain, rounds)
			end
			self.multAnim.spawnChain(bs.x, bs.y, multChain, function()
				local dmgVal = self:_calcSingleAttack(quality, rounds)
				self.dmg:spawn(bs.x, bs.y, math.floor(dmgVal), "normal")
				if self.fx then self.fx:burst("success", bs.x, bs.y) end
			end)
		else
			self.shake:add_trauma(0.2)
			self.dmg:spawn(bs.x, bs.y, 0, "miss")
			if self.fx then self.fx:burst("miss", bs.x, bs.y) end
			if Audio then Audio.playSFX("hit_miss") end
		end
	else
		-- ── Parry feedback ───────────────────────────────────────────────
		local px = self.player.drawX or 0
		local py = self.player.drawY or 0
		if quality ~= "miss" then
			local parryVal = self:_calcSingleParry(quality, rounds)
			self.dmg:spawn(px, py, math.floor(parryVal), "shield")
			if self.fx then self.fx:burst("shield", px, py) end
			if Audio then Audio.playSFX(quality == "great" and "hit_great" or "hit_success") end
			if quality == "great" then
				self:_triggerCard("flat_parry")
				self:_triggerCard("fortify")
			end
			-- ── Counter Hit: damage enemy on successful parry ────────────
			if bonuses.counterDmg > 0 and self.boss then
				self.boss.health = math.max(0, self.boss.health - bonuses.counterDmg)
				self.dmg:spawn(bs.x, bs.y, bonuses.counterDmg, "normal")
				if self.fx then self.fx:burst("counter", bs.x, bs.y) end
				self:_triggerCard("counter_hit")
			end
			-- ── Stun: mark great parries for stun reduction ──────────────
			if quality == "great" and bonuses.stunReduction > 0 then
				self._hasStunParry = true
				if self.fx then self.fx:burst("stun", bs.x, bs.y) end
				self:_triggerCard("stun_parry")
			end
			-- ── Reflect: mark great parries for reflect ──────────────────
			if quality == "great" and bonuses.reflectPct > 0 then
				self._hasReflectParry = true
				if self.fx then self.fx:burst("reflect", bs.x, bs.y) end
				self:_triggerCard("reflect_great")
			end
		else
			self.dmg:spawn(px, py, 0, "miss")
			if self.fx then self.fx:burst("shield_miss", px, py) end
			if Audio then Audio.playSFX("hit_miss") end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Calculate damage for a single attack check
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_calcSingleAttack(quality, multiplier)
	if quality == "miss" then return 0 end
	local bonuses = self:_getCardBonuses()
	local baseDmg = (self.player and self.player.damage or 1)
	local qMult   = (quality == "great") and GREAT_QUALITY or SUCCESS_QUALITY
	local dmgVal  = baseDmg * qMult * math.max(1, multiplier)
	-- Glass Cannon
	dmgVal        = dmgVal * bonuses.atkMult
	-- Double Down: boost success hits
	if quality == "success" and bonuses.successMult > 1 then
		dmgVal = dmgVal * bonuses.successMult
	end
	-- Great Multiplier card
	if quality == "great" and bonuses.greatDmgMult > 0 then
		dmgVal = dmgVal * bonuses.greatDmgMult
	end
	-- Last Stand: massive boost at low HP
	if bonuses.hasLastStand and self.player then
		local hpPct = self.player.health / math.max(1, self.player.maxHealth)
		if hpPct <= bonuses.lastStandThresh then
			dmgVal = dmgVal * bonuses.lastStandMult
		end
	end
	-- Retribution: +1% dmg per 1% HP missing
	if bonuses.hasRetribution and self.player then
		local missingPct = 1 - (self.player.health / math.max(1, self.player.maxHealth))
		dmgVal = dmgVal * (1 + missingPct)
	end
	-- Resonance: consecutive great hits amplify (tracked via attackResults)
	if bonuses.hasResonance and quality == "great" then
		local consecutiveGreats = 0
		for i = #self.attackResults, 1, -1 do
			if self.attackResults[i].quality == "great" then
				consecutiveGreats = consecutiveGreats + 1
			else
				break
			end
		end
		if consecutiveGreats >= 1 then
			dmgVal = dmgVal * math.pow(2, math.min(consecutiveGreats, 3))
		end
	end
	return dmgVal
end

function combat:_calcSingleParry(quality, multiplier)
	if quality == "miss" then return 0 end
	local bonuses  = self:_getCardBonuses()
	local baseDef  = (self.player and self.player.defence or 0) + bonuses.flatParryArmor
	local qMult    = (quality == "great") and GREAT_QUALITY or SUCCESS_QUALITY
	local parryVal = (baseDef + 2) * qMult * math.max(1, multiplier)
	-- Glass Cannon
	parryVal       = parryVal * bonuses.defMult
	-- Fortify: stacking armor per consecutive parry
	if bonuses.fortifyStack > 0 then
		local streak = 0
		for i = #self.parryResults, 1, -1 do
			if self.parryResults[i].quality ~= "miss" then
				streak = streak + 1
			else
				break
			end
		end
		parryVal = parryVal + (streak * bonuses.fortifyStack)
	end
	return parryVal
end

-- ─────────────────────────────────────────────────────────────────────────────
--  After skill check despawns → advance to next check or next phase
--  Supports: Combo King bonus, heal per turn
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_onSkillCheckDespawn()
	self.checkIndex = self.checkIndex + 1

	if self.state == STATE.PLAYER_ATTACK then
		if self.checkIndex < ATTACK_CHECKS then
			self:_spawnSkillCheck()
		else
			-- Calculate total attack damage
			self.totalDamage = 0
			for _, r in ipairs(self.attackResults) do
				self.totalDamage = self.totalDamage + self:_calcSingleAttack(r.quality, r.multiplier)
			end
			local bonuses = self:_getCardBonuses()
			-- ── Echo Strike: 3rd check repeats best hit ──────────────────
			if bonuses.hasEchoStrike and #self.attackResults >= 3 then
				local bestDmg = 0
				local bestR = nil
				for _, r in ipairs(self.attackResults) do
					local d = self:_calcSingleAttack(r.quality, r.multiplier)
					if d > bestDmg then
						bestDmg = d; bestR = r
					end
				end
				if bestR then
					local echoDmg = self:_calcSingleAttack(bestR.quality, bestR.multiplier)
					self.totalDamage = self.totalDamage + echoDmg
					local bs = self.boss:details()
					self.dmg:spawn(bs.x, bs.y - 30, math.floor(echoDmg), "crit",
						{ prefix = "ECHO! " })
					if self.fx then self.fx:burst("echo", bs.x, bs.y) end
					self:_triggerCard("echo_strike")
				end
			end
			-- ── Combo King: if ALL 3 checks hit, apply combo multiplier ──
			if bonuses.comboMult > 0 then
				local allHit = true
				for _, r in ipairs(self.attackResults) do
					if r.quality == "miss" then
						allHit = false; break
					end
				end
				if allHit then
					self.totalDamage = self.totalDamage * bonuses.comboMult
					local bs = self.boss:details()
					self.dmg:spawn(bs.x, bs.y - 40, math.floor(self.totalDamage), "crit",
						{ prefix = "COMBO! " })
					if self.fx then self.fx:burst("combo", bs.x, bs.y) end
					self:_triggerCard("full_combo")
				end
			end
			-- ── Doppelganger: ghost hit at % of total ────────────────────
			if bonuses.ghostPct > 0 then
				local ghostDmg = math.floor(self.totalDamage * bonuses.ghostPct)
				if ghostDmg > 0 then
					self.totalDamage = self.totalDamage + ghostDmg
					local bs = self.boss:details()
					self.dmg:spawn(bs.x + 20, bs.y - 10, ghostDmg, "normal",
						{ prefix = "GHOST! " })
					if self.fx then self.fx:burst("ghost", bs.x, bs.y) end
					self:_triggerCard("doppelganger")
				end
			end
			self.totalDamage = math.floor(self.totalDamage)
			-- ── Bleed: start bleed timer on boss ─────────────────────────
			if bonuses.bleedDmg > 0 and self.totalDamage > 0 then
				self._bleedStacks = (self._bleedStacks or 0) + bonuses.bleedDmg
				self._bleedRoundsLeft = bonuses.bleedRounds
				local bs = self.boss:details()
				if self.fx then self.fx:burst("bleed", bs.x, bs.y) end
				self:_triggerCard("bleed")
			end
			-- Apply damage to boss
			if self.boss and self.totalDamage > 0 then
				self.boss.health = math.max(0, self.boss.health - self.totalDamage)
				if Audio then Audio.playSFX("hit_enemy") end
			end
			-- Check if boss is dead
			if self.boss and self.boss.health <= 0 then
				self.state = STATE.RESOLUTION
				self.resolutionTimer = 0
				return
			end
			-- Move to PARRY_CTA
			self.state = STATE.PARRY_CTA
			self.parryCTAPulse = 0
			self._hasStunParry = false
			self._hasReflectParry = false
			self:_setTurnIndicator("ENEMY INCOMING!", C.enemyTurn)
		end
	elseif self.state == STATE.PLAYER_PARRY then
		if self.checkIndex < PARRY_CHECKS then
			self:_spawnSkillCheck()
		else
			-- Calculate total parry
			self.totalParry = 0
			for _, r in ipairs(self.parryResults) do
				self.totalParry = self.totalParry + self:_calcSingleParry(r.quality, r.multiplier)
			end
			self.totalParry = math.floor(self.totalParry)
			-- Apply heal from cards
			local bonuses = self:_getCardBonuses()
			if bonuses.healPerTurn > 0 and self.player then
				self.player.health = math.min(self.player.maxHealth, self.player.health + bonuses.healPerTurn)
				local px = self.player.drawX or 0
				local py = self.player.drawY or 0
				self.dmg:spawn(px, py, bonuses.healPerTurn, "heal")
				if self.fx then self.fx:burst("heal", px, py) end
				self:_triggerCard("heal_per_turn")
			end
			-- ── Witch's Brew: coin flip heal or hurt ─────────────────────
			if bonuses.hasWitchsBrew and self.player then
				local px = self.player.drawX or 0
				local py = self.player.drawY or 0
				if love.math.random() < bonuses.witchsChance then
					self.player.health = math.min(self.player.maxHealth,
						self.player.health + bonuses.witchsHeal)
					self.dmg:spawn(px, py, bonuses.witchsHeal, "heal",
						{ prefix = "BREW! +" })
					if self.fx then self.fx:burst("brew_heal", px, py) end
					self:_triggerCard("witchs_brew")
				else
					self.player.health = math.max(0, self.player.health - bonuses.witchsPenalty)
					self.dmg:spawn(px, py, bonuses.witchsPenalty, "normal",
						{ prefix = "BREW! " })
					if self.fx then self.fx:burst("brew_hurt", px, py) end
					self:_triggerCard("witchs_brew")
				end
			end
			-- Move to enemy turn
			self.state = STATE.ENEMY_TURN
			self.enemyTimer = 0
			self:_setTurnIndicator("ENEMY ATTACKS!", C.enemyTurn)
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Turn indicator
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_setTurnIndicator(text, color)
	self.turnIndicator.text  = text
	self.turnIndicator.color = color
	self.turnIndicator.alpha = 1
	self.turnIndicator.scale = 2.5
	self.turnIndicator.timer = 0
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Start Combat
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_startCombat()
	self:_loadEncounter()
	self.state = STATE.PLAYER_ATTACK
	self.checkIndex = 0
	self.attackResults = {}
	self.parryResults = {}
	self.totalDamage = 0
	self.totalParry = 0
	self:_setTurnIndicator("ATTACK!", C.attackText)
	self:_spawnSkillCheck()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Start Parry Phase (called when player presses space on PARRY_CTA)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_startParryPhase()
	self.state = STATE.PLAYER_PARRY
	self.checkIndex = 0
	self.parryResults = {}
	self:_setTurnIndicator("PARRY!", C.parryText)
	self:_spawnSkillCheck()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Advance encounter / stage
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_advanceEncounter()
	local stage = self:_getCurrentStage()
	if not stage then return end

	local bonuses = self:_getCardBonuses()
	local px = self.player and self.player.drawX or 0
	local py = self.player and self.player.drawY or 0

	-- ── Soul Harvest: permanent +dmg on kill ─────────────────────────────
	if bonuses.dmgPerKill > 0 and self.player then
		self.player.damage = self.player.damage + bonuses.dmgPerKill
		self.dmg:spawn(px, py, bonuses.dmgPerKill, "xp",
			{ prefix = "+", suffix = " DMG" })
	end

	-- ── Bone Armor: permanent +maxHP on kill ─────────────────────────────
	if bonuses.hpPerKill > 0 and self.player then
		self.player.maxHealth = self.player.maxHealth + bonuses.hpPerKill
		self.player.health    = self.player.health + bonuses.hpPerKill
		self.dmg:spawn(px, py - 20, bonuses.hpPerKill, "heal",
			{ prefix = "+", suffix = " MAX HP" })
	end

	-- ── Gold Drop: reward player with gold for the kill ───────────────────
	if self.player then
		local enc = self:_getCurrentEncounter()
		local goldDrop
		if enc and enc.isBoss then
			goldDrop = 60 + self.currentStageIdx * 10
		else
			goldDrop = 20 + self.currentStageIdx * 5
		end
		self.player:addGold(goldDrop)
		if Audio then Audio.playSFX("gain_gold") end
		self.dmg:spawn(px, py - 40, goldDrop, "xp",
			{ prefix = "+", suffix = " GOLD" })
	end

	-- Reset bleed stacks on kill
	self._bleedStacks = 0
	self._bleedRoundsLeft = 0
	-- Reset phoenix flag per stage
	-- (phoenix is reset only when advancing stage, see _advanceStage)

	if self.currentEncounterIdx < #stage.encounters then
		self.currentEncounterIdx = self.currentEncounterIdx + 1
		self:_startCombat()
	else
		-- Stage clear!
		if self.currentStageIdx < #self.stageOrder then
			self.state = STATE.STAGE_CLEAR
			self.stageClearTimer = 0
			player.health = player.maxHealth
		else
			self.state = STATE.GAME_COMPLETE
		end
		-- Reset visuals to idle between encounters
		if self.player then self.player:setVisualState("idle") end
		if self.boss then self.boss:setVisualState("idle") end
	end
end

function combat:_advanceStage()
	self.currentStageIdx = self.currentStageIdx + 1
	self.currentEncounterIdx = 1
	self.state = STATE.CTA
	self._phoenixUsed = false -- reset phoenix per stage
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Update
-- ─────────────────────────────────────────────────────────────────────────────
function combat:update(dt)
	-- CTA pulse
	if self.state == STATE.CTA then
		self.ctaPulse = self.ctaPulse + dt * CTA_PULSE_SPEED
	end

	-- Parry CTA pulse
	if self.state == STATE.PARRY_CTA then
		self.parryCTAPulse = self.parryCTAPulse + dt * CTA_PULSE_SPEED
	end

	-- Turn indicator animation
	local ti = self.turnIndicator
	if ti.alpha > 0 then
		ti.timer = ti.timer + dt
		ti.scale = 1.0 + math.max(0, (1.5 * (1 - ti.timer / 0.3)))
		if ti.timer > 1.5 then
			ti.alpha = math.max(0, ti.alpha - dt * 3)
		end
	end

	-- Skill check update
	if self.SK then
		self.SK:update(dt)
	end

	-- Enemy turn: auto-attack after delay
	if self.state == STATE.ENEMY_TURN then
		self.enemyTimer = self.enemyTimer + dt
		if self.enemyTimer >= ENEMY_TURN_DELAY then
			self:_executeEnemyAttack()
		end
	end

	-- Resolution: check if enemy dead or continue
	if self.state == STATE.RESOLUTION then
		self.resolutionTimer = self.resolutionTimer + dt
		if self.resolutionTimer >= RESOLUTION_DELAY then
			if self.boss and self.boss.health <= 0 then
				self:_advanceEncounter()
			else
				self:_startNewRound()
			end
		end
	end

	-- Stage clear delay → send to shop
	if self.state == STATE.STAGE_CLEAR then
		self.stageClearTimer = self.stageClearTimer + dt
		if self.stageClearTimer >= STAGE_CLEAR_DELAY then
			self:_advanceStage()
			-- Send player to shop to buy cards/equipment between stages
			if SceneManager then
				SceneManager:switch("shop", { kind = "fade", duration = 0.4 })
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Start a new combat round (same encounter)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_startNewRound()
	self.state = STATE.PLAYER_ATTACK
	self.checkIndex = 0
	self.attackResults = {}
	self.parryResults = {}
	self.totalDamage = 0
	self.totalParry = 0
	-- ── Bleed: tick damage on boss at start of new round ─────────────────
	if (self._bleedStacks or 0) > 0 and (self._bleedRoundsLeft or 0) > 0 then
		if self.boss then
			self.boss.health = math.max(0, self.boss.health - self._bleedStacks)
			local bs = self.boss:details()
			self.dmg:spawn(bs.x, bs.y, self._bleedStacks, "crit",
				{ prefix = "BLEED! " })
			if self.fx then self.fx:burst("bleed_tick", bs.x, bs.y) end
			self:_triggerCard("bleed")
		end
		self._bleedRoundsLeft = self._bleedRoundsLeft - 1
		if self._bleedRoundsLeft <= 0 then
			self._bleedStacks = 0
		end
		-- Check if bleed killed the boss
		if self.boss and self.boss.health <= 0 then
			self.state = STATE.RESOLUTION
			self.resolutionTimer = 0
			return
		end
	end
	self:_setTurnIndicator("ATTACK!", C.attackText)
	self:_spawnSkillCheck()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Enemy attack execution
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_executeEnemyAttack()
	if not self.player or not self.boss then return end
	local enc = self:_getCurrentEncounter()
	if not enc then return end
	local bonuses = self:_getCardBonuses()

	-- ── Visual state: enemy attacks, player takes damage ─────────────────
	self.boss:setVisualState("attack")
	self.player:setVisualState("damage")

	local enemyAtk = enc.attack
	-- ── Shield Bash stun: reduce enemy attack if great parry landed ──────
	if self._hasStunParry and bonuses.stunReduction > 0 then
		enemyAtk = math.floor(enemyAtk * (1 - bonuses.stunReduction))
		local bs = self.boss:details()
		self.dmg:spawn(bs.x, bs.y, 0, "xp", { prefix = "STUNNED! " })
	end

	local reduction = self.totalParry
	local finalDmg = math.max(1, enemyAtk - reduction)
	self.enemyDamageDealt = finalDmg

	self.player.health = math.max(0, self.player.health - finalDmg)

	local px = self.player.drawX or 0
	local py = self.player.drawY or 0
	self.shake:add_trauma(0.6)
	self.dmg:spawn(px, py, finalDmg, "normal")
	if Audio then Audio.playSFX("hit_player") end

	-- ── Thorns reflect: deal % of enemy damage back on great parry ───────
	if self._hasReflectParry and bonuses.reflectPct > 0 then
		local reflectDmg = math.floor(enemyAtk * bonuses.reflectPct)
		if reflectDmg > 0 and self.boss then
			self.boss.health = math.max(0, self.boss.health - reflectDmg)
			local bs = self.boss:details()
			self.dmg:spawn(bs.x, bs.y, reflectDmg, "crit",
				{ prefix = "REFLECT! " })
		end
	end

	if self.player.health <= 0 then
		-- ── Phoenix Feather: revive once per stage ───────────────────────
		local bonuses2 = self:_getCardBonuses()
		if bonuses2.hasPhoenix and not self._phoenixUsed then
			self._phoenixUsed = true
			local reviveHP = math.max(1, math.floor(self.player.maxHealth * bonuses2.phoenixPct))
			self.player.health = reviveHP
			self.shake:add_trauma(1)
			self.dmg:spawn(px, py, reviveHP, "heal", { prefix = "PHOENIX! +" })
			if self.fx then self.fx:burst("phoenix", px, py) end
			self:_triggerCard("phoenix")
			self.state = STATE.RESOLUTION
			self.resolutionTimer = 0
		else
			self.state = STATE.DEFEAT
		end
	else
		self.state = STATE.RESOLUTION
		self.resolutionTimer = 0
		-- Return to idle visuals after resolution
		self.player:setVisualState("idle")
		self.boss:setVisualState("idle")
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Keypressed
-- ─────────────────────────────────────────────────────────────────────────────
function combat:keypressed(key)
	if key == "space" then
		if self.state == STATE.CTA then
			self:_startCombat()
			return true
		end
		if self.state == STATE.PARRY_CTA then
			self:_startParryPhase()
			return true
		end
		if self.SK then
			self.SK:keypressed(key)
			return true
		end
	end

	if key == "return" or key == "space" then
		if self.state == STATE.DEFEAT or self.state == STATE.GAME_COMPLETE then
			self:_restart()
			return true
		end
	end

	return false
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Restart combat from scratch
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_restart()
	for i = #self.stageOrder, 2, -1 do
		local j = love.math.random(1, i)
		self.stageOrder[i], self.stageOrder[j] = self.stageOrder[j], self.stageOrder[i]
	end
	self.currentStageIdx = 1
	self.currentEncounterIdx = 1
	self.state = STATE.CTA
	self.SK = nil
	if self.player then
		self.player.health = self.player.maxHealth
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw
-- ─────────────────────────────────────────────────────────────────────────────
function combat:draw()
	local TvScreen = CrTv:getCrTvScreenDetails()

	if self.state ~= STATE.IDLE then
		self:_drawStageTracker(TvScreen)
	end

	if self.state ~= STATE.CTA and self.state ~= STATE.IDLE and self.boss then
		self:_drawBossHealthBar(TvScreen)
	end

	if self.SK then
		self.SK:draw()
	end

	self:_drawTurnIndicator(TvScreen)

	if self.state == STATE.CTA then
		self:_drawCTA(TvScreen)
	end

	if self.state == STATE.PARRY_CTA then
		self:_drawParryCTA(TvScreen)
	end

	if self.state == STATE.STAGE_CLEAR then
		self:_drawStageClear(TvScreen)
	end

	if self.state == STATE.GAME_COMPLETE then
		self:_drawGameComplete(TvScreen)
	end

	if self.state == STATE.DEFEAT then
		self:_drawDefeat(TvScreen)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: CTA overlay
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawCTA(tv)
	love.graphics.push("all")

	love.graphics.setColor(0, 0, 0, 0.65)
	love.graphics.rectangle("fill", tv.posX, tv.posY, tv.width, tv.height, 6, 6)

	local stage = self:_getCurrentStage()
	local stageName = stage and stage.name or "Unknown"
	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + tv.height / 2

	-- Stage label
	love.graphics.setFont(getFont(14))
	love.graphics.setColor(C.label)
	local stageLabel = "STAGE " .. self.currentStageIdx .. " / " .. #self.stageOrder
	local slw = getFont(14):getWidth(stageLabel)
	love.graphics.print(stageLabel, cx - slw / 2, cy - 60)

	-- Stage name
	love.graphics.setFont(getFont(20))
	love.graphics.setColor(C.title)
	local nw = getFont(20):getWidth(stageName)
	love.graphics.print(stageName, cx - nw / 2, cy - 40)

	-- CTA text with pulse
	local pulse = 0.7 + 0.3 * math.sin(self.ctaPulse)
	love.graphics.setFont(getFont(18))
	local ctaText = "[ PRESS SPACE TO ENTER ]"
	local tw = getFont(18):getWidth(ctaText)
	love.graphics.setColor(C.ctaGlow[1], C.ctaGlow[2], C.ctaGlow[3], pulse)
	love.graphics.print(ctaText, cx - tw / 2, cy + 10)

	-- Title
	love.graphics.setFont(getFont(32))
	love.graphics.setColor(C.border[1], C.border[2], C.border[3], 0.8)
	local icon = "COMBAT"
	local iw = getFont(32):getWidth(icon)
	love.graphics.print(icon, cx - iw / 2, cy - 100)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Parry CTA overlay (enemy turn warning + press space to defend)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawParryCTA(tv)
	love.graphics.push("all")

	-- Semi-dark overlay
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.rectangle("fill", tv.posX, tv.posY, tv.width, tv.height, 6, 6)

	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + tv.height / 2

	-- Warning icon
	love.graphics.setFont(getFont(28))
	love.graphics.setColor(C.enemyTurn)
	local warnText = "ENEMY TURN!"
	local ww = getFont(28):getWidth(warnText)
	love.graphics.print(warnText, cx - ww / 2, cy - 55)

	-- Info text
	love.graphics.setFont(getFont(13))
	love.graphics.setColor(C.value)
	local infoText = "The enemy is preparing to strike."
	local itw = getFont(13):getWidth(infoText)
	love.graphics.print(infoText, cx - itw / 2, cy - 15)

	local infoText2 = "Perform parry skill checks to reduce incoming damage!"
	local itw2 = getFont(13):getWidth(infoText2)
	love.graphics.print(infoText2, cx - itw2 / 2, cy + 5)

	-- Pulsing CTA
	local pulse = 0.6 + 0.4 * math.sin(self.parryCTAPulse)
	love.graphics.setFont(getFont(18))
	love.graphics.setColor(C.parryText[1], C.parryText[2], C.parryText[3], pulse)
	local defText = "[ PRESS SPACE TO DEFEND ]"
	local dw = getFont(18):getWidth(defText)
	love.graphics.print(defText, cx - dw / 2, cy + 40)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Turn Indicator
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawTurnIndicator(tv)
	local ti = self.turnIndicator
	if ti.alpha <= 0 or ti.text == "" then return end

	love.graphics.push("all")
	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + 40

	local font = getFont(26)
	love.graphics.setFont(font)

	local tw = font:getWidth(ti.text)
	local scale = math.max(1, ti.scale)

	love.graphics.translate(cx, cy)
	love.graphics.scale(scale, scale)

	-- Shadow
	love.graphics.setColor(0, 0, 0, ti.alpha * 0.6)
	love.graphics.print(ti.text, -tw / 2 + 2, 2)

	-- Main text
	love.graphics.setColor(ti.color[1], ti.color[2], ti.color[3], ti.alpha)
	love.graphics.print(ti.text, -tw / 2, 0)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Stage Tracker HUD (top-right, dungeon themed)
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawStageTracker(tv)
	love.graphics.push("all")

	local panelW = 170
	local panelH = 66
	local margin = 14
	local px = tv.posX + tv.width - panelW - margin
	local py = tv.posY + margin
	local cornerR = 7
	local padding = 10

	-- Drop shadow
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.rectangle("fill", px + 3, py + 3, panelW, panelH, cornerR, cornerR)

	-- Background
	love.graphics.setColor(C.panelBg)
	love.graphics.rectangle("fill", px, py, panelW, panelH, cornerR, cornerR)

	-- Inner border
	love.graphics.setColor(C.borderDim)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", px + 2, py + 2, panelW - 4, panelH - 4, cornerR - 1, cornerR - 1)

	-- Outer border
	love.graphics.setColor(C.border)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", px, py, panelW, panelH, cornerR, cornerR)
	love.graphics.setLineWidth(1)

	-- Stage label
	love.graphics.setFont(getFont(10))
	love.graphics.setColor(C.label)
	local stage = self:_getCurrentStage()
	local stageName = stage and stage.name or "???"
	love.graphics.print("STAGE " .. self.currentStageIdx .. " / " .. #self.stageOrder, px + padding, py + padding)

	love.graphics.setFont(getFont(11))
	love.graphics.setColor(C.title)
	love.graphics.print(stageName, px + padding, py + padding + 14)

	-- Encounter pips
	local pipY = py + padding + 32
	local pipR = 6
	local pipGap = 18
	local numEnc = stage and #stage.encounters or 4
	local pipStartX = px + padding

	for i = 1, numEnc do
		local pipCx = pipStartX + (i - 1) * pipGap + pipR
		if i < self.currentEncounterIdx then
			love.graphics.setColor(C.pipDone)
			love.graphics.circle("fill", pipCx, pipY, pipR)
		elseif i == self.currentEncounterIdx then
			love.graphics.setColor(C.pipCurrent)
			love.graphics.circle("fill", pipCx, pipY, pipR)
			love.graphics.setColor(1, 1, 1, 0.5)
			love.graphics.setLineWidth(1.5)
			love.graphics.circle("line", pipCx, pipY, pipR + 2)
			love.graphics.setLineWidth(1)
		else
			love.graphics.setColor(C.pipEmpty)
			love.graphics.circle("fill", pipCx, pipY, pipR)
		end
		love.graphics.setColor(C.borderDim)
		love.graphics.circle("line", pipCx, pipY, pipR)
	end

	-- Boss star on last pip
	if numEnc > 0 then
		local lastPipCx = pipStartX + (numEnc - 1) * pipGap + pipR
		love.graphics.setColor(C.title)
		love.graphics.setFont(getFont(8))
		love.graphics.print("B", lastPipCx - 3, pipY - 5)
	end

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Boss Health Bar
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawBossHealthBar(tv)
	if not self.boss then return end

	love.graphics.push("all")

	local bx = self.boss.x or (tv.border.right - 120)
	local by = self.boss.y or (tv.border.bottom - 120)
	local barW = self.boss.width or 100
	local barH = 8
	local barY = by - 18

	-- Background
	love.graphics.setColor(C.hpBg)
	love.graphics.rectangle("fill", bx, barY, barW, barH, 3, 3)

	-- Fill
	local frac = self.boss.health / math.max(1, self.boss.maxHealth)
	local fillW = math.max(0, barW * frac)
	if fillW > 0 then
		local r, g, b
		if frac > 0.5 then
			r = 0.2 + (1 - frac) * 1.6
			g = 0.8
			b = 0.2
		else
			r = 0.9
			g = frac * 1.6
			b = 0.1
		end
		love.graphics.setColor(r, g, b, 1)
		love.graphics.rectangle("fill", bx, barY, fillW, barH, 3, 3)
	end

	-- Border
	love.graphics.setColor(C.border[1], C.border[2], C.border[3], 0.6)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", bx, barY, barW, barH, 3, 3)

	-- HP text
	love.graphics.setFont(getFont(8))
	love.graphics.setColor(C.hpText)
	local hpStr = self.boss.health .. " / " .. self.boss.maxHealth
	local hpW = getFont(8):getWidth(hpStr)
	love.graphics.print(hpStr, bx + barW / 2 - hpW / 2, barY - 12)

	-- Boss name
	local enc = self:_getCurrentEncounter()
	if enc then
		love.graphics.setFont(getFont(9))
		love.graphics.setColor(C.title)
		local nameW = getFont(9):getWidth(enc.name)
		love.graphics.print(enc.name, bx + barW / 2 - nameW / 2, barY - 24)

		if enc.isBoss and enc.effect then
			love.graphics.setColor(0.85, 0.3, 1.0, 0.8)
			love.graphics.setFont(getFont(8))
			local effectStr = "[" .. string.upper(enc.effect) .. "]"
			local ew = getFont(8):getWidth(effectStr)
			love.graphics.print(effectStr, bx + barW / 2 - ew / 2, barY - 34)
		end
	end

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Stage Clear
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawStageClear(tv)
	love.graphics.push("all")

	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", tv.posX, tv.posY, tv.width, tv.height, 6, 6)

	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + tv.height / 2

	love.graphics.setFont(getFont(28))
	love.graphics.setColor(C.victory)
	local txt = "STAGE CLEAR!"
	local tw = getFont(28):getWidth(txt)
	love.graphics.print(txt, cx - tw / 2, cy - 20)

	love.graphics.setFont(getFont(14))
	love.graphics.setColor(C.label)
	local sub = "Heading to the shop..."
	local sw = getFont(14):getWidth(sub)
	love.graphics.print(sub, cx - sw / 2, cy + 20)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Game Complete
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawGameComplete(tv)
	love.graphics.push("all")

	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", tv.posX, tv.posY, tv.width, tv.height, 6, 6)

	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + tv.height / 2

	love.graphics.setFont(getFont(32))
	love.graphics.setColor(C.victory)
	local txt = "DUNGEON CONQUERED!"
	local tw = getFont(32):getWidth(txt)
	love.graphics.print(txt, cx - tw / 2, cy - 30)

	love.graphics.setFont(getFont(14))
	love.graphics.setColor(C.title)
	local sub = "All 10 stages cleared. You are the champion!"
	local sw = getFont(14):getWidth(sub)
	love.graphics.print(sub, cx - sw / 2, cy + 15)

	love.graphics.setColor(C.label)
	local restartTxt = "[ PRESS SPACE TO RESTART ]"
	local rw = getFont(14):getWidth(restartTxt)
	love.graphics.print(restartTxt, cx - rw / 2, cy + 45)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Draw: Defeat
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_drawDefeat(tv)
	love.graphics.push("all")

	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", tv.posX, tv.posY, tv.width, tv.height, 6, 6)

	local cx = tv.posX + tv.width / 2
	local cy = tv.posY + tv.height / 2

	love.graphics.setFont(getFont(32))
	love.graphics.setColor(C.defeat)
	local txt = "YOU DIED"
	local tw = getFont(32):getWidth(txt)
	love.graphics.print(txt, cx - tw / 2, cy - 30)

	love.graphics.setFont(getFont(14))
	love.graphics.setColor(C.label)
	local sub = "The dungeon claims another soul..."
	local sw = getFont(14):getWidth(sub)
	love.graphics.print(sub, cx - sw / 2, cy + 15)

	love.graphics.setColor(C.title)
	local restartTxt = "[ PRESS SPACE TO TRY AGAIN ]"
	local rw = getFont(14):getWidth(restartTxt)
	love.graphics.print(restartTxt, cx - rw / 2, cy + 45)

	love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Public API
-- ─────────────────────────────────────────────────────────────────────────────
function combat:isActive()
	return self.state ~= STATE.IDLE
end

function combat:getState()
	return self.state
end

function combat:getSkillCheck()
	return self.SK
end

return combat
