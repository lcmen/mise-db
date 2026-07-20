local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

local cmd = require("cmd")
local file = require("file")

local function ensure_docker()
    cmd.exec(
        "command -v docker >/dev/null 2>&1 || { echo 'mise-db requires Docker for container-backed database wrappers.' >&2; exit 1; }")
    cmd.exec(
        "docker info >/dev/null 2>&1 || { echo 'Docker is installed but the daemon is not available.' >&2; exit 1; }")
end

local function install_wrapper(ctx, tool)
    local bin_path = file.join_path(ctx.install_path, "bin")
    local libexec_path = file.join_path(ctx.install_path, "libexec")
    local install_dirs = {
        bin_path,
        libexec_path,
    }
    local installed_wrapper = file.join_path(libexec_path, tool.wrapper)
    local wrapper_path = file.join_path(RUNTIME.pluginDirPath, "wrappers", tool.wrapper)
    local wrapper_lib_path = file.join_path(RUNTIME.pluginDirPath, "wrappers", "lib")

    cmd.exec("mkdir -p " .. utils.shell_quotes(install_dirs))
    cmd.exec("cp " .. utils.shell_quote(wrapper_path) .. " " .. utils.shell_quote(installed_wrapper))
    cmd.exec("cp -R " ..
        utils.shell_quote(wrapper_lib_path) .. "/. " .. utils.shell_quote(file.join_path(libexec_path, "lib")))
    cmd.exec("chmod -R u+rwX " .. utils.shell_quote(ctx.install_path))
    cmd.exec("find " .. utils.shell_quote(libexec_path) .. " -type f -exec chmod 755 {} +")

    for _, bin in ipairs(tool.bins) do
        local link = file.join_path(bin_path, bin)
        cmd.exec("ln -sf " .. utils.shell_quote(installed_wrapper) .. " " .. utils.shell_quote(link))
    end
end

local function write_manifest(ctx, image, isolated)
    local manifest = file.join_path(ctx.install_path, "manifest")
    local manifest_file = assert(io.open(manifest, "w"))
    manifest_file:write("TOOL=" .. ctx.tool .. "\n")
    manifest_file:write("VERSION=" .. ctx.version .. "\n")
    manifest_file:write("IMAGE=" .. image .. "\n")
    manifest_file:write("ISOLATED=" .. (isolated and "true" or "false") .. "\n")
    manifest_file:close()
end

function PLUGIN:BackendInstall(ctx)
    local tool = utils.tool(ctx.tool)
    local image = tool.docker_image(ctx.version)
    local isolated = utils.boolean_option(ctx, "isolated", false)

    ensure_docker()

    cmd.exec("mkdir -p " .. utils.shell_quote(ctx.install_path))
    cmd.exec("docker pull " .. utils.shell_quote(image))

    install_wrapper(ctx, tool)
    write_manifest(ctx, image, isolated)

    return {}
end
