local M = {}

--- Tool names implemented by this plugin.
---@type string[]
M.supported_tools = { "postgres" }

--- Ensures only implemented tools are accepted.
---@param tool string Tool name from mise.
---@return nil
function M.validate_tool(tool)
    for _, supported_tool in ipairs(M.supported_tools) do
        if tool == supported_tool then
            return
        end
    end

    error("unsupported tool '" .. tostring(tool) .. "'; supported tools: " .. table.concat(M.supported_tools, ", "))
end

--- Quotes a value for use as one POSIX shell argument.
---@param value any Value to quote.
---@return string quoted Shell-quoted value.
function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Looks up a per-tool option from known mise context containers.
---@param ctx table Mise backend hook context.
---@param key string Option key to read.
---@return any value Option value, or nil when unset.
function M.table_option(ctx, key)
    local containers = {
        ctx.options,
        ctx.opts,
        ctx.tool_options,
        ctx.backend_options,
        ctx.config,
    }

    for _, container in ipairs(containers) do
        if type(container) == "table" and container[key] ~= nil then
            return container[key]
        end
    end

    return nil
end

--- Reads a boolean option from the mise context.
---@param ctx table Mise backend hook context.
---@param key string Option key to read.
---@param default boolean Default value when unset or unrecognized.
---@return boolean value Parsed boolean option.
function M.boolean_option(ctx, key, default)
    local value = M.table_option(ctx, key)
    if value == nil then
        return default
    end
    if value == true or value == "true" or value == "1" then
        return true
    end
    if value == false or value == "false" or value == "0" then
        return false
    end
    return default
end

--- Loads the metadata module for a supported tool.
---@param tool string Tool name from mise.
---@return table tool_module Per-tool metadata and behavior.
function M.tool(tool)
    M.validate_tool(tool)
    return dofile(RUNTIME.pluginDirPath .. "/lib/" .. tool .. ".lua")
end

return M
