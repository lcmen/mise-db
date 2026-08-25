local M = {}

M.github_repository = "lcmen/mise-db"
M.supported_tools = { "postgres", "mysql", "valkey" }

--- Builds GitHub request headers, adding auth when a token is available.
---@param accept string|nil Optional value for the Accept header.
---@return table headers GitHub request headers.
function M.github_headers(accept)
    local token = os.getenv("GH_TOKEN")

    local headers = {
        ["Accept"] = accept or "application/vnd.github+json",
        ["User-Agent"] = "db-mise-plugin",
    }

    if token and token ~= "" then
        headers["Authorization"] = "Bearer " .. token
    end

    return headers
end

--- Returns the optional directory containing local release assets.
---@return string|nil directory Local asset directory, or nil when unset.
function M.local_asset_dir()
    local directory = os.getenv("MISE_DB_ASSET_DIR")
    if directory == nil or directory == "" then
        return nil
    end

    return directory
end

--- Quotes a value for use as one POSIX shell argument.
---@param value any Value to quote.
---@return string quoted Shell argument.
function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
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

return M
