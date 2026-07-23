local M = {}

local cache = dofile(RUNTIME.pluginDirPath .. "/lib/cache.lua")
local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")
local json = require("json")

--- Decodes a Docker Hub tags response.
---@param body string Response body.
---@param url string URL fetched.
---@return table response Decoded response body.
local function decode_tags_response(body, url)
    local ok, response = pcall(json.decode, body)
    if not ok or type(response) ~= "table" then
        error("failed to parse registry tags from " .. url)
    end

    return response
end

--- Fetches a URL using curl.
---@param url string URL to request.
---@return string body Response body.
local function fetch(url)
    url = utils.shell_quote(url)
    local handle = io.popen("curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 " .. url .. " 2>/dev/null")
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

--- Fetches all Docker Hub tag result objects.
---@param repository string Docker Hub repository path, such as "library/postgres".
---@param name_filter string|nil Optional Docker Hub tag-name filter.
---@return table[] results Docker Hub tag results.
local function fetch_tags(repository, name_filter)
    local results = {}
    local url = "https://registry.hub.docker.com/v2/repositories/" .. repository .. "/tags?page_size=100"
    local page = 1

    if name_filter ~= nil and name_filter ~= "" then
        local encoded_filter = tostring(name_filter):gsub("([^A-Za-z0-9_.~-])", function(char)
            return string.format("%%%02X", string.byte(char))
        end)
        url = url .. "&name=" .. encoded_filter
    end

    while url do
        io.stderr:write("mise-db: fetching tag page " .. tostring(page) .. "...\n")
        local body = fetch(url)
        local response = decode_tags_response(body, url)
        for _, tag in ipairs(response.results or {}) do
            if type(tag) == "table" then
                table.insert(results, tag)
            end
        end

        if type(response.next) == "string" and response.next ~= "" then
            url = response.next
        else
            url = nil
        end
        page = page + 1
    end

    return results
end

--- Extracts a supported version from a Docker Hub tag.
---@param tag table Docker Hub tag result.
---@param architecture string|nil OCI architecture. Nil disables architecture filtering.
---@param tag_pattern string Lua pattern with the version as the first capture.
---@param min_major number|nil Optional minimum major version.
---@return string|nil version Matching version, or nil when unsupported.
local function matching_version(tag, architecture, tag_pattern, min_major)
    if type(tag) ~= "table" or tag.name == nil then
        return nil
    end

    local has_platform = architecture == nil or architecture == ""
    for _, image in pairs(tag.images or {}) do
        if type(image) == "table" and image.os == "linux" and image.architecture == architecture then
            has_platform = true
            break
        end
    end
    if not has_platform then
        return nil
    end

    local version = tag.name:match(tag_pattern)
    if version == nil then
        return nil
    end

    local major = tonumber(version:match("^(%d+)"))
    if min_major ~= nil and (major == nil or major < min_major) then
        return nil
    end

    return version
end

--- Lists versions by matching Docker Hub tags with a Lua pattern.
---@param repository string Docker Hub repository path, such as "library/postgres".
---@param tag_pattern string Lua pattern with the version as the first capture.
---@param name_filter string|nil Optional Docker Hub tag-name filter.
---@param min_major number|nil Optional minimum major version.
---@param cache_name string|nil Cache file name.
---@return string[] versions Version strings captured from matching tags.
function M.list_versions(repository, tag_pattern, name_filter, min_major, cache_name)
    local architecture = utils.arch()
    local versions = {}

    for _, tag in ipairs(M.remote_tags(repository, name_filter, cache_name)) do
        local version = matching_version(tag, architecture, tag_pattern, min_major)
        if version ~= nil then
            table.insert(versions, version)
        end
    end

    return versions
end

--- Lists all Docker Hub tag result objects, using cache when configured.
---@param repository string Docker Hub repository path, such as "library/postgres".
---@param name_filter string|nil Optional Docker Hub tag-name filter.
---@param cache_name string|nil Cache file name.
---@return table[] results Docker Hub tag results.
function M.remote_tags(repository, name_filter, cache_name)
    local function fetch_results()
        return fetch_tags(repository, name_filter)
    end

    if cache_name == nil or cache_name == "" then
        return fetch_results()
    else
        return cache.caching(cache_name, fetch_results)
    end
end

return M
