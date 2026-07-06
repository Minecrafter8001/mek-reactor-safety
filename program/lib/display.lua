local display = {}

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
--- @param damaged   boolean whether a damage lock is active
function display.render(state, level, radiation, scrammed, damaged)
    term.clear()
    term.setCursorPos(1, 1)

    setColor(STATE_COLORS[level])
    print("=== Reactor Safety Controller ===")
    print(string.format("Status      : %s", STATE_LABELS[level] or level))
    resetColor()
    print("")

    print(string.format("Temperature : %.1f K",    state.temp))
    print(string.format("Burn Rate   : %.2f mB/t (actual: %.2f)",
        state.burn_rate or 0, state.actual_burn_rate or 0))
    print(string.format("Fuel        : %.1f%%",  (state.fuel_pct        or 0) * 100))
    print(string.format("Coolant     : %.1f%%",  (state.coolant_pct     or 0) * 100))
    print(string.format("Waste       : %.1f%%",  (state.waste_pct       or 0) * 100))
    print(string.format("Damage      : %.2f%%",   state.damage           or 0))

    if radiation and radiation > 0 then
        setColor(STATE_COLORS.WARNING)
        print(string.format("Radiation   : %.4f Sv/h", radiation))
        resetColor()
    end

    print("")
    print("Active      : " .. tostring(state.active))
    print("Formed      : " .. tostring(state.formed))

    if damaged then
        setColor(STATE_COLORS.SCRAM)
        print("[DAMAGE LOCK] Manual clearance required")
        resetColor()
    end

    print("")
    print("Press S to announce the current status.")
end

return display
