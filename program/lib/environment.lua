-- Environmental sensor integration.
-- Supports Advanced Peripherals environment_detector (MC 1.21.1+) and
-- environmentDetector (below 1.21.1). Returns safe defaults when no sensor
-- is found or when Mekanism is not installed.

local config = require("lib.config")
local utils = require("lib.utils")

local environment = {}
local _sensor         = nil
local _last_announce  = 0   -- os.epoch("utc") / 1000 timestamp of last TTS announcement
local _last_radiation_svh = 0
local _last_radiation_text = nil
environment.BASELINE_RADIATION = (config.radiation and config.radiation.baseline) or 9.99999e-8

local RADIATION_UNITS = {
    { factor = 1,     suffix = "Sv" },
    { factor = 1e3,   suffix = "mSv" },
    { factor = 1e6,   suffix = "µSv" },
    { factor = 1e9,   suffix = "nSv" },
}

local SCALE_FACTORS = { [""] = 1 }
for _, unit in ipairs(RADIATION_UNITS) do
    local prefix = tostring(unit.suffix or ""):match("^([%aµ]?)Sv") or ""
    SCALE_FACTORS[prefix] = unit.factor
end
-- Accept common ASCII alias and keep pico parsing support for external unit strings.
SCALE_FACTORS["u"] = SCALE_FACTORS["µ"] or 1e6
SCALE_FACTORS["p"] = 1e12

local function sanitizeUnit(unit)
    local text = tostring(unit or "Sv")
    text = text:gsub("%s+", "")
    text = text:gsub("μ", "µ")
    text = text:gsub("/s$", "")
    text = text:gsub("/m$", "")
    text = text:gsub("/t$", "")
    text = text:gsub("/h$", "")
    text = text:gsub("^uSv", "µSv")
    return text
end

local function svhFromUnitValue(value, unit)
    local number = tonumber(value) or 0
    local normalizedUnit = sanitizeUnit(unit)
    local prefix = normalizedUnit:match("^([pnumµ]?)Sv")
    local scale = SCALE_FACTORS[prefix or ""] or 1
    return number / scale
end

local function formatPeripheralRadiation(value, unit)
    local number = tonumber(value) or 0
    local normalizedUnit = sanitizeUnit(unit)
    -- Always truncate for display/TTS so values never round up (e.g. 99.9999 -> 100).
    local rendered = utils.formatTrimmed(number, 6)
    return string.format("%s %s/h", rendered, normalizedUnit)
end

local function readRadiationFromPeripheral()
    if not _sensor then
        return 0, environment.formatRadiation(0)
    end

    if _sensor.getRadiation then
        local ok, reading = pcall(_sensor.getRadiation)
        if ok and type(reading) == "table" then
            local value = reading.radiation or reading.value or reading[1]
            local unit = reading.unit or reading.units or reading[2] or "Sv"
            if type(value) == "number" then
                return svhFromUnitValue(value, unit), formatPeripheralRadiation(value, unit)
            end
        elseif ok and type(reading) == "number" then
            return reading, environment.formatRadiation(reading)
        end
    end

    if _sensor.getRadiationRaw then
        local ok, val = pcall(_sensor.getRadiationRaw)
        if ok and type(val) == "number" then
            return val, environment.formatRadiation(val)
        end
    end

    return 0, environment.formatRadiation(0)
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
    local number = tonumber(value) or 0
    if _last_radiation_text and math.abs((_last_radiation_svh or 0) - number) < 1e-15 then
        return _last_radiation_text
    end
    local unit = pickRadiationUnit(value)
    return string.format("%s %s/h", utils.formatTrimmed((value or 0) * unit.factor, 4), unit.suffix)
end

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
--- Uses getRadiation() first, then falls back to getRadiationRaw().
function environment.getRadiation()
    local svh, formatted = readRadiationFromPeripheral()
    _last_radiation_svh = svh
    _last_radiation_text = formatted
    return svh
end

--- Returns the radiation level as a human-readable string suitable for TTS.
function environment.getFormattedLevel()
    environment.getRadiation()
    return _last_radiation_text or environment.formatRadiation(_last_radiation_svh)
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
    return "Radiation alert. " .. (_last_radiation_text or environment.formatRadiation(raw))
end

return environment
