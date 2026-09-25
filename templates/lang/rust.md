### Rust
- `cargo fmt` and `cargo clippy --all-targets -- -D warnings` pass.
- No `unwrap`/`expect` outside tests. Propagate with `?`; `thiserror` in libraries, `anyhow` in binaries.
- Borrow before cloning; `&str`/`&[T]` parameters; iterators over index loops.
- Every `unsafe` block has a `// SAFETY:` comment stating its invariants.
- Unit tests in `#[cfg(test)]`, integration tests in `tests/`, doc examples that compile.
