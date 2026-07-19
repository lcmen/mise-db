local M = {}

--- Decodes the small JSON string escape subset used by Docker Hub tag fields.
---@param value string JSON string content without surrounding quotes.
---@return string value Decoded string.
local function json_string(value)
    value = value:gsub("\\/", "/")
    value = value:gsub('\\"', '"')
    value = value:gsub("\\\\", "\\")
    return value
end

--- Quotes a value for use as one POSIX shell argument.
---@param value any Value to quote.
---@return string quoted Shell-quoted value.
local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Fetches a URL using curl.
---@param url string URL to request.
---@return string body Response body.
local function fetch(url)
    local handle = io.popen("curl -fsSL --retry 2 " .. shell_quote(url) .. " 2>/dev/null")
    if not handle then
        error("failed to run curl while fetching registry tags")
    end

    local body = handle:read("*a")
    local ok = handle:close()
    if not ok then
        error("failed to fetch registry tags from " .. url)
    end

    return body
end

--- Extracts the next pagination URL from a Docker Hub tags response.
---@param body string Docker Hub tags response body.
---@return string|nil url Next page URL, or nil when there are no more pages.
local function next_url(body)
    local raw = body:match('"next"%s*:%s*"([^"]*)"')
    if raw == nil or raw == "" then
        return nil
    end
    return json_string(raw)
end

--- Lists all tag names for a Docker Hub repository.
---@param repository string Docker Hub repository path, such as "library/postgres".
---@return string[] tags Docker tag names.
function M.list_tags(repository)
    local tags = {}
    local url = "https://registry.hub.docker.com/v2/repositories/" .. repository .. "/tags?page_size=100"

    while url do
        local body = fetch(url)
        for name in body:gmatch('"name"%s*:%s*"([^"]+)"') do
            table.insert(tags, json_string(name))
        end
        url = next_url(body)
    end

    return tags
end

--- Lists versions by matching Docker Hub tags with a Lua pattern.
---@param repository string Docker Hub repository path, such as "library/postgres".
---@param tag_pattern string Lua pattern with the version as the first capture.
---@return string[] versions Version strings captured from matching tags.
function M.list_versions(repository, tag_pattern)
    local versions = {}

    for _, tag in ipairs(M.list_tags(repository)) do
        local version = tag:match(tag_pattern)
        if version then
            table.insert(versions, version)
        end
    end

    return versions
end

return M
