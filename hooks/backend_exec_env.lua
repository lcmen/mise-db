local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendExecEnv(ctx)
    local tool = utils.tool(ctx.tool)
    local name = utils.resolve_name(ctx)

    local file = require("file")
    local env_vars = {
        { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
    }

    for _, env_var in ipairs(tool.exec_env(ctx, name)) do
        table.insert(env_vars, env_var)
    end

    return {
        env_vars = env_vars,
    }
end
