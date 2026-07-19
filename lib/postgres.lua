local M = {}

--- Commands installed for each PostgreSQL version.
---@type string[]
M.commands = {
    "postgres",
    "pg_ctl",
    "psql",
    "pg_dump",
    "pg_restore",
    "createdb",
    "dropdb",
    "createuser",
    "dropuser",
}

--- Wrapper executable copied into the install libexec directory.
---@type string
M.wrapper = "postgres"

--- Docker Hub repository for the official PostgreSQL image.
M.image_repository = "library/postgres"

--- Image tag suffix used by installed PostgreSQL wrappers.
M.image_tag_suffix = "-alpine"

--- Pattern that maps supported Docker tags to mise versions.
M.version_tag_pattern = "^(%d+%.%d+)%-alpine$"

--- Builds the Docker image reference for a PostgreSQL version.
---@param version string PostgreSQL version selected by mise.
---@return string image Docker image reference.
function M.docker_image(version)
    return "postgres:" .. version .. M.image_tag_suffix
end

--- Returns PostgreSQL-specific environment variables for activation.
---@return table[] env_vars List of mise env var entries.
function M.exec_env()
    return {
        { key = "PGUSER", value = "postgres" },
        { key = "PGPASS", value = "postgres" },
    }
end

--- Lists supported PostgreSQL versions from the configured registry source.
---@return string[] versions PostgreSQL versions available to mise.
function M.list_versions()
    local registry = dofile(RUNTIME.pluginDirPath .. "/lib/registry.lua")
    return registry.list_versions(M.image_repository, M.version_tag_pattern)
end

return M
