-- Operational logger. Writes timestamped entries to a log file.
-- Entries are buffered and flushed in batches to reduce disk I/O.

local config = require("lib.config")
local utils = require("lib.utils")

local logger = {}

local _path    = (config.log and config.log.path)       or "/logs/reactor.log"
local _max_buf = (config.log and config.log.max_buffer) or 10
local _buffer  = {}
local _dir_ready = false

local function ensureDir()
    if _dir_ready then
        return true
    end

    local dir = fs.getDir(_path)
    if not dir or dir == "" then
        _dir_ready = true
        return true
    end

    if not fs.exists(dir) then
        local ok = pcall(fs.makeDir, dir)
        if not ok then
            return false
        end
    end

    _dir_ready = fs.exists(dir)
    return _dir_ready
end

local function flush()
    if #_buffer == 0 then return end
    if not ensureDir() then
        return
    end
    local f = fs.open(_path, "a")
    if f then
        for _, line in ipairs(_buffer) do
            f.writeLine(line)
        end
        f.close()
    end
    _buffer = {}
end

local function write(level, msg)
    ensureDir()
    local entry = string.format("[%s][%s] %s", utils.localTimestamp(), level, msg)
    table.insert(_buffer, entry)
    if #_buffer >= _max_buf then
        flush()
    end
end

ensureDir()

function logger.info(msg)  write("INFO",  msg) end
function logger.warn(msg)  write("WARN",  msg) end
function logger.error(msg) write("ERROR", msg) end
function logger.event(msg) write("EVENT", msg) end

--- Flush any remaining buffered entries to disk. Call on shutdown.
function logger.close()
    flush()
end

return logger
