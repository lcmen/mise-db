local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

--- Adds the installed binary directory to the mise execution environment.
---@param ctx table Mise backend hook context.
---@return table environment Environment variables for the installed tool.
function PLUGIN:BackendExecEnv(ctx)
    common.validate_tool(ctx.tool)

    local file = require("file")
    return {
        env_vars = {
            { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
        },
    }
end
