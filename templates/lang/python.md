### Python
- `ruff format` and `ruff check` clean; type hints on public functions; pyright or mypy passes.
- `pathlib`, f-strings, dataclasses or pydantic for records, context managers for resources.
- No mutable default arguments, bare `except:`, or wildcard imports.
- Pinned deps in `pyproject.toml` via `uv`, `pip-tools`, or `poetry`.
- Tests: pytest with fixtures and `parametrize`.
