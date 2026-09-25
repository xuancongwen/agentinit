### Elixir
- `mix format` and `mix credo --strict` clean; `@spec` on public functions, Dialyzer passes.
- Pattern match in function heads; `|>` pipelines for transformations; `with` for happy paths; tagged tuples `{:ok, _}`/`{:error, _}`.
- Let it crash: supervise processes instead of defensive `try/rescue`.
- Tests: ExUnit with `async: true` where safe.
