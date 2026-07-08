local M = {}

M.github_repository = "lcmen/mise-db"

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

-- Ensures only tools implemented by the current phase are accepted.
function M.validate_tool(tool)
    if tool ~= "postgres" then
        error("unsupported tool '" .. tostring(tool) .. "'; phase 1 supports only postgres")
    end
end

-- Quotes a value for use as one POSIX shell argument.
function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

return M
