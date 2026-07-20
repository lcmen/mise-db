local M = {}

local common = dofile(RUNTIME.pluginDirPath .. "/lib/utils.lua")

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
---@param ctx table Mise backend hook context.
---@return table[] env_vars List of mise env var entries.
function M.exec_env(ctx)
  local isolated = common.boolean_option(ctx, "isolated", false)
  local container = common.container_name("postgres", ctx.version, isolated)
  local env_vars = {
    { key = "PGUSER",     value = "postgres" },
    { key = "PGPASSWORD", value = "postgres" },
  }

  local container_tld = os.getenv("MISE_DB_CONTAINER_TLD")
  if container_tld ~= nil and container_tld ~= "" then
    local host = container .. "." .. container_tld
    table.insert(env_vars, { key = "PGHOST", value = host })
  end

  return env_vars
end

--- Lists supported PostgreSQL versions from the configured registry source.
---@return string[] versions PostgreSQL versions available to mise.
function M.list_versions()
  local registry = dofile(RUNTIME.pluginDirPath .. "/lib/registry.lua")
  return registry.list_versions(M.image_repository, M.version_tag_pattern)
end

return M
