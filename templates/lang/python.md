### Python
- Python 3.10+ per project. `ruff format` and `ruff check` clean; type hints on all public functions; pyright or mypy passes.
- PEP 8 and PEP 20. `pathlib` over `os.path`, f-strings, dataclasses or pydantic for records, context managers for resources.
- No mutable default arguments; no bare `except:`; no wildcard imports.
- Virtual environment with pinned dependencies (`uv`, `pip-tools`, or `poetry`) declared in `pyproject.toml`.
- Tests: pytest with fixtures and `parametrize`.
