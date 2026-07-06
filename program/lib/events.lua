-- Lightweight synchronous event bus.
-- Listeners fire immediately when an event is emitted.

local events = {}
local _listeners = {}

--- Register a callback for an event.
--- @param name     string    event identifier
--- @param callback function  called with a data table when the event fires
function events.on(name, callback)
    if not _listeners[name] then
        _listeners[name] = {}
    end
    table.insert(_listeners[name], callback)
end

--- Fire an event and invoke all registered listeners.
--- @param name string  event identifier
--- @param data table   payload passed to each listener
function events.emit(name, data)
    local list = _listeners[name]
    if list then
        for _, cb in ipairs(list) do
            cb(data or {})
        end
    end
end

return events
