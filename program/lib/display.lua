local display = {}

function display.render(state)
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Reactor Safety ===")
    print(string.format("Temperature : %.1f K",  state.temp))
    print(string.format("Coolant     : %.1f%%",  state.coolant * 100))
    print(string.format("Waste       : %.1f%%",  state.waste   * 100))
    print(string.format("Damage      : %.2f%%",  state.damage))
    print("Active       : " .. tostring(state.active))
end

return display
