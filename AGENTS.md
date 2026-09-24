# mise-db contributor guide

mise-db is a [mise](https://mise.jdx.dev/) backend plugin. It installs versioned database command wrappers backed by OCI images.

PostgreSQL and Redis are implemented services. MySQL is planned.

Start with the document that matches your work:

- [Architecture](docs/architecture.md): how the plugin, wrappers, and container runtimes fit together.
- [Development](docs/development.md): how to set up the project, make changes, and add a service.
- [Code conventions](docs/conventions.md): Lua and Bash style used in this repository.
- [Testing](docs/testing.md): how to run and write tests.
- [PostgreSQL](docs/services/postgresql.md): PostgreSQL-specific behavior.
- [Redis](docs/services/redis.md): Redis-specific behavior.

Keep these project rules:

- mise-db installs OCI-backed wrappers. Do not add native database build or release work unless the project direction changes.
- Pull images during installation, not during normal wrapper execution.
- Do not delete persistent database data during stop or uninstall.
- Copy wrappers into the mise install. Do not link installed commands back to this checkout.
- Public service names are `postgres`, `redis`, and `mysql`.

Before submitting a change, run:

```bash
mise run check
```

Run the relevant smoke tests when the change affects runtime behavior. See [Testing](docs/testing.md) for requirements and commands.
