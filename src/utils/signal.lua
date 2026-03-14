--- signal.lua
--- A minimal, scalable signal/event system for Love2D
--- Usage: local Signal = require("signal")

local Signal = {}
Signal.__index = Signal

-- Create a new signal bus
function Signal.new()
	local self      = setmetatable({}, Signal)
	self._listeners = {} -- { [event] = { {fn, once} } }
	self._queue     = {} -- deferred emit queue
	self._emitting  = false
	return self
end

--- Subscribe to an event.
-- @param event  string   event name
-- @param fn     function callback(...)
-- @return       handle   (pass to :off to unsubscribe)
function Signal:on(event, fn)
	assert(type(event) == "string", "event must be a string")
	assert(type(fn) == "function", "listener must be a function")
	local list = self._listeners[event]
	if not list then
		list = {}
		self._listeners[event] = list
	end
	local handle = { event = event, fn = fn, once = false, active = true }
	list[#list + 1] = handle
	return handle
end

--- Subscribe for a single firing, then auto-unsubscribe.
function Signal:once(event, fn)
	local handle = self:on(event, fn)
	handle.once = true
	return handle
end

--- Unsubscribe using the handle returned by :on / :once.
function Signal:off(handle)
	if handle and handle.active then
		handle.active = false
	end
end

--- Unsubscribe ALL listeners for a given event (or everything if no event given).
function Signal:clear(event)
	if event then
		local list = self._listeners[event]
		if list then
			for _, h in ipairs(list) do h.active = false end
			self._listeners[event] = nil
		end
	else
		for _, list in pairs(self._listeners) do
			for _, h in ipairs(list) do h.active = false end
		end
		self._listeners = {}
	end
end

--- Emit an event immediately, calling all active listeners.
-- While inside an emit, any nested :emit calls are safe (re-entrant).
function Signal:emit(event, ...)
	local list = self._listeners[event]
	if not list then return end

	-- Snapshot the list so mutations during iteration are safe
	local snapshot = {}
	for i = 1, #list do snapshot[i] = list[i] end

	local dead = false
	for _, handle in ipairs(snapshot) do
		if handle.active then
			if handle.once then handle.active = false end
			handle.fn(...)
			dead = dead or (not handle.active)
		end
	end

	-- Compact dead handles lazily
	if dead then
		local kept = {}
		for _, h in ipairs(list) do
			if h.active then kept[#kept + 1] = h end
		end
		if #kept == 0 then
			self._listeners[event] = nil
		else
			self._listeners[event] = kept
		end
	end
end

--- Queue an emit to fire on the next :flush() call.
-- Useful for end-of-frame batching or cross-system decoupling.
function Signal:queue(event, ...)
	local args = { ... }
	self._queue[#self._queue + 1] = { event = event, args = args }
end

--- Fire all queued events in order.
function Signal:flush()
	-- Swap so that events queued *during* flush fire next frame, not this one
	local q = self._queue
	self._queue = {}
	for _, entry in ipairs(q) do
		self:emit(entry.event, table.unpack(entry.args))
	end
end

--- Convenience: return a bound emitter function for a named event.
-- local fireShoot = bus:emitter("shoot")
-- fireShoot(x, y, dir)   -- equivalent to bus:emit("shoot", x, y, dir)
function Signal:emitter(event)
	return function(...) self:emit(event, ...) end
end

--- Debug helper: list active listeners per event.
function Signal:debug()
	local out = {}
	for event, list in pairs(self._listeners) do
		local count = 0
		for _, h in ipairs(list) do
			if h.active then count = count + 1 end
		end
		out[#out + 1] = string.format("  %-24s %d listener(s)", event, count)
	end
	table.sort(out)
	return "Signal bus:\n" .. (#out > 0 and table.concat(out, "\n") or "  (empty)")
end

return Signal
