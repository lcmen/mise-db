local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

--- Fetches all releases from the mise-db GitHub repository.
---@param repo string GitHub repository in owner/name form.
---@return table releases Decoded GitHub releases.
local function fetch_releases(repo)
    local http = require("http")
    local json = require("json")

    local resp, err = http.try_get({
        url = "https://api.github.com/repos/" .. repo .. "/releases?per_page=100",
        headers = common.github_headers(),
    })
    if err ~= nil then
        error("failed to fetch GitHub releases for " .. repo .. ": " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub releases request failed for " .. repo .. ": HTTP " .. tostring(resp.status_code))
    end

    local ok, releases = pcall(json.decode, resp.body)
    if not ok then
        error("failed to parse GitHub releases for " .. repo)
    end
    return releases
end

--- Lists concrete versions represented by local release archive filenames.
---@param directory string Local release asset directory.
---@param tool string Supported tool name.
---@return string[] versions Concrete versions found in the directory.
local function local_versions(directory, tool)
    local handle = io.popen(
        "if [ -d "
            .. common.shell_quote(directory)
            .. " ]; then ls -1 "
            .. common.shell_quote(directory)
            .. "; else exit 2; fi"
    )
    if handle == nil then
        error("failed to inspect local asset directory: " .. directory)
    end

    local versions = {}
    local seen = {}
    for filename in handle:lines() do
        local version = filename:match("^" .. tool .. "%-(%d+%.%d+%.%d+)%-[%w]+%-[%w]+%.tar%.xz$")
        if not version then
            version = filename:match("^" .. tool .. "%-(%d+%.%d+)%-[%w]+%-[%w]+%.tar%.xz$")
        end
        if version and not seen[version] then
            table.insert(versions, version)
            seen[version] = true
        end
    end

    local ok = handle:close()
    if not ok then
        error("local asset directory was not found: " .. directory)
    end

    return versions
end

--- Lists stable concrete versions for a supported tool.
---@param ctx table Mise backend hook context.
---@return table result Mise versions result.
function PLUGIN:BackendListVersions(ctx)
    common.validate_tool(ctx.tool)

    local semver = require("semver")
    local directory = common.local_asset_dir()
    if directory then
        return { versions = semver.sort(local_versions(directory, ctx.tool)) }
    end

    local versions = {}
    for _, release in ipairs(fetch_releases(common.github_repository)) do
        if not release.prerelease then
            local version = release.tag_name and release.tag_name:match("^" .. ctx.tool .. "%-(%d+%.%d+%.%d+)$")
            if not version then
                version = release.tag_name and release.tag_name:match("^" .. ctx.tool .. "%-(%d+%.%d+)$")
            end
            if version then
                table.insert(versions, version)
            end
        end
    end

    return { versions = semver.sort(versions) }
end
