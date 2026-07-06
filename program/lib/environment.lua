-- Environmental sensor integration.
-- Supports Advanced Peripherals environment_detector (MC 1.21.1+) and
-- environmentDetector (below 1.21.1). Returns safe defaults when no sensor
-- is found or when Mekanism is not installed.

local config = require("lib.config")

local environment = {}
local _sensor         = nil
local _last_announce  = 0   -- os.epoch("utc") / 1000 timestamp of last TTS announcement

-- Maps Mekanism unit abbreviations to full spoken words for TTS.
-- Abbreviations and multipliers from Mekanism's EnumUtils unit table.
local UNIT_NAMES = {
    ["f"] = "femto",
    ["p"] = "pico",
    ["n"] = "nano",
    ["µ"] = "micro",
    ["m"] = "milli",
    [""]  = "",
    ["k"] = "kilo",
    ["M"] = "mega",
    ["G"] = "giga",
    ["T"] = "tera",
    ["P"] = "peta",
    ["E"] = "exa",
    ["Z"] = "zetta",
    ["Y"] = "yotta",
}

--- Locate an environmental sensor peripheral.
function environment.init()
    _sensor = peripheral.find("environment_detector")
           or peripheral.find("environmentDetector")
end

--- Returns true if an environmental sensor is connected.
function environment.available()
    return _sensor ~= nil
end

--- Returns the current radiation level in Sv/h, or 0 if unavailable.
--- Uses getRadiationRaw() which returns a plain number.
--- getRadiation() returns a table {radiation, unit} and is not used here.
function environment.getRadiation()
    if _sensor and _sensor.getRadiationRaw then
        local ok, val = pcall(_sensor.getRadiationRaw)
        return (ok and type(val) == "number") and val or 0
    end
    return 0
end

--- Returns the radiation level as a human-readable string suitable for TTS,
--- e.g. "125.3 nano Sievert per hour". Uses getRadiation() (table form).
function environment.getFormattedLevel()
    if not (_sensor and _sensor.getRadiation) then
        return "unknown radiation level"
    end
    local ok, result = pcall(_sensor.getRadiation)
    if not ok or type(result) ~= "table" then
        return "unknown radiation level"
    end
    local unit_full = UNIT_NAMES[result.unit]
    if unit_full == nil then unit_full = result.unit end
    local sv = (unit_full ~= "") and (unit_full .. " Sievert") or "Sievert"
    return string.format("%s %s per hour", result.radiation, sv)
end

--- Returns a TTS announcement string if radiation exceeds config.radiation.warning
--- and at least config.radiation.announce_interval seconds have passed since the
--- last announcement. Returns nil otherwise.
--- When radiation drops back to safe levels the timer resets so the next
--- elevation is announced immediately.
function environment.getRadiationAnnouncement()
    local raw = environment.getRadiation()
    if raw <= config.radiation.warning then
        _last_announce = 0
        return nil
    end
    local now = math.floor(os.epoch("utc") / 1000)
    if now - _last_announce < config.radiation.announce_interval then
        return nil
    end
    _last_announce = now
    return "Radiation alert. " .. environment.getFormattedLevel()
end

return environment
