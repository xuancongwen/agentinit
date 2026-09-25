### SQL
- Uppercase keywords, `snake_case` identifiers, one clause per line; explicit column lists, never `SELECT *` in code.
- Migrations are forward-only and never edited after merge; make them idempotent where possible.
- Index what you filter and join on; `EXPLAIN` new queries against large tables.
- Parameterized queries only; never interpolate input.
