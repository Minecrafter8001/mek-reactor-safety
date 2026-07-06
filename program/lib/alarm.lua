-- Industrial alarm control via the redstone API.
-- The industrialAlarm peripheral has no enable/disable methods; it responds
-- to redstone signals. setRedstoneMode("HIGH") configures each alarm to
-- activate when it receives a HIGH signal, which the computer outputs on the
-- side the alarm is connected to (the peripheral name IS the side for
-- directly-connected peripherals).

local alarm = {}
local _devices = {}

--- Scan for connected industrial alarms and configure their redstone mode.
function alarm.init()
    for _, name in ipairs(peripheral.getNames()) do
        local t = peripheral.getType(name)
        if t == "industrialAlarm" or t == "alarm" then
            local h = peripheral.wrap(name)
            -- Alarm activates when it receives a HIGH redstone signal
            if h.setRedstoneMode then
                pcall(h.setRedstoneMode, "HIGH")
            end
            table.insert(_devices, { side = name })
        end
    end
end

--- Output a HIGH redstone signal on each alarm side to activate them.
function alarm.enable()
    for _, dev in ipairs(_devices) do
        redstone.setOutput(dev.side, true)
    end
end

--- Remove the redstone signal from each alarm side to deactivate them.
function alarm.disable()
    for _, dev in ipairs(_devices) do
        redstone.setOutput(dev.side, false)
    end
end

--- Pulse alarms on for duration seconds then off.
--- @param duration number  seconds (default 1)
function alarm.pulse(duration)
    alarm.enable()
    sleep(duration or 1)
    alarm.disable()
end

--- Returns the number of connected alarm devices.
function alarm.count()
    return #_devices
end

return alarm
