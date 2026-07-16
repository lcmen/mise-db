local M = {}

M.github_repository = "lcmen/mise-db"
M.supported_tools = {"postgres"}
M.postgres_versions = {"16.14", "17.10", "18.4"}

-- Builds GitHub request headers, adding auth when a token is available.
function M.github_headers(accept)
    local token = os.getenv("GH_TOKEN")

    local headers = {
        ["Accept"] = accept or "application/vnd.github+json",
        ["User-Agent"] = "db-mise-plugin"
    }

    if token and token ~= "" then
        headers["Authorization"] = "Bearer " .. token
    end

    return headers
end

-- Ensures only implemented tools are accepted.
function M.validate_tool(tool)
    for _, supported_tool in ipairs(M.supported_tools) do
        if tool == supported_tool then
            return
        end
    end

    error("unsupported tool '" .. tostring(tool) .. "'; supported tools: " .. table.concat(M.supported_tools, ", "))
end

-- Quotes a value for use as one POSIX shell argument.
function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

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

function M.sanitize(value)
    local sanitized = tostring(value):lower():gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if sanitized == "" then
        return "project"
    end
    return sanitized
end

function M.byte_sum(value)
    local sum = 0
    value = tostring(value)
    for index = 1, #value do
        sum = (sum + value:byte(index)) % 65536
    end
    return sum
end

function M.project_root(ctx)
    return ctx.project_root or ctx.project_path or os.getenv("MISE_PROJECT_ROOT") or os.getenv("PWD") or "."
end

function M.postgres_context(ctx)
    local isolated = M.boolean_option(ctx, "isolated", false)
    local version_token = tostring(ctx.version):gsub("[^A-Za-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    local instance = "global"

    if isolated then
        local root = M.project_root(ctx)
        local slug = M.sanitize(root:match("([^/]+)$") or root)
        instance = slug .. "-" .. string.format("%04x", M.byte_sum(root))
    end

    return {
        isolated = isolated,
        instance = instance,
        container = "mise-db-postgres-" .. version_token .. "-" .. instance,
    }
end

return M
