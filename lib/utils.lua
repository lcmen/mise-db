local M = {}

--- Tool names implemented by this plugin.
---@type string[]
M.supported_tools = { "postgres" }

local function adapter_available(adapter)
    if adapter == "apple" then
        return "command -v container >/dev/null 2>&1 && container system status >/dev/null 2>&1"
    end

    return "command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1"
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

--- Computes a small deterministic checksum for a string.
---@param value string Input string.
---@return number checksum Decimal checksum in the range 0..65535.
function M.byte_sum(value)
    local sum = 0
    for i = 1, #value do
        sum = (sum + string.byte(value, i)) % 65536
    end
    return sum
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

    error("unsupported tool '" .. tostring(tool) .. "'; supported tools: " .. table.concat(M.supported_tools, ", "))
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

--- Builds the deterministic Docker container name.
---@param tool string Tool name.
---@param version string Tool version.
---@param isolated boolean Whether project isolation is enabled.
---@return string container Container name.
function M.container_name(tool, version, isolated)
    return "mise-db-" .. tool .. "-" .. M.version_tag(version) .. "-" .. M.instance_name(isolated)
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

--- Resolves the runtime adapter for an installation.
---@return string adapter "apple" or "docker"
function M.resolve_adapter()
    local cmd = require("cmd")
    local requested = os.getenv("MISE_DB_ADAPTER")

    if requested ~= nil and requested ~= "" then
        if requested ~= "apple" and requested ~= "docker" then
            error("invalid MISE_DB_ADAPTER '" .. requested .. "'; expected docker or apple")
        end

        cmd.exec(adapter_available(requested) .. " || { echo 'mise-db adapter " .. requested .. " is not available.' >&2; exit 1; }")
        return requested
    end

    return cmd.exec("if " .. adapter_available("apple") .. "; then printf apple; "
        .. "elif " .. adapter_available("docker") .. "; then printf docker; "
        .. "else echo 'mise-db requires a running Apple Container service or Docker daemon.' >&2; exit 1; fi")
end

--- Builds the instance identity for global or isolated mode.
---@param isolated boolean Whether project isolation is enabled.
---@return string instance "global" or "<project-slug>-<path-checksum>".
function M.instance_name(isolated)
    if isolated then
        local root = M.project_root()
        local slug = M.sanitize(M.basename(root))
        return string.format("%s-%04x", slug, M.byte_sum(root))
    end

    return "global"
end

--- Returns the final path segment.
---@param path string Path.
---@return string name Base name.
function M.basename(path)
    local value = tostring(path):gsub("/+$", "")
    return value:match("([^/]+)$") or value
end

--- Finds the current project root used for isolated identities.
---@return string root Project root.
function M.project_root()
    local env_root = os.getenv("MISE_PROJECT_ROOT")
    if env_root ~= nil and env_root ~= "" then
        return env_root
    end

    local cmd = require("cmd")
    local root = cmd.exec("command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel 2>/dev/null || pwd -P")
    return tostring(root):gsub("%s+$", "")
end

--- Converts arbitrary text into a lowercase slug.
---@param value string Input string.
---@return string slug Slug containing only lowercase letters, digits, and hyphens.
function M.sanitize(value)
    local slug = tostring(value or "project"):lower()
    slug = slug:gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if slug == "" then
        return "project"
    end
    return slug
end

--- Loads the metadata module for a supported tool.
---@param tool string Tool name from mise.
---@return table tool_module Per-tool metadata and behavior.
function M.tool(tool)
    M.validate_tool(tool)
    return dofile(RUNTIME.pluginDirPath .. "/lib/" .. tool .. ".lua")
end

--- Converts a version string into a Docker-name-safe tag segment.
---@param version string Version string.
---@return string tag Sanitized version tag.
function M.version_tag(version)
    return tostring(version or ""):gsub("[^A-Za-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
end

return M
