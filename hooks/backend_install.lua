local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

local function ensure_docker()
    local cmd = require("cmd")
    cmd.exec("command -v docker >/dev/null 2>&1 || { echo 'mise-db requires Docker for container-backed database wrappers.' >&2; exit 1; }")
    cmd.exec("docker info >/dev/null 2>&1 || { echo 'Docker is installed but the daemon is not available.' >&2; exit 1; }")
end

function PLUGIN:BackendInstall(ctx)
    local tool = common.tool(ctx.tool)

    local file = require("file")
    local cmd = require("cmd")
    local image = tool.docker_image(ctx.version)
    local isolated = common.boolean_option(ctx, "isolated", false)

    ensure_docker()

    cmd.exec("mkdir -p " .. common.shell_quote(ctx.install_path))
    cmd.exec("docker pull " .. common.shell_quote(image))

    local libexec = file.join_path(ctx.install_path, "libexec")
    local bin = file.join_path(ctx.install_path, "bin")
    local manifest = file.join_path(ctx.install_path, "manifest")
    local runtime_src = file.join_path(RUNTIME.pluginDirPath, "wrappers", tool.wrapper)
    local lib_src = file.join_path(RUNTIME.pluginDirPath, "wrappers", "lib")

    cmd.exec("mkdir -p " .. common.shell_quote(libexec) .. " " .. common.shell_quote(file.join_path(libexec, "lib")) .. " " .. common.shell_quote(bin))
    cmd.exec("cp " .. common.shell_quote(runtime_src) .. " " .. common.shell_quote(file.join_path(libexec, tool.wrapper)))
    cmd.exec("cp -R " .. common.shell_quote(lib_src) .. "/. " .. common.shell_quote(file.join_path(libexec, "lib")))
    cmd.exec("chmod -R u+rwX " .. common.shell_quote(ctx.install_path))
    cmd.exec("find " .. common.shell_quote(libexec) .. " -type f -exec chmod 755 {} +")

    local manifest_file = assert(io.open(manifest, "w"))
    manifest_file:write("TOOL=" .. ctx.tool .. "\n")
    manifest_file:write("VERSION=" .. ctx.version .. "\n")
    manifest_file:write("IMAGE=" .. image .. "\n")
    manifest_file:write("ISOLATED=" .. (isolated and "true" or "false") .. "\n")
    manifest_file:close()

    for _, command_name in ipairs(tool.commands) do
        local link = file.join_path(bin, command_name)
        cmd.exec("ln -sf " .. common.shell_quote(file.join_path(libexec, tool.wrapper)) .. " " .. common.shell_quote(link))
    end

    return {}
end
