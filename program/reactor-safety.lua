local config  = require("lib.config")
local safety  = require("lib.safety")
local display = require("lib.display")

local reactor = peripheral.find("fissionReactorLogicAdapter")

if not reactor then
    error("No Fission Reactor Logic Adapter found")
end

local scrammed = false

while true do
    local state
    scrammed, state = safety.check(reactor, scrammed)
    display.render(state)
    sleep(config.CHECK_INTERVAL)
end