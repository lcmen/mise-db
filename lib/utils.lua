local M = {}

M.github_repository = "lcmen/binaries-db"

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
