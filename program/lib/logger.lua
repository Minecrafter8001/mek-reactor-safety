-- Operational logger. Writes timestamped entries to a log file.
-- Logging is fail-fast: filesystem errors are raised immediately.

local config = require("lib.config")
local utils = require("lib.utils")

local logger = {}

local _path = (config.log and config.log.path) or "/logs/reactor.log"
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

    if fs.exists(dir) and not fs.isDir(dir) then
        error("Log path parent exists but is not a directory: " .. tostring(dir), 2)
    end

    if not fs.exists(dir) then
        local ok, err = pcall(fs.makeDir, dir)
        if not ok then
            error("Failed to create log directory '" .. tostring(dir) .. "': " .. tostring(err), 2)
        end
    end

    if not fs.exists(dir) then
        error("Log directory does not exist after creation attempt: " .. tostring(dir), 2)
    end

    _dir_ready = true
    return true
end

local function appendLine(line)
    ensureDir()

    local file = fs.open(_path, "a")
    if not file then
        error("Failed to open log file for append: " .. tostring(_path), 2)
    end

    local ok, err = pcall(function()
        file.writeLine(line)
        file.close()
    end)
    if not ok then
        error("Failed writing log entry to '" .. tostring(_path) .. "': " .. tostring(err), 2)
    end
end

local function write(level, msg)
    local entry = string.format("[%s][%s] %s", utils.localTimestamp(), level, msg)
    appendLine(entry)
end

function logger.info(msg)  write("INFO",  msg) end
function logger.warn(msg)  write("WARN",  msg) end
function logger.error(msg) write("ERROR", msg) end
function logger.event(msg) write("EVENT", msg) end

-- Writes are immediate; close only validates destination availability.
function logger.close()
    ensureDir()
end

-- Fail fast on startup if the log target is invalid, and ensure file exists.
ensureDir()
do
    local file = fs.open(_path, "a")
    if not file then
        error("Failed to initialize log file: " .. tostring(_path), 2)
    end
    file.close()
end

return logger
