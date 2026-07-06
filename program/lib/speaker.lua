-- Multi-speaker management with CCSpeaks TTS.
-- Discovers all speaker peripherals (direct or via wired modem) and plays
-- decoded DFPWM audio through all of them simultaneously.
-- Use speaker.run() with parallel.waitForAll alongside the main safety loop.

local speaker = {}
local _speakers = {}
local _queue    = {}

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
local function playBufferAll(buffer)
    -- First pass: submit to all speakers; record those that rejected (buffer full).
    local retry = {}
    for _, s in ipairs(_speakers) do
        if not s.handle.playAudio(buffer) then
            retry[s.name] = s.handle
        end
    end
    -- Re-submit to each speaker as it signals it is free.
    while next(retry) do
        local _, name = os.pullEvent("speaker_audio_empty")
        local h = retry[name]
        if h and h.playAudio(buffer) then
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
    local url = "https://music.madefor.cc/tts?text=" .. textutils.urlEncode(text)
    if voice and voice ~= "" then
        url = url .. "&voice=" .. textutils.urlEncode(voice)
    end

    local response = http.get({ url = url, binary = true })
    if not response then return end  -- network failure; skip message

    local decoder = require("cc.audio.dfpwm").make_decoder()
    while true do
        local chunk = response.read(16 * 1024)
        if not chunk then break end
        playBufferAll(decoder(chunk))
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
