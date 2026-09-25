### SQL
- Uppercase keywords, `snake_case` identifiers, one clause per line, explicit column lists.
- Migrations are forward-only, never edited after merge, idempotent where possible.
- Index what you filter and join on; `EXPLAIN` new queries on large tables.
- Parameterized queries only.
