-- Environmental sensor integration.
-- Supports Advanced Peripherals environment_detector (MC 1.21.1+) and
-- environmentDetector (below 1.21.1). Returns safe defaults when no sensor
-- is found or when Mekanism is not installed.

local config = require("lib.config")

local environment = {}
local _sensor         = nil
local _last_announce  = 0   -- os.epoch("utc") / 1000 timestamp of last TTS announcement
environment.BASELINE_RADIATION = (config.radiation and config.radiation.baseline) or 9.99999e-8

local RADIATION_UNITS = {
    { factor = 1,     suffix = "Sv/h" },
    { factor = 1e3,   suffix = "mSv/h" },
    { factor = 1e6,   suffix = "µSv/h" },
    { factor = 1e9,   suffix = "nSv/h" },
}

local function formatTrimmed(value, decimals)
    local places = math.max(0, math.floor(tonumber(decimals) or 2))
    local scale = 10 ^ places
    local number = tonumber(value) or 0
    local truncated = (number >= 0)
        and (math.floor(number * scale) / scale)
        or (math.ceil(number * scale) / scale)
    local formatted = string.format("%." .. tostring(places) .. "f", truncated)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    if formatted == "-0" then
        formatted = "0"
    end
    return formatted
end

local function pickRadiationUnit(value)
    local magnitude = math.abs(value or 0)

    for index = #RADIATION_UNITS, 1, -1 do
        local unit = RADIATION_UNITS[index]
        if magnitude * unit.factor >= 1 or index == #RADIATION_UNITS then
            return unit
        end
    end

    return RADIATION_UNITS[1]
end

--- Format a radiation value using the most readable unit.
function environment.formatRadiation(value)
    local unit = pickRadiationUnit(value)
    return string.format("%s %s", formatTrimmed((value or 0) * unit.factor, 4), unit.suffix)
end

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
--- e.g. "99.9999 nSv/h". Uses the raw radiation reading.
function environment.getFormattedLevel()
    return environment.formatRadiation(environment.getRadiation())
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
    return "Radiation alert. " .. environment.formatRadiation(raw)
end

return environment
