local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendListVersions(ctx)
    local tool = common.tool(ctx.tool)

    local semver = require("semver")
    return {versions = semver.sort(tool.list_versions())}
end
