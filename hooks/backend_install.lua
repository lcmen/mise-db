local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

local function target()
    local os_type = RUNTIME and RUNTIME.osType
    local arch_type = RUNTIME and RUNTIME.archType
    local env_type = RUNTIME and RUNTIME.envType

    if os_type == "darwin" then
        if arch_type == "amd64" then
            return "darwin-amd64"
        end
        if arch_type == "arm64" then
            return "darwin-arm64"
        end
        error("unsupported macOS architecture: " .. tostring(arch_type) .. "; supported: amd64, arm64")
    end

    if os_type == "linux" then
        if env_type ~= "gnu" then
            error("unsupported Linux libc: " .. tostring(env_type) .. "; Linux builds require glibc and are built and verified on Ubuntu")
        end
        if arch_type == "amd64" then
            return "linux-amd64"
        end
        if arch_type == "arm64" then
            return "linux-arm64"
        end
        error("unsupported Linux architecture: " .. tostring(arch_type) .. "; supported: amd64, arm64")
    end

    error("unsupported platform: " .. tostring(os_type) .. "; supported: glibc Linux built and verified on Ubuntu, and macOS")
end

local function asset_name(tool, version, install_target)
    return "db-" .. tool .. "-" .. version .. "-" .. install_target .. ".tar.xz"
end

local function fetch_release(repo, tool, version)
    local http = require("http")
    local json = require("json")
    local tag = tool .. "-" .. version

    local resp, err = http.try_get({
        url = "https://api.github.com/repos/" .. repo .. "/releases/tags/" .. tag,
        headers = common.github_headers()
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

function PLUGIN:BackendInstall(ctx)
    common.validate_tool(ctx.tool)

    local file = require("file")
    local http = require("http")
    local archiver = require("archiver")
    local cmd = require("cmd")

    local install_target = target()
    local archive = asset_name(ctx.tool, ctx.version, install_target)
    local archive_path = file.join_path(ctx.download_path, archive)
    local url = asset_api_url(common.github_repository, ctx.tool, ctx.version, install_target)

    cmd.exec("mkdir -p " .. common.shell_quote(ctx.download_path) .. " " .. common.shell_quote(ctx.install_path))

    local ok, err = http.try_download_file({
        url = url,
        headers = common.github_headers("application/octet-stream")
    }, archive_path)
    if err ~= nil then
        error("failed to download " .. url .. ": " .. err)
    end
    if not ok then
        error("failed to download " .. url)
    end

    local decompress_err = archiver.decompress(archive_path, ctx.install_path)
    if decompress_err ~= nil then
        error("failed to extract " .. archive_path .. ": " .. decompress_err)
    end

    cmd.exec("chmod -R u+rwX " .. common.shell_quote(ctx.install_path))
    cmd.exec("find " .. common.shell_quote(file.join_path(ctx.install_path, "bin")) .. " -type f -exec chmod 755 {} +")

    return {}
end
