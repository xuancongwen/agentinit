### Elixir
- `mix format` and `mix credo --strict` clean; `@spec` on public functions; Dialyzer passes.
- Pattern match in function heads; `|>` pipelines; `with` for happy paths; `{:ok, _}`/`{:error, _}`.
- Let it crash: supervise instead of defensive `try/rescue`.
- Tests: ExUnit, `async: true` where safe.
