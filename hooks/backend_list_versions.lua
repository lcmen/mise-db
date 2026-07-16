local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

function PLUGIN:BackendListVersions(ctx)
    common.validate_tool(ctx.tool)

    local semver = require("semver")
    return {versions = semver.sort(common.postgres_versions)}
end
