### Ruby
- Ruby Style Guide via RuboCop; `# frozen_string_literal: true`; 2-space indent, `snake_case` methods, `CamelCase` classes.
- `each`/`map`/`select` over `for`; guard clauses over nested `if`; keyword arguments for more than two parameters.
- Raise specific exceptions; never `rescue Exception`; no monkey-patching core classes.
- Bundler with a committed `Gemfile.lock`.
- Tests: RSpec or Minitest, one behavior per example.
