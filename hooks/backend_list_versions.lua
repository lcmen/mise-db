local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendListVersions(ctx)
    local tool = utils.tool(ctx.tool)

    local semver = require("semver")
    return { versions = semver.sort(tool.list_versions()) }
end
