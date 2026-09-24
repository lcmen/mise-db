local M = {}

local log = dofile(RUNTIME.pluginDirPath .. "/lib/log.lua")

--- Tool names implemented by this plugin.
---@type string[]
M.supported_tools = { "postgres", "redis" }

--- Checks whether a runtime adapter is available.
---@param adapter string Runtime adapter, either "apple" or "docker".
---@return string|nil adapter The adapter name when available, or nil otherwise.
local function adapter_available(adapter)
    local cmd = require("cmd")
    local command

    if adapter == "apple" then
        command = "container system status >/dev/null 2>&1"
    elseif adapter == "docker" then
        command = "docker info >/dev/null 2>&1"
    else
        return nil
    end

    return pcall(cmd.exec, command) and adapter or nil
end

--- Detects the current host architecture in OCI platform terms.
---@return string|nil architecture OCI architecture, or nil when unknown.
function M.arch()
    local handle = io.popen("uname -m 2>/dev/null")
    if not handle then
        return nil
    end

    local machine = handle:read("*l")
    handle:close()

    if machine == "arm64" or machine == "aarch64" then
        return "arm64"
    end
    if machine == "x86_64" or machine == "amd64" then
        return "amd64"
    end

    return nil
end

--- Builds the deterministic container name.
---@param tool string Tool name.
---@param family string Compatibility family.
---@param name string Explicit name.
---@return string container Container name.
function M.container_name(tool, family, name)
    return "mise-db-" .. tool .. "-" .. M.version_tag(family) .. "-" .. name
end

--- Validates and resolves the globally configured runtime adapter.
---@return string adapter "apple" or "docker"
function M.resolve_adapter()
    local requested = os.getenv("MISE_DB_ADAPTER")

    if requested == nil or requested == "" then
        log.error("MISE_DB_ADAPTER is required; set it to 'apple' or 'docker' in your global mise configuration")
    end
    if requested ~= "apple" and requested ~= "docker" then
        log.error(
            "unsupported MISE_DB_ADAPTER '"
                .. requested
                .. "'; set it to 'apple' or 'docker' in your global mise configuration"
        )
    end

    log.debug("Checking configured " .. requested .. " adapter")
    local resolved = adapter_available(requested)
    if resolved == nil then
        log.error(
            "mise-db adapter "
                .. requested
                .. " is not available; verify its CLI is installed and its service is running"
        )
    end
    log.debug("Selected " .. resolved .. " adapter")
    return resolved
end

--- Resolves and validates the name option from the mise context.
---@param ctx table Mise backend hook context.
---@return string name Explicit name, defaulting to "global".
function M.resolve_name(ctx)
    if M.table_option(ctx, "isolated") ~= nil then
        log.error("the 'isolated' option is no longer supported; use the 'name' option instead")
    end
    if M.table_option(ctx, "namespace") ~= nil then
        log.error("the 'namespace' option is no longer supported; use the 'name' option instead")
    end

    local name = M.table_option(ctx, "name")
    if name == nil or name == "" then
        return "global"
    end
    if type(name) ~= "string" then
        log.error("name must be a string matching [a-z0-9]+(-[a-z0-9]+)*")
    end
    if
        name:match("^[a-z0-9-]+$") == nil
        or name:match("^-") ~= nil
        or name:match("-$") ~= nil
        or name:match("%-%-") ~= nil
    then
        log.error("invalid name '" .. name .. "'; expected [a-z0-9]+(-[a-z0-9]+)*")
    end

    return name
end

--- Quotes a value for use as one POSIX shell argument.
---@param value any Value to quote.
---@return string quoted Shell-quoted value.
function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Quotes multiple values for use as POSIX shell arguments.
---@param values any[] Values to quote.
---@return string quoted Shell-quoted values separated by spaces.
function M.shell_quotes(values)
    local quoted = {}
    for _, value in ipairs(values) do
        table.insert(quoted, M.shell_quote(value))
    end
    return table.concat(quoted, " ")
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

--- Loads the metadata module for a supported tool.
---@param tool string Tool name from mise.
---@return table tool_module Per-tool metadata and behavior.
function M.tool(tool)
    M.validate_tool(tool)
    return dofile(RUNTIME.pluginDirPath .. "/lib/" .. tool .. ".lua")
end

--- Ensures only implemented tools are accepted.
---@param tool string Tool name from mise.
---@return nil
function M.validate_tool(tool)
    for _, supported_tool in ipairs(M.supported_tools) do
        if tool == supported_tool then
            return
        end
    end

    log.error("unsupported tool '" .. tostring(tool) .. "'; supported tools: " .. table.concat(M.supported_tools, ", "))
end

--- Converts a version string into a Docker-name-safe tag segment.
---@param version string Version string.
---@return string tag Sanitized version tag.
function M.version_tag(version)
    return tostring(version or ""):gsub("[^A-Za-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
end

return M
