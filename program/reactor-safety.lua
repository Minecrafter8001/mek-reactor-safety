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

events.on("recovered", function(data)
    if data and data.manual then
        logger.event("Manual reactor reset confirmed")
        notify.info("Manual reset confirmed. Reactor restarting.")
    else
        logger.event("Reactor recovered and restarted")
        notify.info("Reactor conditions safe. Restarting.")
    end
    alarm.disable()
end)

events.on("warning", function(data)
    logger.warn("Safety warning: entering WARNING state")
    notify.warning("Reactor safety warning. Monitor conditions.")
end)

events.on("burn_reduced", function(data)
    if data and data.from_pct and data.to_pct then
        logger.warn(string.format(
            "Burn rate reduced: %s%% -> %s%% of max (%s -> %s mB/t)",
            string.format("%.1f", data.from_pct * 100),
            string.format("%.1f", data.to_pct * 100),
            string.format("%.2f", data.from_rate or 0),
            string.format("%.2f", data.to_rate or 0)
        ))
    else
        logger.warn(string.format("Burn rate reduced: %s -> %s mB/t", data.from, data.to))
    end
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
            display.render(
                state,
                level,
                radiation,
                safety.isScrammed(),
                safety.isResetRequired(),
                safety.isDamaged()
            )

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
            elseif keyCode == keys.r then
                local ok, reason = safety.requestReset(reactor)
                if ok then
                    logger.event("Manual reset confirmed")
                    notify.info("Reset confirmed. Reactor restart requested.")
                else
                    logger.warn("Reset request denied: " .. (reason or "unknown"))
                    notify.warning("Reset not allowed. " .. (reason or "unknown"))
                end
            end
        end
    end,
    speaker.run
)