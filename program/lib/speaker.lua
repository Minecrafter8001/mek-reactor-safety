-- Multi-speaker management with CCSpeaks TTS.
-- Discovers all speaker peripherals (direct or via wired modem) and plays
-- decoded DFPWM audio through all of them simultaneously.
-- Use speaker.run() with parallel.waitForAll alongside the main safety loop.

local speaker = {}
local _speakers = {}
local _queue    = {}

local config = require("lib.config")
local logger = require("lib.logger")

local SCALE_WORDS = {
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

local UNIT_WORDS = {
    ["B"]  = "bucket",
    ["Sv"] = "sieverts",
    ["K"]  = "Kelvin",
}

local TIME_WORDS = {
    ["t"] = "per tick",
    ["m"] = "per minute",
    ["h"] = "per hour",
}

local PRONUNCIATION_WORDS = {
    ["fuel"] = "fyuel",
    ["AM"] = "A , M",
    ["PM"] = "P , M",
}

local PREFIX_PATTERN = "[fpnµmkMGTPEZY]?"

local function expandScaled(scale, unit, time)
    local parts = {}
    local scaleWord = SCALE_WORDS[scale] or scale
    local unitWord = UNIT_WORDS[unit] or unit

    if scaleWord ~= "" then
        parts[#parts + 1] = scaleWord
    end
    parts[#parts + 1] = unitWord

    if time and time ~= "" then
        local timeWord = TIME_WORDS[time] or time
        parts[#parts + 1] = timeWord
    end

    return table.concat(parts, " ")
end

local function expandScaledWithTime(text, units)
    local expanded = text
    for _, unit in ipairs(units) do
        local pattern = "(" .. PREFIX_PATTERN .. ")(" .. unit .. ")([/][th])"
        expanded = expanded:gsub(pattern, function(scale, matchedUnit, time)
            return expandScaled(scale, matchedUnit, time:sub(2, 2))
        end)
    end
    return expanded
end

local function expandScaledWithoutTime(text, units)
    local expanded = text
    for _, unit in ipairs(units) do
        local pattern = "(" .. PREFIX_PATTERN .. ")(" .. unit .. ")"
        expanded = expanded:gsub(pattern, function(scale, matchedUnit)
            return expandScaled(scale, matchedUnit)
        end)
    end
    return expanded
end

local function expandUnits(text)
    local expanded = tostring(text or "")

    expanded = expandScaledWithTime(expanded, { "B", "Sv" })
    expanded = expandScaledWithoutTime(expanded, { "B", "Sv", "K" })

    expanded = expanded:gsub("%%", " percent")

    return expanded
end

local function getPlaybackVolume()
    local notifyConfig = config.notify or {}
    local volume = tonumber(notifyConfig.volume) or 1
    return volume
end

local function to12Hour(hour24)
    local h = tonumber(hour24) or 0
    local suffix = "AM"
    if h >= 12 then
        suffix = "PM"
    end
    h = h % 12
    if h == 0 then
        h = 12
    end
    return h, suffix
end

local function rewriteDateTimeForTTS(text)
    local rewritten = tostring(text or "")

    rewritten = rewritten:gsub(
        "(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)",
        function(year, month, day, hour, minute, second)
            local hour12, suffix = to12Hour(hour)
            return string.format("%d,%d,%s %d:%s:%s %s", tonumber(day) or 0, tonumber(month) or 0, year, hour12, minute, second, suffix)
        end
    )

    rewritten = rewritten:gsub(
        "(%d%d%d%d)%-(%d%d)%-(%d%d)",
        function(year, month, day)
            return string.format("%d,%d,%s", tonumber(day) or 0, tonumber(month) or 0, year)
        end
    )

    rewritten = rewritten:gsub(
        "(%d%d):(%d%d):(%d%d)",
        function(hour, minute, second)
            local hour12, suffix = to12Hour(hour)
            return string.format("%d:%s:%s %s", hour12, minute, second, suffix)
        end
    )

    return rewritten
end

local function formatForTTS(text)
    local notifyConfig = config.notify or {}
    local wordGap = notifyConfig.tts_word_gap

    text = rewriteDateTimeForTTS(text)
    text = expandUnits(text)

    for source, replacement in pairs(PRONUNCIATION_WORDS) do
        text = text:gsub("%f[%a]" .. source .. "%f[%A]", replacement)
    end

    if type(wordGap) ~= "string" or wordGap == "" then
        return text
    end

    local normalized = tostring(text or "")
    normalized = normalized:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return normalized:gsub(" ", wordGap)
end

--- Locate all connected speaker peripherals.
function speaker.init()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            table.insert(_speakers, {
                name   = name,
                handle = peripheral.wrap(name),
            })
        end
    end
end

--- Returns the number of connected speakers.
function speaker.count() return #_speakers end

--- Returns true if at least one speaker is connected.
function speaker.available() return #_speakers > 0 end

--- Play a decoded DFPWM audio buffer through all speakers simultaneously.
--- Blocks (yielding) until every speaker has accepted the buffer.
local function playBufferAll(buffer, volume)
    volume = volume or getPlaybackVolume()
    -- First pass: submit to all speakers; record those that rejected (buffer full).
    local retry = {}
    for _, s in ipairs(_speakers) do
        if not s.handle.playAudio(buffer, volume) then
            retry[s.name] = s.handle
        end
    end
    -- Re-submit to each speaker as it signals it is free.
    while next(retry) do
        local _, name = os.pullEvent("speaker_audio_empty")
        local h = retry[name]
        if h and h.playAudio(buffer, volume) then
            retry[name] = nil
        end
        -- If h.playAudio still returns false the speaker is still busy;
        -- it will emit another speaker_audio_empty when ready.
    end
end

--- Fetch TTS audio from CCSpeaks and stream it through all speakers.
--- @param text  string  message to speak
--- @param voice string  espeak voice id, or "" for the server default
local function say(text, voice)
    local formattedText = formatForTTS(text)
    logger.info(string.format("[tts][say][input] %s", tostring(text or "")))
    logger.info(string.format("[tts][say][formatted] %s", tostring(formattedText or "")))
    local url = "https://music.madefor.cc/tts?text=" .. textutils.urlEncode(formattedText)
    if voice and voice ~= "" then
        url = url .. "&voice=" .. textutils.urlEncode(voice)
    end

    local response = http.get({ url = url, binary = true })
    if not response then return end  -- network failure; skip message

    local decoder = require("cc.audio.dfpwm").make_decoder()
    local volume = getPlaybackVolume()
    while true do
        local chunk = response.read(16 * 1024)
        if not chunk then break end
        playBufferAll(decoder(chunk), volume)
    end
    response.close()
end

--- Enqueue a message for TTS playback.
--- @param text  string  message to speak
--- @param voice string  espeak voice id, or "" for the server default
function speaker.enqueue(text, voice)
    table.insert(_queue, { text = text, voice = voice or "" })
end

--- Discard all queued messages and immediately stop playback on all speakers.
function speaker.clearQueue()
    _queue = {}
    for _, s in ipairs(_speakers) do
        pcall(s.handle.stop)
    end
end

--- Background playback loop — pass this to parallel.waitForAll alongside
--- the main safety loop so TTS never blocks reactor monitoring.
function speaker.run()
    while true do
        if #_speakers > 0 and #_queue > 0 then
            local item = table.remove(_queue, 1)
            say(item.text, item.voice)
        else
            sleep(0.1)
        end
    end
end

return speaker
