local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")
local log = dofile(RUNTIME.pluginDirPath .. "/lib/log.lua")

local cmd = require("cmd")
local file = require("file")

--- Copies wrapper support files into the mise install path and creates command symlinks.
---@param ctx table Mise backend hook context.
---@param tool table Tool metadata, including wrapper and bin names.
---@return nil
local function install_wrapper(ctx, tool)
    local bin_dir = file.join_path(ctx.install_path, "bin")
    local lib_dest_dir = file.join_path(ctx.install_path, "lib")
    local lib_src_dir = file.join_path(RUNTIME.pluginDirPath, "wrappers", "lib")
    local wrapper_dest_file = file.join_path(lib_dest_dir, tool.wrapper)
    local wrapper_src_file = file.join_path(RUNTIME.pluginDirPath, "wrappers", tool.wrapper)

    log.debug("Installing wrapper files into " .. ctx.install_path)
    cmd.exec("mkdir -p " .. utils.shell_quote(bin_dir))
    cmd.exec("cp -R " .. utils.shell_quotes({ lib_src_dir, ctx.install_path }))
    cmd.exec("cp " .. utils.shell_quotes({ wrapper_src_file, wrapper_dest_file }))
    cmd.exec("chmod -R u+rwX " .. utils.shell_quote(ctx.install_path))
    cmd.exec("find " .. utils.shell_quote(lib_dest_dir) .. " -type f -exec chmod 755 {} +")

    for _, bin in ipairs(tool.bins) do
        local cmd_file = file.join_path(bin_dir, bin)
        cmd.exec("ln -sf " .. utils.shell_quotes({ wrapper_dest_file, cmd_file }))
    end
    log.debug("Installed " .. tostring(#tool.bins) .. " command wrappers")
end

--- Pulls the selected OCI image with the globally configured adapter.
---@param image string OCI image reference to pull.
---@param resolved_adapter string Runtime adapter, either "apple" or "docker".
---@return nil
local function pull_image(image, resolved_adapter)
    local pull_command

    log.info("Pulling " .. image .. " with " .. resolved_adapter)

    if resolved_adapter == "apple" then
        pull_command = "container image pull " .. utils.shell_quote(image)
    else
        pull_command = "docker pull " .. utils.shell_quote(image)
    end

    cmd.exec(pull_command .. " >&2")
    log.info("Pulled " .. image)
end

function PLUGIN:BackendInstall(ctx)
    local tool = utils.tool(ctx.tool)
    local image = tool.docker_image(ctx.version)
    local resolved_adapter = utils.resolve_adapter()

    log.debug("Installing " .. ctx.tool .. " " .. ctx.version .. " from " .. image)
    cmd.exec("mkdir -p " .. utils.shell_quote(ctx.install_path))
    pull_image(image, resolved_adapter)

    install_wrapper(ctx, tool)

    return {}
end
