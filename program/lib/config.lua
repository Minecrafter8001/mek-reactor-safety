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
    -- Waste control thresholds (0–1 fraction)
    -- Waste no longer triggers WARNING/SCRAM directly.
    -- If waste reaches stop, the reactor is paused (shut down) until
    -- waste falls back below start.
    waste = {
        start = 0.20, -- resume threshold (auto-clear waste pause below this)
        stop  = 0.95, -- pause threshold (shut down reactor at/above this)
    },
    -- Damage: any nonzero value triggers SCRAM
    damage = {
        threshold = 0,
    },
    -- Radiation (Sv/h)
    -- Mekanism background radiation is ~99.9999 nSv/h (9.99999e-8 Sv/h).
    -- Gameplay effects are based on:
    --   scaled = clamp((ln(trueRadiation) + 5) / 7, 0..1)
    --   chance in [0.1, 1.0]
    --   damage when scaled > chance
    -- Key breakpoints:
    --   scaled = 0.1  -> trueRadiation ~= 0.0135 Sv/h (13.5 mSv/h), first possible damage
    --   scaled = 0.55 -> trueRadiation ~= 0.316 Sv/h, ~50% damage/hunger tick chance
    -- warning  : pre-effect early warning below first-damage threshold
    -- critical : severe exposure SCRAM threshold around high per-tick hit probability
    -- announce_interval : minimum seconds between repeated radiation level TTS alerts
    radiation = {
        baseline          = 9.99999e-8, -- 99.9999 nSv/h background level
        warning           = 1e-2,  -- 10 mSv/h early warning (pre-damage zone)
        critical          = 3.16e-1, -- 316 mSv/h severe zone (~50% tick damage chance)
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
        volume      = 3.0,  -- speaker playback volume (0.0 to 3.0)
        voice       = "",   -- espeak voice id ("" = server default, e.g. "en-gb-scotland")
        tts_word_gap = ", ", -- separator used between words when speaking
    },
}
