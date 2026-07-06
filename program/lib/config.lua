return {
    -- Temperature thresholds (Kelvin)
    temp = {
        warning   = 800,
        reduce    = 950,
        emergency = 1100,
    },
    -- Coolant thresholds (0–1 fraction)
    coolant = {
        warning  = 0.30,
        critical = 0.20,
    },
    -- Waste thresholds (0–1 fraction)
    waste = {
        warning  = 0.80,
        critical = 0.95,
    },
    -- Damage: any nonzero value triggers SCRAM
    damage = {
        threshold = 0,
    },
    -- Radiation (Sv/h)
    -- Mekanism background radiation is ~99.9999 nSv/h (9.99999e-8 Sv/h).
    -- warning  : above-background level; triggers safety WARNING state and TTS announcements
    -- critical : SCRAM threshold
    -- announce_interval : minimum seconds between repeated radiation level TTS alerts
    radiation = {
        warning           = 1e-7,  -- ~100 nSv/h (background)
        critical          = 1e-3,  -- 1 mSv/h
        announce_interval = 60,    -- seconds
    },
    -- Burn rate control (mB/t)
    burn_rate = {
        min         = 0.1,
        reduce_step = 0.5,
    },
    -- Recovery settings
    recovery = {
        require_manual_after_damage = true,
    },
    -- Main loop timing (seconds)
    check_interval = 0.5,
    -- Logging
    log = {
        path       = "/logs/reactor.log",
        max_buffer = 10,
    },
    -- Notifications
    notify = {
        tts_enabled = true,
        volume      = 1.0,
        voice       = "",   -- espeak voice id ("" = server default, e.g. "en-gb-scotland")
    },
}
