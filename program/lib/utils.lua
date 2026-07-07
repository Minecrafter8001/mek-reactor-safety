local utils = {}

--- Returns a local date-time timestamp string.
function utils.localTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

--- Returns an event timestamp formatted for display/TTS alignment.
--- Format: d,m,yyyy h:mm:ss AM/PM (no leading zeros on day/month/hour)
function utils.eventTimestamp()
    local stamp = tostring(os.date("%d,%m,%Y %I:%M:%S %p"))
    stamp = stamp:gsub("^0(%d),", "%1,")
    stamp = stamp:gsub(",0(%d),", ",%1,")
    stamp = stamp:gsub(" 0(%d):", " %1:")
    return stamp
end

--- Converts event timestamp text to display-friendly dd-mm-yyyy date format.
--- Input examples:
---   d,m,yyyy h:mm:ss AM/PM
---   dd,mm,yyyy h:mm:ss AM/PM
function utils.displayEventTimestamp(value)
    local text = tostring(value or "")
    local day, month, year, rest = text:match("^(%d%d?),(%d%d?),(%d%d%d%d)%s+(.+)$")
    if not day then
        return text
    end
    return string.format("%02d-%02d-%s %s", tonumber(day) or 0, tonumber(month) or 0, year, rest)
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
