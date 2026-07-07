local display = {}
local config = require("lib.config")
local environment = require("lib.environment")
local safety = require("lib.safety")
local utils = require("lib.utils")

local STATE_COLORS = {
    NORMAL  = colors and colors.green  or nil,
    WARNING = colors and colors.yellow or nil,
    REDUCED = colors and colors.orange or nil,
    SCRAM   = colors and colors.red    or nil,
}

local STATE_LABELS = {
    NORMAL  = "NORMAL",
    WARNING = "WARNING",
    REDUCED = "THROTTLED",
    SCRAM   = "** SCRAM **",
}

local function setColor(c)
    if c and term.isColor and term.isColor() then
        term.setTextColor(c)
    end
end

local function resetColor()
    if term.isColor and term.isColor() then
        term.setTextColor(colors.white)
    end
end

--- Render the full reactor status screen.
--- @param state     table   snapshot from reactor.getState()
--- @param level     string  STATES value from safety module
--- @param radiation number  current radiation (Sv/h), or nil
--- @param scrammed  boolean whether a SCRAM is active
--- @param resetRequired boolean whether a manual reset confirmation is required
--- @param damaged   boolean whether a damage lock is active
function display.render(state, level, radiation, scrammed, resetRequired, damaged)
    term.clear()
    term.setCursorPos(1, 1)

    local statusLabel = STATE_LABELS[level] or level
    local statusColor = STATE_COLORS[level]

    if state and state.active == false and level ~= safety.STATES.SCRAM and level ~= safety.STATES.LOCKED then
        statusLabel = "OFFLINE"
        statusColor = STATE_COLORS.WARNING
    end

    setColor(statusColor)
    print("=== Reactor Safety Controller ===")
    print(string.format("Status      : %s", statusLabel))
    resetColor()
    print("")

    print(string.format("Temperature : %s K",     utils.formatTrimmed(state.temp, 1)))
    if state.burn_rate_pct and state.burn_rate_max then
        print(string.format(
            "Burn Rate   : %s%% of max (%s mB/t of %s mB/t)",
            utils.formatTrimmed(state.burn_rate_pct * 100, 1),
            utils.formatTrimmed(state.burn_rate, 2),
            utils.formatTrimmed(state.burn_rate_max, 2)
        ))
    else
        print(string.format("Burn Rate   : %s mB/t (actual: %s)",
            utils.formatTrimmed(state.burn_rate, 2), utils.formatTrimmed(state.actual_burn_rate, 2)))
    end
    print(string.format("Fuel        : %.1f%%",  (state.fuel_pct        or 0) * 100))
    print(string.format("Coolant     : %.1f%%",  (state.coolant_pct     or 0) * 100))
    print(string.format("Waste       : %.1f%%",  (state.waste_pct       or 0) * 100))
    print(string.format("Damage      : %s%%",    utils.formatTrimmed(state.damage, 2)))

    if radiation and radiation > 0 then
        local warningThreshold = (config.radiation and config.radiation.warning) or math.huge
        if radiation >= warningThreshold then
            setColor(STATE_COLORS.WARNING)
        end
        print(string.format("Radiation   : %s", environment.formatRadiation(radiation)))
        resetColor()
    end

    local assessment = safety.getLastAssessment()
    if assessment.event_time then
        local displayEventTime = utils.displayEventTimestamp(assessment.event_time)
        print("")
        print(string.format("Last Event  : %s at %s", assessment.event_kind or "EVENT", displayEventTime))
        if assessment.event_note and assessment.event_note ~= "" then
            print(string.format("Event Note  : %s", assessment.event_note))
        end
    end

    print("")
    print("Active      : " .. tostring(state.active))
    print("Formed      : " .. tostring(state.formed))

    if damaged then
        setColor(STATE_COLORS.SCRAM)
        print("[DAMAGE LOCK] Manual clearance required")
        resetColor()
    end

    if resetRequired then
        setColor(STATE_COLORS.WARNING)
        print("[RESET LOCK] Press R to confirm reset")
        resetColor()
    end

    print("")
    print("Press S to announce the current status.")
end

return display
