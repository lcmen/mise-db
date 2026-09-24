local M = {}

local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

M.bins = {
    "redis-cli",
    "redis-server",
}
M.image_repository = "library/redis"
M.image_tag_suffix = "-alpine"
M.image_tag_name_filter = "alpine"
M.minimum_major_version = 6
M.registry_cache_name = "redis.json"
M.wrapper = "redis"
M.version_tag_pattern = "^(%d+%.%d+%.?%d*)%-alpine$"

--- Builds the Docker image reference for a Redis version.
---@param version string Redis version selected by mise.
---@return string image Docker image reference.
function M.docker_image(version)
    return "redis:" .. version .. M.image_tag_suffix
end

--- Derives the Redis data compatibility family from a concrete release.
---@param version string Validated concrete Redis release.
---@return string family Redis major-minor release line.
function M.version_family(version)
    return version:match("^(%d+%.%d+)")
end

--- Returns Redis-specific environment variables for activation.
---@param ctx table Mise backend hook context.
---@param name string Explicit name.
---@return table[] env_vars List of mise env var entries.
function M.exec_env(ctx, name)
    local family = M.version_family(ctx.version)
    local env_vars = {
        { key = "_MISE_DB_REDIS_FAMILY", value = family },
        { key = "_MISE_DB_REDIS_IMAGE", value = M.docker_image(ctx.version) },
        { key = "_MISE_DB_REDIS_NAME", value = name },
        { key = "_MISE_DB_REDIS_VERSION", value = ctx.version },
    }
    local domain = os.getenv("MISE_DB_DOMAIN")
    if domain == nil or domain == "" then
        return env_vars
    end

    local container = utils.container_name("redis", family, name)
    table.insert(env_vars, { key = "REDIS_URL", value = "redis://" .. container .. "." .. domain .. ":6379" })
    return env_vars
end

--- Lists supported Redis versions from the configured registry source.
---@return string[] versions Redis versions available to mise.
function M.list_versions()
    local registry = dofile(RUNTIME.pluginDirPath .. "/lib/registry.lua")
    return registry.list_versions(
        M.image_repository,
        M.version_tag_pattern,
        M.image_tag_name_filter,
        M.minimum_major_version,
        M.registry_cache_name
    )
end

return M
