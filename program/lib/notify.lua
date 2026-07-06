-- Priority-based voice notification queue.
-- Delegates audio playback to lib/speaker, which runs concurrently via
-- parallel.waitForAll so TTS never blocks reactor monitoring.

local config  = require("lib.config")
local speaker = require("lib.speaker")

local notify = {}

local PRIORITY = { INFO = 1, WARNING = 2, CRITICAL = 3 }
notify.PRIORITY = PRIORITY

local function enqueue(msg, priority)
    if not config.notify.tts_enabled then return end
    -- Critical messages discard the queue and stop current playback immediately
    if priority == PRIORITY.CRITICAL then
        speaker.clearQueue()
    end
    speaker.enqueue(msg, config.notify.voice or "")
end

function notify.info(msg)     enqueue(msg, PRIORITY.INFO)     end
function notify.warning(msg)  enqueue(msg, PRIORITY.WARNING)  end
function notify.critical(msg) enqueue(msg, PRIORITY.CRITICAL) end

return notify
