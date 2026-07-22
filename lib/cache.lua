local M = {}

local json = require("json")

local CACHE_TTL_SECONDS = 24 * 60 * 60

--- Quotes a value for use as one POSIX shell argument.
---@param value any Value to quote.
---@return string quoted Shell-quoted value.
local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Builds the mise-db cache directory path.
---@return string path Cache directory path.
function M.dir()
    local base = os.getenv("XDG_CACHE_HOME")
    if base == nil or base == "" then
        local home = os.getenv("HOME")
        if home == nil or home == "" then
            error("HOME is required when XDG_CACHE_HOME is not set")
        end
        base = home .. "/.cache"
    end

    return base .. "/mise-db"
end

--- Returns a file's modification time.
---@param path string Path.
---@return number|nil timestamp Unix timestamp, or nil when unavailable.
function M.file_mtime(path)
    local commands = {
        "stat -f %m " .. shell_quote(path) .. " 2>/dev/null",
        "stat -c %Y " .. shell_quote(path) .. " 2>/dev/null",
    }

    for _, command in ipairs(commands) do
        local handle = io.popen(command)
        if handle then
            local output = handle:read("*l")
            local ok = handle:close()
            local timestamp = tonumber(output)
            if ok and timestamp ~= nil then
                return timestamp
            end
        end
    end

    return nil
end

--- Returns whether registry caching is enabled.
---@return boolean enabled True when cache reads and writes are enabled.
function M.enabled()
    return os.getenv("MISE_DB_CACHE") ~= "0"
end

--- Builds a cache file path.
---@param name string Cache file name.
---@return string path Cache file path.
function M.file(name)
    return M.dir() .. "/" .. name
end

--- Checks whether a cache file is younger than the cache TTL.
---@param path string Cache file path.
---@return boolean fresh True when cache can be reused.
function M.fresh(path)
    local mtime = M.file_mtime(path)
    if mtime == nil then
        return false
    end

    return os.time() - mtime < CACHE_TTL_SECONDS
end

--- Returns whether a path exists.
---@param path string Path.
---@return boolean exists True when the path exists.
function M.path_exists(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end

    file:close()
    return true
end

--- Reads a JSON cache file.
---@param path string Cache file path.
---@return table|nil value Cached value, or nil when unavailable.
function M.read_json(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local body = file:read("*a")
    file:close()

    local ok, value = pcall(json.decode, body)
    if not ok or type(value) ~= "table" then
        return nil
    end

    return value
end

--- Writes a JSON cache file atomically.
---@param path string Cache file path.
---@param value table Cache value.
function M.write_json(path, value)
    os.execute("mkdir -p " .. shell_quote(M.dir()))

    local unique = tostring({}):gsub("[^A-Za-z0-9]", "")
    local temp_file = path .. ".tmp." .. tostring(os.time()) .. "." .. unique
    local file = assert(io.open(temp_file, "w"))
    file:write(json.encode(value))
    file:write("\n")
    file:close()

    os.rename(temp_file, path)
end

--- Returns a cached value or executes a callback and caches its result.
---@param name string Cache file name.
---@param callback fun(): table Callback that produces a fresh cache value.
---@return table value Cached or fresh value.
function M.caching(name, callback)
    if not M.enabled() then
        io.stderr:write("mise-db: registry cache disabled; fetching data from Docker Hub...\n")
        return callback()
    end

    local path = M.file(name)
    if M.path_exists(path) and M.fresh(path) then
        local value = M.read_json(path)
        if value ~= nil then
            io.stderr:write("mise-db: using cached registry data from " .. path .. "\n")
            return value
        end
    end

    io.stderr:write("mise-db: registry cache missing/expired; fetching data from Docker Hub...\n")
    local value = callback()
    M.write_json(path, value)
    return value
end

return M
