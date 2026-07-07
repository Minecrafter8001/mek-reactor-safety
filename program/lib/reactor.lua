-- Reactor peripheral abstraction.
-- Wraps fissionReactorLogicAdapter and exposes normalised state and controls.

local reactor = {}
local _handle = nil
local _last_read_values = {}

local function resolveHandle()
    if _handle then
        return _handle
    end
    _handle = peripheral.find("fissionReactorLogicAdapter")
    return _handle
end

local function safeRead(method, defaultValue, ...)
    local handle = resolveHandle()
    if not handle then
        local cached = _last_read_values[method]
        if cached ~= nil then
            return cached, false
        end
        return defaultValue, false
    end

    local fn = handle[method]
    if type(fn) ~= "function" then
        local cached = _last_read_values[method]
        if cached ~= nil then
            return cached, false
        end
        return defaultValue, false
    end

    local ok, value = pcall(fn, handle, ...)
    if not ok then
        local cached = _last_read_values[method]
        if cached ~= nil then
            return cached, false
        end
        return defaultValue, false
    end

    if value == nil then
        local cached = _last_read_values[method]
        if cached ~= nil then
            return cached, false
        end
        return defaultValue, false
    end

    _last_read_values[method] = value
    return value, true
end

local function safeCommand(method, ...)
    local handle = resolveHandle()
    if not handle then
        return false
    end

    local fn = handle[method]
    if type(fn) ~= "function" then
        return false
    end

    local ok = pcall(fn, handle, ...)
    return ok
end

--- Locate and bind the reactor peripheral.
--- @param name string|nil  optional specific peripheral name; auto-finds if omitted
function reactor.init(name)
    _handle = name and peripheral.wrap(name)
           or peripheral.find("fissionReactorLogicAdapter")
end

--- Returns a snapshot of all safety-relevant reactor metrics.
--- All tank levels are normalised to 0–1 fractions.
function reactor.getState()
    local formed = safeRead("isFormed", false)

    -- Use safe defaults while chunks/peripherals are loading.
    local temp = safeRead("getTemperature", 0)
    local max_burn_rate = safeRead("getMaxBurnRate", 0)
    local burn_rate = safeRead("getBurnRate", 0)
    local actual_burn_rate = safeRead("getActualBurnRate", 0)
    local fuel_pct = safeRead("getFuelFilledPercentage", 0)
    local coolant_pct = safeRead("getCoolantFilledPercentage", 0)
    local heated_coolant_pct = safeRead("getHeatedCoolantFilledPercentage", 0)
    local waste_pct = safeRead("getWasteFilledPercentage", 0)
    local damage = safeRead("getDamagePercent", 0)
    local active = safeRead("getStatus", false)
    local force_disabled = safeRead("isForceDisabled", false)

    return {
        temp               = temp,
        burn_rate          = burn_rate,
        burn_rate_max      = max_burn_rate,
        burn_rate_pct      = (max_burn_rate and max_burn_rate > 0) and (burn_rate / max_burn_rate) or nil,
        actual_burn_rate   = actual_burn_rate,
        fuel_pct           = fuel_pct,
        coolant_pct        = coolant_pct,
        heated_coolant_pct = heated_coolant_pct,
        waste_pct          = waste_pct,
        damage             = damage,
        active             = active,
        formed             = formed,
        force_disabled     = force_disabled,
    }
end

function reactor.scram()
    return safeCommand("scram")
end

function reactor.activate()
    return safeCommand("activate")
end

function reactor.setBurnRate(rate)
    return safeCommand("setBurnRate", rate)
end

return reactor
