local M = {}

local CYAN = "\27[36m"
local ORANGE = "\27[38;5;208m"
local RED = "\27[31m"
local RESET = "\27[0m"

--- Capitalizes the first ASCII letter in a message.
---@param message any Message text.
---@return string message Capitalized message text.
local function capitalize(message)
    return tostring(message):gsub("^%l", string.upper)
end

--- Returns whether stderr is attached to a terminal.
---@return boolean terminal True when stderr is a TTY.
local function stderr_is_terminal()
    local ok = os.execute("test -t 2")
    return ok == true or ok == 0
end

--- Formats a mise-db-owned message.
---@param message any Message text.
---@param color string|nil Optional ANSI color.
---@return string formatted Prefixed and optionally colored message.
local function format(message, color)
    local formatted = "[mise-db] " .. capitalize(message)
    if color ~= nil and stderr_is_terminal() then
        return color .. formatted .. RESET
    end
    return formatted
end

--- Prints a debug message when DEBUG=1.
---@param message any Message text.
---@return nil
function M.debug(message)
    if M.enabled() then
        io.stderr:write(format(message, CYAN) .. "\n")
    end
end

--- Returns whether debug logging is enabled.
---@return boolean enabled True only when DEBUG is exactly "1".
function M.enabled()
    return os.getenv("DEBUG") == "1"
end

--- Raises a formatted mise-db error.
---@param message any Error text.
---@return never
function M.error(message)
    error(format(message, RED), 0)
end

--- Prints a normal informational message.
---@param message any Message text.
---@return nil
function M.info(message)
    io.stderr:write(format(message) .. "\n")
end

--- Prints a warning message.
---@param message any Warning text.
---@return nil
function M.warn(message)
    io.stderr:write(format(message, ORANGE) .. "\n")
end

return M
