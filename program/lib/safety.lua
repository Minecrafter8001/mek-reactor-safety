local config = require("lib.config")
local events = require("lib.events")
local environment = require("lib.environment")

local safety = {}

local STATES = {
    NORMAL   = "NORMAL",
    WARNING  = "WARNING",
    REDUCED  = "REDUCED",
    LOCKED   = "LOCKED",
    SCRAM    = "SCRAM",
}
safety.STATES = STATES

-- Module-level state (persists across check() calls)
local _scrammed        = false
local _damaged         = false
local _saved_burn_rate = nil
local _prev_level      = nil
local _reset_required  = false
local _startup_checked = false
local _lock_reason     = nil
local _last_level      = STATES.NORMAL
local _last_reason     = nil
local _last_state      = nil
local _last_radiation  = 0
local _last_burn_reduction = nil
local _last_event_kind = nil
local _last_event_time  = nil
local _last_event_note  = nil

local function localTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function recordEvent(kind, note)
    _last_event_kind = kind
    _last_event_time = localTimestamp()
    _last_event_note = note
end

local function eventLabel(kind)
    if kind == STATES.SCRAM then
        return "SCRAM"
    elseif kind == STATES.REDUCED then
        return "Throttle down"
    elseif kind == STATES.LOCKED then
        return "Lock"
    end
    return kind or "Unknown"
end

local function copyState(state)
    local result = {}
    for key, value in pairs(state or {}) do
        result[key] = value
    end
    return result
end

local function formatPercent(value)
    return string.format("%.1f%%", (value or 0) * 100)
end

local function formatTrimmed(value, decimals)
    local formatted = string.format("%." .. tostring(decimals or 2) .. "f", value or 0)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    if formatted == "-0" then
        formatted = "0"
    end
    return formatted
end

local function joinParts(parts)
    if #parts == 0 then
        return ""
    end
    if #parts == 1 then
        return parts[1]
    end
    if #parts == 2 then
        return parts[1] .. " and " .. parts[2]
    end
    return table.concat(parts, ", ", 1, #parts - 1) .. ", and " .. parts[#parts]
end

local function describeWarningReasons(state, radiation)
    local reasons = {}

    if state.temp >= config.temp.warning then
        reasons[#reasons + 1] = string.format("temperature at %s K", formatTrimmed(state.temp, 1))
    end
    if state.coolant_pct <= config.coolant.warning then
        reasons[#reasons + 1] = string.format("coolant at %s", formatPercent(state.coolant_pct))
    end
    if state.waste_pct >= config.waste.warning then
        reasons[#reasons + 1] = string.format("waste at %s", formatPercent(state.waste_pct))
    end
    if radiation >= config.radiation.warning then
        reasons[#reasons + 1] = string.format("radiation at %s", environment.formatRadiation(radiation))
    end

    return reasons
end

local function describeScramReason(reason, state, radiation)
    if reason == "reactor_damaged" then
        return string.format("reactor damage detected at %s%%", formatTrimmed(state.damage or 0, 2))
    elseif reason == "temp_critical" then
        return string.format("temperature critical at %s K", formatTrimmed(state.temp or 0, 1))
    elseif reason == "coolant_critical" then
        return string.format("coolant critical at %s", formatPercent(state.coolant_pct))
    elseif reason == "waste_critical" then
        return string.format("waste critical at %s", formatPercent(state.waste_pct))
    elseif reason == "radiation_critical" then
        return string.format("radiation critical at %s", environment.formatRadiation(radiation or 0))
    end
    return "an unknown critical condition"
end

local function buildSummary(state)
    local parts = {
        string.format("temperature %s K", formatTrimmed(state.temp or 0, 1)),
        string.format("fuel %s", formatPercent(state.fuel_pct)),
        string.format("coolant %s", formatPercent(state.coolant_pct)),
        string.format("waste %s", formatPercent(state.waste_pct)),
        string.format("damage %s%%", formatTrimmed(state.damage or 0, 2)),
    }

    if state.active ~= nil then
        parts[#parts + 1] = state.active and "reactor active" or "reactor offline"
    end
    if state.formed ~= nil then
        parts[#parts + 1] = state.formed and "reactor formed" or "reactor unformed"
    end

    return joinParts(parts)
end

local function describeLockReason(state)
    if _lock_reason == "fuel_empty" or (state.fuel_pct or 0) <= 0 then
        return "fuel is empty"
    end
    if _lock_reason == "reactor_off" or not state.active then
        return "reactor is offline"
    end
    return "manual reset is required"
end

--- Pure evaluation: returns level and optional SCRAM reason.
local function evaluate(state, radiation)
    if state.damage > config.damage.threshold then
        return STATES.SCRAM, "reactor_damaged"
    end
    if state.temp >= config.temp.emergency then
        return STATES.SCRAM, "temp_critical"
    end
    if state.coolant_pct <= config.coolant.critical then
        return STATES.SCRAM, "coolant_critical"
    end
    if state.waste_pct >= config.waste.critical then
        return STATES.SCRAM, "waste_critical"
    end
    if radiation >= config.radiation.critical then
        return STATES.SCRAM, "radiation_critical"
    end
    if state.temp >= config.temp.reduce then
        return STATES.REDUCED, nil
    end
    if state.temp        >= config.temp.warning
    or state.coolant_pct <= config.coolant.warning
    or state.waste_pct   >= config.waste.warning
    or radiation         >= config.radiation.warning then
        return STATES.WARNING, nil
    end
    return STATES.NORMAL, nil
end

--- Attempt automatic recovery if all conditions are safe.
local function tryRecover(reactor, state, radiation)
    if _damaged and config.recovery.require_manual_after_damage then return end
    if state.force_disabled then return end
    if evaluate(state, radiation) ~= STATES.NORMAL then return end
    _reset_required = true
    if not _lock_reason then
        _lock_reason = "manual_reset"
    end
end

--- Evaluate reactor conditions and apply safety actions.
--- @param reactor   table   reactor module
--- @param state     table   snapshot from reactor.getState()
--- @param radiation number  radiation level in Sv/h (default 0)
--- @return string  current STATES value
function safety.check(reactor, state, radiation)
    radiation = radiation or 0

    if not _startup_checked then
        _reset_required = (not state.active) or ((state.fuel_pct or 0) <= 0)
        if _reset_required then
            _lock_reason = ((state.fuel_pct or 0) <= 0) and "fuel_empty" or "reactor_off"
        end
        _startup_checked = true
    end

    if _reset_required and ((not state.active) or ((state.fuel_pct or 0) <= 0)) then
        if _last_event_kind ~= STATES.LOCKED then
            recordEvent(STATES.LOCKED, describeLockReason(state))
        end
        _last_level = STATES.LOCKED
        _last_reason = _lock_reason
        _last_state = copyState(state)
        _last_radiation = radiation
        _last_burn_reduction = nil
        _prev_level = STATES.LOCKED
        return STATES.LOCKED
    end

    local level, reason = evaluate(state, radiation)

    _last_level = level
    _last_reason = reason
    _last_state = copyState(state)
    _last_radiation = radiation

    if level == STATES.SCRAM then
        if not _scrammed then
            _scrammed = true
            if reason == "reactor_damaged" then _damaged = true end
            if state.active then reactor.scram() end
            _reset_required = true
            _lock_reason = reason
            recordEvent(STATES.SCRAM, describeScramReason(reason, state, radiation))
            events.emit("scram", { reason = reason, state = state })
        end

    elseif level == STATES.REDUCED then
        if state.active then
            if _saved_burn_rate == nil then
                _saved_burn_rate = state.burn_rate
            end
            local new_rate = math.max(
                config.burn_rate.min,
                state.burn_rate - config.burn_rate.reduce_step
            )
            if new_rate < state.burn_rate then
                reactor.setBurnRate(new_rate)
                _last_burn_reduction = { from = state.burn_rate, to = new_rate }
                recordEvent(
                    STATES.REDUCED,
                    string.format("%s -> %s mB/t", formatTrimmed(state.burn_rate, 2), formatTrimmed(new_rate, 2))
                )
                events.emit("burn_reduced", { from = state.burn_rate, to = new_rate })
            end
        end
        if _scrammed then tryRecover(reactor, state, radiation) end

    else -- NORMAL or WARNING
        -- Emit warning only on transition into WARNING state
        if level == STATES.WARNING and _prev_level ~= STATES.WARNING then
            events.emit("warning", { state = state, radiation = radiation })
        end
        -- Restore throttled burn rate once conditions are safe
        if _saved_burn_rate ~= nil and state.active then
            reactor.setBurnRate(_saved_burn_rate)
            _saved_burn_rate = nil
        end
        if _scrammed then
            tryRecover(reactor, state, radiation)
        end
    end

    if level ~= STATES.REDUCED then
        _last_burn_reduction = nil
    end

    _prev_level = level
    return level
end

--- Returns true if the safety system has issued a SCRAM.
function safety.isScrammed() return _scrammed end

--- Returns true if the SCRAM was caused by reactor damage.
--- When require_manual_after_damage is set, clearDamage() must be called
--- before automatic restart is permitted.
function safety.isDamaged() return _damaged end

--- Manually clear the damage lock to allow automatic restart.
function safety.clearDamage()
    _damaged = false
end

--- Returns true when the controller requires a manual reset confirmation.
function safety.isResetRequired()
    return _reset_required
end

--- Confirm a manual reset, then restart the reactor if it is safe and fuel is available.
function safety.requestReset(reactor)
    local assessment = safety.getLastAssessment()
    local state = assessment.state

    if not state then
        return false, "status unavailable"
    end
    if _damaged then
        return false, "damage lock active"
    end
    if (state.fuel_pct or 0) <= 0 then
        return false, "fuel empty"
    end
    if evaluate(state, assessment.radiation or 0) ~= STATES.NORMAL and not state.active then
        return false, "conditions not safe"
    end

    _scrammed = false
    _reset_required = false
    _lock_reason = nil

    if not state.active and not state.force_disabled then
        reactor.activate()
    end

    events.emit("recovered", { state = state, manual = true })
    return true
end

--- Returns the last evaluated safety snapshot.
function safety.getLastAssessment()
    return {
        level = _last_level,
        reason = _last_reason,
        state = _last_state,
        radiation = _last_radiation,
        burn_reduction = _last_burn_reduction,
        event_kind = _last_event_kind,
        event_time = _last_event_time,
        event_note = _last_event_note,
    }
end

--- Builds a spoken summary of the current reactor status.
function safety.buildAnnouncement()
    local assessment = safety.getLastAssessment()
    local state = assessment.state

    if not state then
        return "Reactor status is unavailable."
    end

    local level = assessment.level or STATES.NORMAL
    local message = string.format("Reactor status %s. %s.", level, buildSummary(state))

    if level == STATES.LOCKED then
        message = string.format(
            "Reactor is locked. %s. Press R to confirm reset.",
            describeLockReason(state)
        )
    elseif level == STATES.SCRAM then
        message = string.format(
            "Reactor scrammed because of %s. %s. Press R to confirm reset.",
            describeScramReason(assessment.reason, state, assessment.radiation),
            buildSummary(state)
        )
    elseif level == STATES.WARNING then
        local reasons = describeWarningReasons(state, assessment.radiation or 0)
        if #reasons > 0 then
            message = string.format(
                "Reactor warning because of %s. %s.",
                joinParts(reasons),
                buildSummary(state)
            )
        end
    elseif level == STATES.REDUCED then
        if assessment.burn_reduction then
            message = string.format(
                "Reactor throttling down. Burn rate reduced from %s to %s mB per tick. %s.",
                formatTrimmed(assessment.burn_reduction.from, 2),
                formatTrimmed(assessment.burn_reduction.to, 2),
                buildSummary(state)
            )
        else
            message = string.format("Reactor throttling down. %s.", buildSummary(state))
        end
    end

    if assessment.radiation and assessment.radiation > 0 then
        message = message .. string.format(" Radiation is %s.", environment.formatRadiation(assessment.radiation))
    end

    if _last_event_time then
        message = message .. string.format(" Last event: %s at %s", eventLabel(_last_event_kind), _last_event_time)
        if _last_event_note and _last_event_note ~= "" then
            message = message .. string.format(" (%s)", _last_event_note)
        end
        message = message .. "."
    end

    if _damaged then
        message = message .. " Damage lock is active."
    end

    return message
end

return safety
