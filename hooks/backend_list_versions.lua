local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

local function fetch_releases(repo)
    local http = require("http")
    local json = require("json")

    local resp, err = http.try_get({
        url = "https://api.github.com/repos/" .. repo .. "/releases?per_page=100",
        headers = {
            ["Accept"] = "application/vnd.github+json",
            ["User-Agent"] = "binaries-db-mise-plugin"
        }
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

function PLUGIN:BackendListVersions(ctx)
    common.validate_tool(ctx.tool)

    local semver = require("semver")
    local versions = {}

    for _, release in ipairs(fetch_releases(common.github_repository)) do
        if not release.prerelease then
            local version = release.tag_name and release.tag_name:match("^postgres%-(18%.%d+)$")
            if version then
                table.insert(versions, version)
            end
        end
    end

    return {versions = semver.sort(versions)}
end
