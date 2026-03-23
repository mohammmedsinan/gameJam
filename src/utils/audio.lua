local Audio = {}

Audio.sfxList = {
    click = "assets/audio/sfx/ButtonClick.wav",
    hover = "assets/audio/sfx/ButtonHover.wav",
    equip_buy = "assets/audio/sfx/EquipmentPurchased.wav",
    hit_great = "assets/audio/sfx/GREATHit.wav",
    hit_success = "assets/audio/sfx/SUCCESSHit.wav",
    hit_miss = "assets/audio/sfx/MISSHit.wav",
    level_up = "assets/audio/sfx/LevelUp.wav",
    pointer = "assets/audio/sfx/PointerTick.wav",
    shop_door = "assets/audio/sfx/ShopOpenAndClose.wav",
    skill_start = "assets/audio/sfx/SkillCheckStart.wav",
    card = "assets/audio/sfx/cardSound.wav",
    gain_gold = "assets/audio/sfx/gainGold.wav",
    hit_player = "assets/audio/sfx/SUCCESSHit1.wav",
    hit_enemy = "assets/audio/sfx/GREATHit1.wav",
}
Audio.musicList = {
    game = "assets/audio/sfx/gameOst.ogg",
    boss = "assets/audio/sfx/finalBossesOst.mp3"
}

Audio.sfxSources = {}
Audio.musicSources = {}
Audio.currentMusic = nil
Audio.currentMusicName = nil

function Audio.load()
    -- Load SFX
    for name, path in pairs(Audio.sfxList) do
        local info = love.filesystem.getInfo(path)
        if info then
            Audio.sfxSources[name] = love.audio.newSource(path, "static")
        end
    end

    -- Load Music
    for name, path in pairs(Audio.musicList) do
        local info = love.filesystem.getInfo(path)
        if info then
            Audio.musicSources[name] = love.audio.newSource(path, "stream")
            Audio.musicSources[name]:setLooping(true)
        end
    end
end

function Audio.playSFX(name, volume, pitch)
    local src = Audio.sfxSources[name]
    if src then
        local clone = src:clone()
        clone:setVolume(volume or 1.0)
        clone:setPitch(pitch or 1.0)
        clone:play()
    end
end

function Audio.playMusic(name, volume)
    if Audio.currentMusicName == name then return end

    if Audio.currentMusic then
        Audio.currentMusic:stop()
    end

    local src = Audio.musicSources[name]
    if src then
        src:setVolume(volume or 0.5)
        src:play()
        Audio.currentMusic = src
        Audio.currentMusicName = name
    else
        Audio.currentMusic = nil
        Audio.currentMusicName = nil
    end
end

function Audio.stopMusic()
    if Audio.currentMusic then
        Audio.currentMusic:stop()
        Audio.currentMusic = nil
        Audio.currentMusicName = nil
    end
end

return Audio
