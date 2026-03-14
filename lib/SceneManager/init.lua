--- scene_manager.lua
-- A lightweight, flexible scene manager for Love2D
-- Usage:
--   local SceneManager = require("scene_manager")
--   SceneManager:add("menu", require("scenes.menu"))
--   SceneManager:switch("menu")

local SceneManager = {}
SceneManager.__index = SceneManager

-- Internal state
local _scenes    = {}       -- registered scenes by name
local _stack     = {}       -- scene stack (for push/pop)
local _current   = nil      -- active scene name
local _transition = nil     -- active transition state

-------------------------------------------------------------------------------
-- Transition helpers
-------------------------------------------------------------------------------

local function _newTransition(kind, duration, onMidpoint, onDone)
    return {
        kind      = kind or "fade",   -- "fade" | "none"
        duration  = duration or 0.3,
        timer     = 0,
        phase     = "out",            -- "out" -> "in"
        alpha     = 0,
        onMidpoint = onMidpoint,
        onDone    = onDone,
    }
end

-------------------------------------------------------------------------------
-- Scene lifecycle helpers
-------------------------------------------------------------------------------

local function _callIfExists(scene, method, ...)
    if scene and type(scene[method]) == "function" then
        return scene[method](scene, ...)
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Register a scene under a name.
-- @param name  string  Identifier used to switch to this scene.
-- @param scene table   Scene object implementing any of:
--                        :load()           called once on first switch
--                        :enter(prev, ...) called each time scene becomes active
--                        :exit(next)       called when leaving
--                        :update(dt)
--                        :draw()
--                        :keypressed(key, scancode, isrepeat)
--                        :keyreleased(key, scancode)
--                        :mousepressed(x, y, btn, istouch, presses)
--                        :mousereleased(x, y, btn, istouch, presses)
--                        :mousemoved(x, y, dx, dy, istouch)
--                        :wheelmoved(x, y)
--                        :resize(w, h)
--                        :focus(focused)
--                        :quit()            return true to block quitting
function SceneManager:add(name, scene)
    assert(type(name) == "string", "Scene name must be a string")
    assert(type(scene) == "table", "Scene must be a table")
    scene._name   = name
    scene._loaded = false
    _scenes[name] = scene
end

--- Remove a registered scene. Cannot remove the currently active scene.
function SceneManager:remove(name)
    assert(name ~= _current, "Cannot remove the currently active scene")
    _scenes[name] = nil
end

--- Switch to a scene, optionally with a transition.
-- @param name       string   Target scene name.
-- @param transition table    Optional: { kind="fade", duration=0.3 }
-- @param ...                 Extra args forwarded to scene:enter()
function SceneManager:switch(name, transition, ...)
    assert(_scenes[name], ("Scene '%s' is not registered"):format(name))
    local args = { ... }

    local function doSwitch()
        local prev = _current
        if prev and _scenes[prev] then
            _callIfExists(_scenes[prev], "exit", name)
        end

        _current = name
        -- Reset stack — switch replaces history
        _stack = { name }

        local scene = _scenes[name]
        if not scene._loaded then
            _callIfExists(scene, "load")
            scene._loaded = true
        end
        _callIfExists(scene, "enter", prev, table.unpack(args))
    end

    if transition and transition.kind ~= "none" then
        _transition = _newTransition(
            transition.kind,
            transition.duration,
            doSwitch,
            function() _transition = nil end
        )
    else
        doSwitch()
    end
end

--- Push a scene onto the stack (previous scene is paused, not exited).
-- The previous scene stops receiving update/draw while buried.
-- @param name  string  Target scene name.
-- @param ...           Extra args forwarded to scene:enter()
function SceneManager:push(name, ...)
    assert(_scenes[name], ("Scene '%s' is not registered"):format(name))
    local prev = _current
    table.insert(_stack, name)
    _current = name

    local scene = _scenes[name]
    if not scene._loaded then
        _callIfExists(scene, "load")
        scene._loaded = true
    end
    _callIfExists(scene, "enter", prev, ...)
end

--- Pop the current scene off the stack, returning to the previous one.
-- @param ...  Extra args forwarded to previous scene's :enter()
function SceneManager:pop(...)
    assert(#_stack > 1, "Cannot pop: scene stack would be empty")
    local leaving = table.remove(_stack)
    _callIfExists(_scenes[leaving], "exit", _stack[#_stack])
    _current = _stack[#_stack]
    _callIfExists(_scenes[_current], "enter", leaving, ...)
end

--- Return the currently active scene name.
function SceneManager:current()
    return _current
end

--- Return the scene object by name (or current if name omitted).
function SceneManager:get(name)
    return _scenes[name or _current]
end

--- Return true if a scene with this name is registered.
function SceneManager:has(name)
    return _scenes[name] ~= nil
end

--- Mark a scene as unloaded so :load() will be called again on next switch.
function SceneManager:reload(name)
    name = name or _current
    if _scenes[name] then _scenes[name]._loaded = false end
end

-------------------------------------------------------------------------------
-- Love2D callback forwarding
-- Call these from your main.lua love.* callbacks.
-------------------------------------------------------------------------------

function SceneManager:update(dt)
    -- Handle transition
    if _transition then
        local t = _transition
        t.timer = t.timer + dt
        local half = t.duration / 2

        if t.phase == "out" then
            t.alpha = math.min(t.timer / half, 1)
            if t.timer >= half then
                t.phase = "in"
                t.timer = 0
                t.onMidpoint()
            end
        else
            t.alpha = 1 - math.min(t.timer / half, 1)
            if t.timer >= half then
                t.onDone()
            end
        end
        -- Scene still updates during transition
    end

    local scene = _scenes[_current]
    _callIfExists(scene, "update", dt)
end

function SceneManager:draw()
    local scene = _scenes[_current]
    _callIfExists(scene, "draw")

    -- Draw transition overlay
    if _transition and _transition.kind == "fade" then
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(0, 0, 0, _transition.alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(r, g, b, a)
    end
end

function SceneManager:keypressed(key, scancode, isrepeat)
    _callIfExists(_scenes[_current], "keypressed", key, scancode, isrepeat)
end

function SceneManager:keyreleased(key, scancode)
    _callIfExists(_scenes[_current], "keyreleased", key, scancode)
end

function SceneManager:mousepressed(x, y, btn, istouch, presses)
    _callIfExists(_scenes[_current], "mousepressed", x, y, btn, istouch, presses)
end

function SceneManager:mousereleased(x, y, btn, istouch, presses)
    _callIfExists(_scenes[_current], "mousereleased", x, y, btn, istouch, presses)
end

function SceneManager:mousemoved(x, y, dx, dy, istouch)
    _callIfExists(_scenes[_current], "mousemoved", x, y, dx, dy, istouch)
end

function SceneManager:wheelmoved(x, y)
    _callIfExists(_scenes[_current], "wheelmoved", x, y)
end

function SceneManager:resize(w, h)
    _callIfExists(_scenes[_current], "resize", w, h)
end

function SceneManager:focus(focused)
    _callIfExists(_scenes[_current], "focus", focused)
end

function SceneManager:quit()
    return _callIfExists(_scenes[_current], "quit")
end

return SceneManager
