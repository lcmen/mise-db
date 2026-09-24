local M = {}

local utils = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

M.bins = {
    "createdb",
    "createuser",
    "dropdb",
    "dropuser",
    "pg_ctl",
    "pg_dump",
    "pg_restore",
    "postgres",
    "psql",
}
M.image_repository = "library/postgres"
M.image_tag_suffix = "-alpine"
M.image_tag_name_filter = "alpine"
M.minimum_major_version = 12
M.registry_cache_name = "postgres.json"
M.wrapper = "postgres"
M.version_tag_pattern = "^(%d+%.%d+)%-alpine$"

--- Builds the Docker image reference for a PostgreSQL version.
---@param version string PostgreSQL version selected by mise.
---@return string image Docker image reference.
function M.docker_image(version)
    return "postgres:" .. version .. M.image_tag_suffix
end

--- Derives the PostgreSQL data compatibility family from a concrete release.
---@param version string Validated concrete PostgreSQL release.
---@return string family PostgreSQL major version.
function M.version_family(version)
    return version:match("^(%d+)")
end

--- Returns PostgreSQL-specific environment variables for activation.
---@param ctx table Mise backend hook context.
---@param name string Explicit name.
---@return table[] env_vars List of mise env var entries.
function M.exec_env(ctx, name)
    local family = M.version_family(ctx.version)
    local container = utils.container_name("postgres", family, name)
    local env_vars = {
        { key = "_MISE_DB_POSTGRES_FAMILY", value = family },
        { key = "_MISE_DB_POSTGRES_IMAGE", value = M.docker_image(ctx.version) },
        { key = "_MISE_DB_POSTGRES_NAME", value = name },
        { key = "_MISE_DB_POSTGRES_VERSION", value = ctx.version },
        { key = "PGPASS", value = "postgres" },
        { key = "PGUSER", value = "postgres" },
    }

    local domain = os.getenv("MISE_DB_DOMAIN")
    if domain ~= nil and domain ~= "" then
        local host = container .. "." .. domain
        table.insert(env_vars, { key = "PGHOST", value = host })
    end

    return env_vars
end

--- Lists supported PostgreSQL versions from the configured registry source.
---@return string[] versions PostgreSQL versions available to mise.
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
