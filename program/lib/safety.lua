local config = require("lib.config")

local safety = {}

local function isUnsafe(state)
    return state.temp   >= config.MAX_TEMP
        or state.coolant <= config.MIN_COOLANT
        or state.waste   >= config.MAX_WASTE
        or state.damage  >  config.MAX_DAMAGE
end

--- Read reactor state, apply SCRAM or restart logic, and return the new
--- scrammed flag plus a state snapshot for display.
--- @param reactor table  peripheral handle
--- @param scrammed boolean
--- @return boolean, table
function safety.check(reactor, scrammed)
    local state = {
        temp    = reactor.getTemperature(),
        coolant = reactor.getCoolantFilledPercentage(),
        waste   = reactor.getWasteFilledPercentage(),
        damage  = reactor.getDamagePercent(),
        active  = reactor.getStatus(),
    }

    if isUnsafe(state) then
        if state.active then
            print("!!! REACTOR SCRAM !!!")
            reactor.scram()
        end
        scrammed = true
    else
        if scrammed and not reactor.isForceDisabled() then
            print("Conditions safe. Restarting reactor.")
            reactor.activate()
            scrammed = false
        elseif not state.active and not scrammed and not reactor.isForceDisabled() then
            reactor.activate()
        end
    end

    return scrammed, state
end

return safety
