local config      = require("lib.config")
local reactor     = require("lib.reactor")
local safety      = require("lib.safety")
local display     = require("lib.display")
local alarm       = require("lib.alarm")
local notify      = require("lib.notify")
local speaker     = require("lib.speaker")
local environment = require("lib.environment")
local events      = require("lib.events")
local logger      = require("lib.logger")

-- ===== Hardware Initialisation =====
reactor.init()
alarm.init()
speaker.init()
environment.init()

-- ===== Event Wiring =====
events.on("scram", function(data)
    logger.event("SCRAM: " .. (data.reason or "unknown"))
    alarm.enable()
    notify.critical("Emergency reactor shutdown. " .. (data.reason or ""))
end)

events.on("recovered", function()
    logger.event("Reactor recovered and restarted")
    alarm.disable()
    notify.info("Reactor conditions safe. Restarting.")
end)

events.on("warning", function(data)
    logger.warn("Safety warning: entering WARNING state")
    notify.warning("Reactor safety warning. Monitor conditions.")
end)

events.on("burn_reduced", function(data)
    logger.warn(string.format("Burn rate reduced: %.2f -> %.2f mB/t", data.from, data.to))
    notify.warning("Reactor output reduced due to elevated temperature.")
end)

-- ===== Startup =====
logger.event("Reactor Safety Controller started")
notify.info("Reactor Safety Controller online.")

-- ===== Main Loop (runs concurrently with TTS playback) =====
parallel.waitForAll(
    function()
        while true do
            local state     = reactor.getState()
            local radiation = environment.getRadiation()
            local level     = safety.check(reactor, state, radiation)
            display.render(state, level, radiation, safety.isScrammed(), safety.isDamaged())

            local rad_msg = environment.getRadiationAnnouncement()
            if rad_msg then
                logger.warn(rad_msg)
                notify.warning(rad_msg)
            end

            sleep(config.check_interval)
        end
    end,
    function()
        while true do
            local _, keyCode = os.pullEvent("key")
            if keyCode == keys.s then
                local message = safety.buildAnnouncement()
                logger.event("Status announcement requested")
                notify.info(message)
            end
        end
    end,
    speaker.run
)