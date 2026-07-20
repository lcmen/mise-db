local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendExecEnv(ctx)
    local tool = common.tool(ctx.tool)

    local file = require("file")
    local env_vars = {
        { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
    }

    for _, env_var in ipairs(tool.exec_env(ctx)) do
        table.insert(env_vars, env_var)
    end

    return {
        env_vars = env_vars
    }
end
