local M = {}

M.github_repository = "lcmen/mise-db"
M.supported_tools = {"postgres", "valkey"}

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

return M
