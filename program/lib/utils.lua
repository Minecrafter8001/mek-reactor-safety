local utils = {}

--- Returns a local date-time timestamp string.
function utils.localTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

--- Truncate a number to N decimals and trim trailing zero padding.
function utils.formatTrimmed(value, decimals)
    local places = math.max(0, math.floor(tonumber(decimals) or 2))
    local scale = 10 ^ places
    local number = tonumber(value) or 0
    local truncated = (number >= 0)
        and (math.floor(number * scale) / scale)
        or (math.ceil(number * scale) / scale)
    local formatted = string.format("%." .. tostring(places) .. "f", truncated)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    if formatted == "-0" then
        formatted = "0"
    end
    return formatted
end

return utils
