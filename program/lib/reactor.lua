-- Reactor peripheral abstraction.
-- Wraps fissionReactorLogicAdapter and exposes normalised state and controls.

local reactor = {}
local _handle = nil

--- Locate and bind the reactor peripheral.
--- @param name string|nil  optional specific peripheral name; auto-finds if omitted
function reactor.init(name)
    _handle = name and peripheral.wrap(name)
           or peripheral.find("fissionReactorLogicAdapter")
    if not _handle then
        error("No Fission Reactor Logic Adapter found")
    end
end

--- Returns a snapshot of all safety-relevant reactor metrics.
--- All tank levels are normalised to 0–1 fractions.
function reactor.getState()
    if not _handle then
        error("Reactor peripheral not initialised")
    end
    return {
        temp               = _handle.getTemperature(),
        burn_rate          = _handle.getBurnRate(),
        actual_burn_rate   = _handle.getActualBurnRate(),
        fuel_pct           = _handle.getFuelFilledPercentage(),
        coolant_pct        = _handle.getCoolantFilledPercentage(),
        heated_coolant_pct = _handle.getHeatedCoolantFilledPercentage(),
        waste_pct          = _handle.getWasteFilledPercentage(),
        damage             = _handle.getDamagePercent(),
        active             = _handle.getStatus(),
        formed             = _handle.isFormed(),
        force_disabled     = _handle.isForceDisabled(),
    }
end

function reactor.scram()
    if not _handle then
        error("Reactor peripheral not initialised")
    end
    _handle.scram()
end

function reactor.activate()
    if not _handle then
        error("Reactor peripheral not initialised")
    end
    _handle.activate()
end

function reactor.setBurnRate(rate)
    if not _handle then
        error("Reactor peripheral not initialised")
    end
    _handle.setBurnRate(rate)
end

return reactor
