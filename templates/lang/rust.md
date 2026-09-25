### Rust
- `cargo fmt` and `cargo clippy --all-targets -- -D warnings` must pass.
- No `unwrap`/`expect` outside tests and provably infallible cases. Propagate with `?`; `thiserror` for libraries, `anyhow` at binaries.
- Borrow before cloning; `&str`/`&[T]` in parameters; iterators over index loops; `impl Trait` over boxing where possible.
- Every `unsafe` block carries a `// SAFETY:` comment stating the upheld invariants.
- Unit tests in `#[cfg(test)]` modules, integration tests in `tests/`, doc examples that compile.
