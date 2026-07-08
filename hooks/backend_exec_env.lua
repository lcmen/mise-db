local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendExecEnv(ctx)
    common.validate_tool(ctx.tool)

    local file = require("file")
    return {
        env_vars = {
            {key = "PATH", value = file.join_path(ctx.install_path, "bin")},
        }
    }
end
