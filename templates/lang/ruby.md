### Ruby
- RuboCop clean; `# frozen_string_literal: true`; `snake_case` methods, `CamelCase` classes.
- `each`/`map`/`select` over `for`; guard clauses over nested `if`; keyword args beyond two parameters.
- Raise specific exceptions; never `rescue Exception`; no core-class monkey patches.
- Bundler with committed `Gemfile.lock`. Tests: RSpec or Minitest, one behavior per example.
