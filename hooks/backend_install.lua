local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

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

    cmd.exec("mkdir -p " .. utils.shell_quote(bin_dir))
    cmd.exec("cp -R " .. utils.shell_quotes({ lib_src_dir, ctx.install_path }))
    cmd.exec("cp " .. utils.shell_quotes({ wrapper_src_file, wrapper_dest_file }))
    cmd.exec("chmod -R u+rwX " .. utils.shell_quote(ctx.install_path))
    cmd.exec("find " .. utils.shell_quote(lib_dest_dir) .. " -type f -exec chmod 755 {} +")

    for _, bin in ipairs(tool.bins) do
        local cmd_file = file.join_path(bin_dir, bin)
        cmd.exec("ln -sf " .. utils.shell_quotes({ wrapper_dest_file, cmd_file }))
    end
end

--- Pulls the selected OCI image with the adapter chosen for this installation.
---@param image string OCI image reference to pull.
---@param resolved_adapter string Runtime adapter, either "apple" or "docker".
---@return nil
local function pull_image(image, resolved_adapter)
    local pull_command

    cmd.exec(
        "printf '%s\n' "
            .. utils.shell_quote("mise-db: pulling " .. image .. " with " .. resolved_adapter .. "...")
            .. " >&2"
    )

    if resolved_adapter == "apple" then
        pull_command = "container image pull " .. utils.shell_quote(image)
    else
        pull_command = "docker pull " .. utils.shell_quote(image)
    end

    cmd.exec(pull_command .. " >&2")
    cmd.exec("printf '%s\n' " .. utils.shell_quote("mise-db: pulled " .. image) .. " >&2")
end

--- Writes the wrapper manifest consumed by installed command symlinks.
---@param ctx table Mise backend hook context.
---@param image string OCI image reference persisted for wrapper execution.
---@param isolated boolean Whether this install uses project-isolated instances.
---@param resolved_adapter string Runtime adapter persisted for wrapper execution.
---@return nil
local function write_manifest(ctx, image, isolated, resolved_adapter)
    local manifest = file.join_path(ctx.install_path, "manifest")
    local manifest_file = assert(io.open(manifest, "w"))
    manifest_file:write("TOOL=" .. ctx.tool .. "\n")
    manifest_file:write("VERSION=" .. ctx.version .. "\n")
    manifest_file:write("IMAGE=" .. image .. "\n")
    manifest_file:write("ISOLATED=" .. (isolated and "true" or "false") .. "\n")
    manifest_file:write("ADAPTER=" .. resolved_adapter .. "\n")
    manifest_file:close()
end

function PLUGIN:BackendInstall(ctx)
    local tool = utils.tool(ctx.tool)
    local image = tool.docker_image(ctx.version)
    local isolated = utils.boolean_option(ctx, "isolated", false)
    local resolved_adapter = utils.resolve_adapter()

    cmd.exec("mkdir -p " .. utils.shell_quote(ctx.install_path))
    pull_image(image, resolved_adapter)

    install_wrapper(ctx, tool)
    write_manifest(ctx, image, isolated, resolved_adapter)

    return {}
end
