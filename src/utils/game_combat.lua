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
local GREAT_QUALITY     = 1.0  -- 100% base damage on great
local SUCCESS_QUALITY   = 0.6  -- 60% base damage on success
local ENEMY_TURN_DELAY  = 1.2  -- seconds before enemy attacks
local RESOLUTION_DELAY  = 1.5  -- seconds before next round/encounter
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
    -- Load stages
    local raw = love.filesystem.read("src/entities/stages.json")
    local data = json.decode(raw)
    self.allStages = data and data.stages or {}

    -- Generate random stage order
    self.stageOrder = {}
    for i = 1, #self.allStages do
        self.stageOrder[i] = i
    end
    -- Fisher-Yates shuffle
    for i = #self.stageOrder, 2, -1 do
        local j = love.math.random(1, i)
        self.stageOrder[i], self.stageOrder[j] = self.stageOrder[j], self.stageOrder[i]
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
--  Load encounter into boss
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_loadEncounter()
    local enc = self:_getCurrentEncounter()
    if enc and self.boss then
        self.boss:setFromEncounter(enc)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Calculate card bonuses
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_getCardBonuses()
    local bonuses = { attackDmg = 0, parryArmor = 0, healPerTurn = 0, magicGreatBonus = 0 }
    if not self.player then return bonuses end
    for _, card in ipairs(self.player:getInventoryCards()) do
        if card.type == "attack" and card.stats and card.stats.damage then
            bonuses.attackDmg = bonuses.attackDmg + card.stats.damage
        elseif card.type == "defense" and card.stats and card.stats.armor then
            bonuses.parryArmor = bonuses.parryArmor + card.stats.armor
        elseif card.type == "heal" and card.stats and card.stats.heal then
            bonuses.healPerTurn = bonuses.healPerTurn + card.stats.heal
        elseif card.type == "magic" and card.stats and card.stats.damage then
            bonuses.magicGreatBonus = bonuses.magicGreatBonus + card.stats.damage
        end
    end
    return bonuses
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Spawn a skill check for the current phase
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_spawnSkillCheck()
    local isParry = (self.state == STATE.PLAYER_PARRY)
    local cfg     = getSkillCheckConfig(self.currentStageIdx, isParry)

    local selfRef = self
    self.SK       = SkillCheck:new({
        successArcSize = cfg.successArcSize,
        greatArcSize   = cfg.greatArcSize,
        pointerSpeed   = cfg.pointerSpeed,
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
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Skill check result callback
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_onSkillCheckResult(quality, rounds)
    local isParry = (self.state == STATE.PLAYER_PARRY)
    local results = isParry and self.parryResults or self.attackResults

    table.insert(results, { quality = quality, multiplier = rounds })

    -- Visual feedback
    local bs = self.boss:details()
    if not isParry then
        if quality == "great" then
            self.shake:add_trauma(1)
            self.multAnim.spawnChain(bs.x, bs.y, { rounds, rounds, rounds }, function()
                local dmgVal = self:_calcSingleAttack(quality, rounds)
                self.dmg:spawn(bs.x, bs.y, math.floor(dmgVal), "crit")
            end)
        elseif quality == "success" then
            self.shake:add_trauma(0.4)
            self.multAnim.spawnChain(bs.x, bs.y, { rounds }, function()
                local dmgVal = self:_calcSingleAttack(quality, rounds)
                self.dmg:spawn(bs.x, bs.y, math.floor(dmgVal), "normal")
            end)
        else
            self.shake:add_trauma(0.2)
            self.dmg:spawn(bs.x, bs.y, 0, "miss")
        end
    else
        local px = self.player.drawX or 0
        local py = self.player.drawY or 0
        if quality ~= "miss" then
            local parryVal = self:_calcSingleParry(quality, rounds)
            self.dmg:spawn(px, py, math.floor(parryVal), "shield")
        else
            self.dmg:spawn(px, py, 0, "miss")
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Calculate damage for a single attack check
-- ─────────────────────────────────────────────────────────────────────────────
function combat:_calcSingleAttack(quality, multiplier)
    if quality == "miss" then return 0 end
    local bonuses = self:_getCardBonuses()
    local baseDmg = (self.player and self.player.damage or 1) + bonuses.attackDmg
    local qMult   = (quality == "great") and GREAT_QUALITY or SUCCESS_QUALITY
    local dmgVal  = baseDmg * qMult * math.max(1, multiplier)
    if quality == "great" then
        dmgVal = dmgVal + bonuses.magicGreatBonus * math.max(1, multiplier)
    end
    return dmgVal
end

function combat:_calcSingleParry(quality, multiplier)
    if quality == "miss" then return 0 end
    local bonuses = self:_getCardBonuses()
    local baseDef = (self.player and self.player.defence or 0) + bonuses.parryArmor
    local qMult   = (quality == "great") and GREAT_QUALITY or SUCCESS_QUALITY
    return (baseDef + 2) * qMult * math.max(1, multiplier)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  After skill check despawns → advance to next check or next phase
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
            self.totalDamage = math.floor(self.totalDamage)
            -- Apply damage to boss
            if self.boss then
                self.boss.health = math.max(0, self.boss.health - self.totalDamage)
            end
            -- Check if boss is dead
            if self.boss and self.boss.health <= 0 then
                self.state = STATE.RESOLUTION
                self.resolutionTimer = 0
                return
            end
            -- Move to PARRY_CTA — notify player it's enemy turn, wait for space
            self.state = STATE.PARRY_CTA
            self.parryCTAPulse = 0
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

    if self.currentEncounterIdx < #stage.encounters then
        self.currentEncounterIdx = self.currentEncounterIdx + 1
        self:_startCombat()
    else
        -- Stage clear!
        if self.currentStageIdx < #self.stageOrder then
            self.state = STATE.STAGE_CLEAR
            self.stageClearTimer = 0
        else
            self.state = STATE.GAME_COMPLETE
        end
    end
end

function combat:_advanceStage()
    self.currentStageIdx = self.currentStageIdx + 1
    self.currentEncounterIdx = 1
    self.state = STATE.CTA
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

    local enemyAtk = enc.attack
    local reduction = self.totalParry
    local finalDmg = math.max(1, enemyAtk - reduction)
    self.enemyDamageDealt = finalDmg

    self.player.health = math.max(0, self.player.health - finalDmg)

    local px = self.player.drawX or 0
    local py = self.player.drawY or 0
    self.shake:add_trauma(0.6)
    self.dmg:spawn(px, py, finalDmg, "normal")

    if self.player.health <= 0 then
        self.state = STATE.DEFEAT
    else
        self.state = STATE.RESOLUTION
        self.resolutionTimer = 0
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
