local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

--- Builds the archive name used by GitHub Releases and local asset installs.
---@param tool string Supported tool name.
---@param version string Concrete tool version.
---@param install_target string Target platform identifier.
---@return string name Release archive filename.
local function asset_name(tool, version, install_target)
    return tool .. "-" .. version .. "-" .. install_target .. ".tar.xz"
end

--- Fetches the GitHub release for a tool and version.
---@param repo string GitHub repository in owner/name form.
---@param tool string Supported tool name.
---@param version string Concrete tool version.
---@return table release Decoded GitHub release.
local function fetch_release(repo, tool, version)
    local http = require("http")
    local json = require("json")
    local tag = tool .. "-" .. version

    local resp, err = http.try_get({
        url = "https://api.github.com/repos/" .. repo .. "/releases/tags/" .. tag,
        headers = common.github_headers(),
    })
    if err ~= nil then
        error("failed to fetch GitHub release " .. tag .. " from " .. repo .. ": " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub release request failed for " .. repo .. "@" .. tag .. ": HTTP " .. tostring(resp.status_code))
    end

    local ok, release = pcall(json.decode, resp.body)
    if not ok then
        error("failed to parse GitHub release " .. tag .. " from " .. repo)
    end

    return release
end

--- Finds the download URL for a target archive in a GitHub release.
---@param repo string GitHub repository in owner/name form.
---@param tool string Supported tool name.
---@param version string Concrete tool version.
---@param install_target string Target platform identifier.
---@return string url GitHub API asset URL.
local function asset_api_url(repo, tool, version, install_target)
    local name = asset_name(tool, version, install_target)
    local release = fetch_release(repo, tool, version)

    for _, asset in ipairs(release.assets or {}) do
        if asset.name == name then
            return asset.url
        end
    end

    error("release asset not found: " .. name)
end

--- Reads distribution metadata from the Linux host.
---@return table values Parsed /etc/os-release key/value pairs.
local function linux_distro()
    local values = {}
    local handle = io.open("/etc/os-release", "r")
    if handle == nil then
        error("unsupported Linux distribution: /etc/os-release was not found")
    end

    for line in handle:lines() do
        local key, value = line:match("^([A-Z0-9_]+)=(.*)$")
        if key and value then
            value = value:gsub('^"', ""):gsub('"$', "")
            values[key] = value
        end
    end
    handle:close()

    return values
end

--- Builds the release target identifier for a Linux architecture.
---@param arch_type string Architecture identifier supplied by mise.
---@return string target Linux distribution and architecture target.
local function linux_target(arch_type)
    local distro = linux_distro()
    local id = distro.ID or ""
    local version_id = (distro.VERSION_ID or ""):match("^[^.]+") or ""

    return id .. version_id .. "-" .. arch_type
end

--- Maps the current operating system and architecture to a release target.
---@return string target Release target identifier.
local function target()
    local os_type = RUNTIME and RUNTIME.osType
    local arch_type = RUNTIME and RUNTIME.archType

    if os_type == "darwin" then
        if arch_type == "amd64" then
            return "darwin-amd64"
        end
        if arch_type == "arm64" then
            return "darwin-arm64"
        end
        error("unsupported macOS architecture: " .. tostring(arch_type) .. ".")
    end

    if os_type == "linux" then
        return linux_target(arch_type)
    end

    error("unsupported platform: " .. tostring(os_type) .. ".")
end

--- Downloads or locates an archive and extracts it into the mise install path.
---@param ctx table Mise backend hook context.
---@return table result Empty mise backend install result.
function PLUGIN:BackendInstall(ctx)
    common.validate_tool(ctx.tool)

    local file = require("file")
    local archiver = require("archiver")
    local cmd = require("cmd")

    local install_target = target()
    local archive = asset_name(ctx.tool, ctx.version, install_target)
    local directory = common.local_asset_dir()
    local archive_path

    cmd.exec("mkdir -p " .. common.shell_quote(ctx.download_path) .. " " .. common.shell_quote(ctx.install_path))

    if directory then
        archive_path = file.join_path(directory, archive)
        local handle = io.open(archive_path, "rb")
        if handle == nil then
            error("local release asset not found: " .. archive_path)
        end
        handle:close()
    else
        local http = require("http")
        local url = asset_api_url(common.github_repository, ctx.tool, ctx.version, install_target)
        archive_path = file.join_path(ctx.download_path, archive)

        local ok, err = http.try_download_file({
            url = url,
            headers = common.github_headers("application/octet-stream"),
        }, archive_path)
        if err ~= nil then
            error("failed to download " .. url .. ": " .. err)
        end
        if not ok then
            error("failed to download " .. url)
        end
    end

    local decompress_err = archiver.decompress(archive_path, ctx.install_path)
    if decompress_err ~= nil then
        error("failed to extract " .. archive_path .. ": " .. decompress_err)
    end

    cmd.exec("chmod -R u+rwX " .. common.shell_quote(ctx.install_path))
    cmd.exec("find " .. common.shell_quote(file.join_path(ctx.install_path, "bin")) .. " -type f -exec chmod 755 {} +")

    return {}
end
